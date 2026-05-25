{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.easytier;
  settings_format = pkgs.formats.toml { };

  # Filter settings that has null value, then filter instances and it's settings that the value is an empty attrset
  gen_final_settings =
    inst:
    lib.filterAttrsRecursive (_: v: v != { }) (
      lib.filterAttrsRecursive (_: v: v != null) (
        {
          inherit (inst.settings)
            instance_name
            hostname
            ipv4
            dhcp
            listeners
            ;
          network_identity = { inherit (inst.settings) network_name network_secret; };
          peer = map (p: { uri = p; }) inst.settings.peers;
        }
        // inst.extraSettings
      )
    );

  config_file_det =
    name: inst:
    if inst.configFile == null then
      settings_format.generate "easytier-${name}.toml" (gen_final_settings inst)
    else
      inst.configFile;

  active_insts = lib.filterAttrs (_: inst: inst.enable) cfg.instances;

  settings_module = name: {
    options = {
      instance_name = lib.mkOption {
        type = lib.types.str;
        default = name;
        description = "Identify different instances on same host";
      };
      hostname = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        description = "Hostname shown in peer list and web console.";
      };
      network_name = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        description = "EasyTier network name.";
      };
      network_secret = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        description = ''
          EasyTier network credential used for verification and encryption. It can also be set in environmentFile.
        '';
      };
      ipv4 = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        description = ''
          IPv4 cidr address of this peer in the virtual network. If empty, this peer will only forward packets and no
          TUN device will be created.
        '';
        example = "10.144.144.1/24";
      };
      dhcp = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Automatically determine the IPv4 address of this peer based on existing peers on network.";
      };
      listeners = lib.mkOption {
        type = with lib.types; listOf str;
        default = [
          "tcp://0.0.0.0:11010"
          "udp://0.0.0.0:11010"
        ];
        description = ''
          Listener addresses to accept connections from other peers. Valid format is: `<proto>://<addr>:<port>`, where
          the protocol can be `tcp`, `udp`, `ring`, `wg`, `ws`, `wss`.
        '';
      };
      peers = lib.mkOption {
        type = with lib.types; listOf str;
        default = [ ];
        description = "Peers to connect initially. Valid format is: `<proto>://<addr>:<port>`.";
        example = [ "tcp://example.com:11010" ];
      };
    };
  };
  instance_module =
    { name, ... }:
    {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable the instance.";
        };
        configServer = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          description = ''
            Configure the instance from config server. When this option set, any other settings for configuring the
            instance manually except `hostname` will be ignored. Valid formats are:

            - full uri for custom server: `udp://example.com:22020/<token>`
            - username only for official server: `<token>`
          '';
          example = "udp://example.com:22020/myusername";
        };
        configFile = lib.mkOption {
          type = with lib.types; nullOr path;
          default = null;
          description = ''
            Path to easytier config file. Setting this option will override `settings` and `extraSettings` of this
            instance.
          '';
        };
        environmentFiles = lib.mkOption {
          type = with lib.types; listOf path;
          default = [ ];
          description = ''
            Environment files for this instance. All command-line args have corresponding environment variables.
          '';
          example = lib.literalExpression ''
            [
              /path/to/.env
              /path/to/.env.secret
            ]
          '';
        };
        settings = lib.mkOption {
          type = lib.types.submodule (settings_module name);
          default = { };
          description = "Settings to generate {file}`easytier-${name}.toml`";
        };
        extraSettings = lib.mkOption {
          type = settings_format.type;
          default = { };
          description = ''
            Extra settings to add to {file}`easytier-${name}.toml`.
          '';
        };
        extraArgs = lib.mkOption {
          type = with lib.types; listOf str;
          default = [ ];
          description = "Extra args append to the easytier command-line.";
        };
      };
    };
in
{
  options.services.easytier = {
    enable = lib.mkEnableOption "EasyTier daemon";
    package = lib.mkPackageOption pkgs "easytier" { };
    allowSystemForward = lib.mkEnableOption ''
      Allow the system to forward packets from easytier. Useful when `proxy_forward_by_system` enabled.
    '';
    instances = lib.mkOption {
      description = "EasyTier instances.";
      type = lib.types.attrsOf (lib.types.submodule instance_module);
      default = { };
      example = {
        settings = {
          network_name = "easytier";
          network_secret = "easytier";
          ipv4 = "10.144.144.1/24";
          peers = [
            "tcp://public.easytier.cn:11010"
            "wss://example.com:443"
          ];
        };
        extraSettings.flags.dev_name = "utun5";
      };
    };
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    system.activationScripts.postActivation.text = ''
      # Ensure the Easytier state directory is initialized
      ${lib.concatLines (
        lib.mapAttrsToList (name: _: ''
          if [ ! -d "/Library/Application Support/easytier-${name}" ]; then
            echo "Setting up EasyTier directory for ${name}..."
            install -dm700 "/Library/Application Support/easytier-${name}"
          fi
        '') active_insts
      )}
    '';
    # nix-darwin lacks `launchd.daemon.<name>.restartTriggers`
    launchd.daemons = lib.mapAttrs' (
      name: inst:
      lib.nameValuePair "easytier-${name}" {
        path = [
          cfg.package
          "/usr/bin:/bin:/usr/sbin:/sbin"
        ];
        # Emulate Systemd's EnvironmentFile setups inside the Launchd script
        script = ''
          # Emulate Systemd's EnvironmentFile parsing safely
          load_env_file() {
            local file=$1
            if [ ! -f "$file" ]; then return 2; fi

            while IFS= read -r line || [ -n "$line" ]; do
              # Skip empty lines and comments
              [[ "$line" =~ ^[[:space:]]*$ || "$line" =~ ^[[:space:]]*# ]] && continue

              # Split into key and value on the first '='
              local key="''${line%%=*}"
              local value="''${line#*=}"

              # Optional: Systemd ignores matching outer quotes, so we strip them here
              if [[ "$value" == \"*\" ]] || [[ "$value" == \'*\' ]]; then
                value="''${value:1:-1}"
              fi

              export "$key"="$value"
            done < "$file"
          }
          ${lib.concatMapStringsSep "\n" (f: "load_env_file ${lib.escapeShellArg f}") inst.environmentFiles}

          exec ${
            lib.escapeShellArgs (
              [ "easytier-core" ]
              ++ lib.optionals (inst.configServer != null) [
                "-w"
                inst.configServer
              ]
              ++ lib.optionals (inst.configServer != null && inst.settings.hostname != null) [
                "--hostname"
                inst.settings.hostname
              ]
              ++ lib.optionals (inst.configServer == null) [
                "-c"
                "${config_file_det name inst}"
              ]
              ++ inst.extraArgs
            )
          }
        '';
        serviceConfig = {
          Label = "org.nixos.easytier-${name}";
          RunAtLoad = true;
          KeepAlive = {
            Crashed = true;
            SuccessfulExit = false;
          };
          WorkingDirectory = "/Library/Application Support/easytier-${name}";
          StandardOutPath = "/Library/Logs/org.nixos.easytier-${name}.stdout.log";
          StandardErrorPath = "/Library/Logs/org.nixos.easytier-${name}.stderr.log";
        };
      }
    ) active_insts;

    # Darwin-specific sysctl routing equivalents
    # TODO: nix-darwin currently lacks hooks and we need manually run `sysctl -f /etc/sysctl.conf` to apply
    environment.etc = lib.mkIf cfg.allowSystemForward {
      "sysctl.conf".text = ''
        net.inet.ip.forwarding=1
        net.inet6.ip6.forwarding=1
      '';
    };
  };
  meta.maintainers = [ lib.maintainers.proteus or "Proteus Qian" ];
}
