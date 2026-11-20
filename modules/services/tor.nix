{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.tor;

  stateDir = "/var/lib/tor";
  dataDir = "${stateDir}/data";

  onionServiceOpts = { name, ... }: {
    options = {
      version = mkOption {
        type = types.enum [ 3 ];
        default = 3;
        description = "Onion service protocol version. Only v3 is supported.";
      };

      path = mkOption {
        type = types.path;
        default = "${stateDir}/onion/${name}";
        defaultText = literalExpression ''"${stateDir}/onion/<name>"'';
        description = "`HiddenServiceDir` path for this onion service.";
      };

      map = mkOption {
        type = types.listOf (types.submodule {
          options = {
            port = mkOption {
              type = types.port;
              description = "Virtual port advertised on the onion address.";
            };
            target = mkOption {
              type = types.nullOr (types.submodule {
                options = {
                  addr = mkOption {
                    type = types.str;
                    default = "127.0.0.1";
                    description = "Local address the onion port forwards to.";
                  };
                  port = mkOption {
                    type = types.port;
                    description = "Local port the onion port forwards to.";
                  };
                };
              });
              default = null;
              description = ''
                Local endpoint traffic to this onion port is forwarded to.
                When `null`, Tor forwards to `127.0.0.1` on the same port as
                the virtual port.
              '';
            };
          };
        });
        default = [ ];
        description = ''
          `HiddenServicePort` entries. Each entry maps an onion-side virtual
          port to a local target address and port.
        '';
      };

      authorizedClients = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "descriptor:x25519:D36W263P4L27TFGHQAVBGKE5DLGUMUTI3BOHBWB3RIM5R77KYYVA" ];
        description = ''
          v3 client authorization public keys. Each entry is written as a
          separate `.auth` file under `<path>/authorized_clients/`.
        '';
      };
    };
  };

  mkOnionBlock = name: svc:
    let
      portLines = concatMapStringsSep "\n" (m:
        if m.target == null
        then "HiddenServicePort ${toString m.port}"
        else "HiddenServicePort ${toString m.port} ${m.target.addr}:${toString m.target.port}"
      ) svc.map;
    in ''
      HiddenServiceDir ${svc.path}
      HiddenServiceVersion ${toString svc.version}
      ${portLines}
    '';

  mkSettingLines = k: v:
    if v == null then [ ]
    else if isList v then map (x: "${k} ${toString x}") v
    else [ "${k} ${toString v}" ];

  settingsLines = concatStringsSep "\n" (
    concatLists (mapAttrsToList mkSettingLines cfg.settings)
  );

  onionBlocks = concatStringsSep "\n\n" (
    mapAttrsToList mkOnionBlock cfg.relay.onionServices
  );

  torrc = pkgs.writeText "torrc" ''
    DataDirectory ${dataDir}
    ${settingsLines}

    ${onionBlocks}
  '';
in
{
  meta.maintainers = [ lib.maintainers.master-hax or "master-hax" ];

  options.services.tor = {
    enable = mkEnableOption "the Tor daemon";

    package = mkPackageOption pkgs "tor" { };

    settings = mkOption {
      type = types.attrsOf (types.nullOr (types.oneOf [
        types.str
        types.int
        types.bool
        (types.listOf types.str)
      ]));
      default = { };
      example = {
        SocksPort = 9050;
        Log = [ "notice stdout" ];
      };
      description = ''
        Raw `torrc` key/value entries. Each attribute is written as
        `<key> <value>` on its own line; a list value emits one line
        per element, and `null` omits the entry entirely.
      '';
    };

    relay.onionServices = mkOption {
      type = types.attrsOf (types.submodule onionServiceOpts);
      default = { };
      description = "Onion services exposed by this Tor daemon.";
    };

    client = {
      enable = mkEnableOption ''
        the Tor client: opens a local SOCKS proxy that routes connections
        through the Tor network.
      '';

      dns = {
        enable = mkEnableOption ''
          the Tor DNS resolver: resolves DNS queries anonymously through
          the Tor network.
        '';

        listenAddress = mkOption {
          type = types.str;
          default = "127.0.0.1:9053";
          example = "0.0.0.0:9053";
          description = ''
            `DNSPort` value used when {option}`services.tor.client.dns.enable`
            is `true`.
          '';
        };
      };
    };
  };

  config = mkIf cfg.enable {
    services.tor.settings = {
      SOCKSPort = mkDefault (if cfg.client.enable then 9050 else 0);
      DNSPort = mkIf cfg.client.dns.enable (mkDefault cfg.client.dns.listenAddress);
    };

    security.sandbox.profiles.tor = {
      closure = [ cfg.package ];
      allowNetworking = true;
      profile = mkAfter ''
        (allow file-read*)
        (allow file-write* (subpath "${stateDir}"))
        (allow file-ioctl)
        (allow mach-lookup)
        (allow sysctl-read)
        (allow ipc-posix-shm*)
      '';
    };

    users.users._tor = {
      uid = config.ids.uids._tor;
      gid = config.ids.gids._tor;
      home = "/var/lib/tor";
      createHome = true;
      shell = "/usr/bin/false";
      description = "System user for the Tor daemon";
    };

    users.groups._tor = {
      gid = config.ids.gids._tor;
      description = "System group for the Tor daemon";
    };

    users.knownUsers = [ "_tor" ];
    users.knownGroups = [ "_tor" ];

    launchd.daemons.tor = {
      serviceConfig =
        let
          logPath = stateDir + "/tor.log";
        in
        {
          ProgramArguments = [
            "/usr/bin/sandbox-exec"
            "-f" "${config.security.sandbox.profiles.tor.profile}"
            "${cfg.package}/bin/tor"
            "-f" "${torrc}"
          ];
          RunAtLoad = true;
          KeepAlive = true;
          StandardOutPath = logPath;
          StandardErrorPath = logPath;
          GroupName = "_tor";
          UserName = "_tor";
        };
    };

    system.activationScripts.postActivation.text = mkAfter (concatMapStrings (name:
      let svc = cfg.relay.onionServices.${name}; in ''
        install -d -o _tor -g _tor -m 0700 "${svc.path}"
      '' + optionalString (svc.authorizedClients != [ ]) (''
        install -d -o _tor -g _tor -m 0700 "${svc.path}/authorized_clients"
      '' + concatStringsSep "\n" (imap0 (i: c: ''
        printf '%s\n' '${c}' > "${svc.path}/authorized_clients/client-${toString i}.auth"
        chown _tor:_tor "${svc.path}/authorized_clients/client-${toString i}.auth"
        chmod 0600 "${svc.path}/authorized_clients/client-${toString i}.auth"
      '') svc.authorizedClients))
    ) (attrNames cfg.relay.onionServices));
  };
}
