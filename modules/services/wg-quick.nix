{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.networking.wg-quick;

  peerOpts = { ... }: {
    options = {
      allowedIPs = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "List of IP addresses associated with this peer.";
      };

      endpoint = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "IP and port to connect to this peer at.";
      };

      persistentKeepalive = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Interval in seconds to send keepalive packets";
      };

      presharedKeyFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description =
          "Optional, path to file containing the pre-shared key for this peer.";
      };

      publicKey = mkOption {
        default = null;
        type = types.str;
        description = "The public key for this peer.";
      };
    };
  };

  interfaceOpts = { ... }: {
    options = {
      address = mkOption {
        type = types.nullOr (types.listOf types.str);
        default = [ ];
        description = "List of IP addresses for this interface.";
      };

      autostart = mkOption {
        type = types.bool;
        default = true;
        description =
          "Whether to bring up this interface automatically during boot.";
      };

      dns = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "List of DNS servers for this interface.";
      };

      listenPort = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Port to listen on, randomly selected if not specified.";
      };

      mtu = mkOption {
        type = types.nullOr types.int;
        default = null;
        description =
          "MTU to set for this interface, automatically set if not specified";
      };

      peers = mkOption {
        type = types.listOf (types.submodule peerOpts);
        default = [ ];
        description = "List of peers associated with this interface.";
      };

      preDown = mkOption {
        type = with types; coercedTo (listOf str) (concatStringsSep "\n") lines;
        default = "";
        description = "List of commands to run before interface shutdown.";
      };

      preUp = mkOption {
        type = with types; coercedTo (listOf str) (concatStringsSep "\n") lines;
        default = "";
        description = "List of commands to run before interface setup.";
      };

      postDown = mkOption {
        type = with types; coercedTo (listOf str) (concatStringsSep "\n") lines;
        default = "";
        description = "List of commands to run after interface shutdown";
      };

      postUp = mkOption {
        type = with types; coercedTo (listOf str) (concatStringsSep "\n") lines;
        default = "";
        description = "List of commands to run after interface setup.";
      };

      privateKeyFile = mkOption {
        type = types.str;
        default = null;
        description = "Path to file containing this interface's private key.";
      };

      table = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Controls the routing table to which routes are added. There are two
          special values: `off` disables the creation of routes altogether,
          and `auto` (the default) adds routes to the default table and
          enables special handling of default routes.
        '';
      };
    };
  };

  generateInterfaceScript = name: text:
    ((pkgs.writeShellScriptBin name text) + "/bin/${name}");

  generatePostUpPSKText = name: interfaceOpt:
    map (peer:
      optionalString (peer.presharedKeyFile != null) ''
        wg set $(cat /var/run/wireguard/${name}.name) peer ${peer.publicKey} preshared-key ${peer.presharedKeyFile}
      '') interfaceOpt.peers;

  generatePostUpText = name: interfaceOpt:
    (optionalString (interfaceOpt.privateKeyFile != null) ''
      wg set $(cat /var/run/wireguard/${name}.name) private-key ${interfaceOpt.privateKeyFile}
    '') + (concatStrings (generatePostUpPSKText name interfaceOpt))
    + interfaceOpt.postUp;

  generateInterfacePostUp = name: interfaceOpt:
    generateInterfaceScript "postUp.sh" (generatePostUpText name interfaceOpt);

  generateInterfaceConfig = name: interfaceOpt:
    ''
      [Interface]
    '' + optionalString (interfaceOpt.address != [ ]) (''
      Address = ${concatStringsSep "," interfaceOpt.address}
    '') + optionalString (interfaceOpt.dns != [ ]) ''
      DNS = ${concatStringsSep "," interfaceOpt.dns}
    '' + optionalString (interfaceOpt.listenPort != null) ''
      ListenPort = ${toString interfaceOpt.listenPort}
    '' + optionalString (interfaceOpt.mtu != null) ''
      MTU = ${toString interfaceOpt.mtu}
    '' + optionalString (interfaceOpt.preUp != "") ''
      PreUp = ${generateInterfaceScript "preUp.sh" interfaceOpt.preUp}
    '' + optionalString (interfaceOpt.preDown != "") ''
      PreDown = ${generateInterfaceScript "preDown.sh" interfaceOpt.preDown}
    '' + optionalString
    (interfaceOpt.privateKeyFile != null || interfaceOpt.postUp != "") ''
      PostUp = ${generateInterfacePostUp name interfaceOpt}
    '' + optionalString (interfaceOpt.postDown != "") ''
      PostDown = ${generateInterfaceScript "postDown.sh" interfaceOpt.postDown}
    '' + optionalString (interfaceOpt.table != null) ''
      Table = ${interfaceOpt.table}
    '' + optionalString (interfaceOpt.peers != [ ]) "\n"
    + concatStringsSep "\n" (map generatePeerConfig interfaceOpt.peers);

  generatePeerConfig = peerOpt:
    ''
      [Peer]
      PublicKey = ${peerOpt.publicKey}
    '' + optionalString (peerOpt.allowedIPs != [ ]) ''
      AllowedIPs = ${concatStringsSep "," peerOpt.allowedIPs}
    '' + optionalString (peerOpt.endpoint != null) ''
      Endpoint = ${peerOpt.endpoint}
    '' + optionalString (peerOpt.persistentKeepalive != null) ''
      PersistentKeepalive = ${toString peerOpt.persistentKeepalive}
    '';

  generateInterfaceAttrs = name: interfaceOpt:
    nameValuePair "wireguard/${name}.conf" {
      enable = true;
      text = generateInterfaceConfig name interfaceOpt;
    };

  generateLaunchDaemonAttrs = name: interfaceOpt:
    nameValuePair "wg-quick-${name}" {
      serviceConfig = {
        EnvironmentVariables = {
          PATH =
            "${pkgs.wireguard-tools}/bin:${pkgs.wireguard-go}/bin:${config.environment.systemPath}";
        };
        KeepAlive = {
          NetworkState = true;
          SuccessfulExit = true;
        };
        ProgramArguments =
          [ "${pkgs.wireguard-tools}/bin/wg-quick" "up" "${name}" ];
        RunAtLoad = true;
        StandardErrorPath = "${cfg.logDir}/wg-quick-${name}.log";
        StandardOutPath = "${cfg.logDir}/wg-quick-${name}.log";
      };
    };
in {
  options = {
    networking.wg-quick = {
      interfaces = mkOption {
        type = types.attrsOf (types.submodule interfaceOpts);
        default = { };
        description = "Set of wg-quick interfaces.";
      };

      logDir = mkOption {
        type = types.str;
        default = "/var/log";
        description = "Directory to save wg-quick logs to.";
      };
    };
  };

  config = mkIf (cfg.interfaces != { }) {
    launchd.daemons = mapAttrs' generateLaunchDaemonAttrs
      (filterAttrs (name: interfaceOpt: interfaceOpt.autostart)
        config.networking.wg-quick.interfaces);

    environment.etc =
      mapAttrs' generateInterfaceAttrs config.networking.wg-quick.interfaces;

    environment.systemPackages = [ pkgs.wireguard-go pkgs.wireguard-tools ];
  };
}
