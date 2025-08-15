{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.netbird;

  # Helper functions for common paths and configurations
  getClientPaths = clientName: {
    configDir = "/var/lib/netbird-${clientName}";
    configFile = "/var/lib/netbird-${clientName}/config.json";
    configDirEtc = "/etc/netbird-${clientName}/config.d";
    runtimeDir = "/var/run/netbird-${clientName}";
    socketAddr = "unix:///var/run/netbird-${clientName}.sock";
    logOut = "/var/log/netbird-${clientName}.out.log";
    logErr = "/var/log/netbird-${clientName}.err.log";
  };

  getClientEnvVars = clientCfg: let
    paths = getClientPaths clientCfg.name;
  in {
    NB_CONFIG = paths.configFile;
    NB_LOG_FILE = "console";
    NB_DAEMON_ADDR = paths.socketAddr;
    NB_INTERFACE_NAME = clientCfg.interface;
    NB_WIREGUARD_PORT = toString clientCfg.port;
    NB_LOG_LEVEL = clientCfg.logLevel;
  };

  getDefaultEnvVars = {
    NB_CONFIG = "/var/lib/netbird/config.json";
    NB_LOG_FILE = "console";
  };

  # Generate helper script for a client
  mkClientScript = clientCfg:
    pkgs.writeScriptBin "netbird-${clientCfg.name}" ''
      #!${pkgs.bash}/bin/bash
      # Helper script for ${clientCfg.name} NetBird instance
      export NB_CONFIG="${(getClientPaths clientCfg.name).configFile}"
      export NB_DAEMON_ADDR="${(getClientPaths clientCfg.name).socketAddr}"
      export NB_INTERFACE_NAME="${clientCfg.interface}"
      export NB_WIREGUARD_PORT="${toString clientCfg.port}"
      export NB_LOG_FILE="console"
      export NB_LOG_LEVEL="${clientCfg.logLevel}"
      export NB_SERVICE="netbird-${clientCfg.name}"
      exec ${clientCfg.package}/bin/netbird "$@"
    '';

  clientSubmodule = types.submodule (
    { name, config, ... }:
    let
      client = config;
    in
    {
      options = {
        enable = mkEnableOption "this NetBird client instance" // { default = true; };
        package = mkOption {
          type = types.package;
          default = pkgs.netbird;
          defaultText = literalExpression "pkgs.netbird";
          description = "The package to use for this NetBird instance.";
        };
        port = mkOption {
          type = types.port;
          example = literalExpression "51820";
          description = "Port the NetBird client listens on.";
        };
        name = mkOption {
          type = types.str;
          default = name;
          description = "Primary name for use as a suffix in service names, directories, and interfaces.";
        };
        interface = mkOption {
          type = types.str;
          default = "utun${toString (100 + (lib.lists.findFirstIndex (x: x == name) 0 (builtins.attrNames cfg.clients)))}";
          description = "Name of the network interface managed by this client. Uses utun100+ prefix to avoid conflicts with system interfaces.";
        };
        config = mkOption {
          type = (pkgs.formats.json { }).type;
          defaultText = literalExpression ''
            {
              DisableAutoConnect = false;
              WgIface = client.interface;
              WgPort = client.port;
            }
          '';
          description = "Additional configuration that exists before the first start and later overrides the existing values in config.json.";
        };
        autoStart = mkOption {
          type = types.bool;
          default = true;
          description = "Start the service with the system.";
        };
        logLevel = mkOption {
          type = types.enum [ "debug" "info" "warn" "error" ];
          default = "info";
          description = "Log level for this NetBird instance.";
        };
        group = mkOption {
          type = types.str;
          default = "daemon";
          description = "Group to run the NetBird service under. The group will be created if it doesn't exist.";
        };
        openFirewall = mkOption {
          type = types.bool;
          default = true;
          description = "Opens up firewall port for communication between NetBird peers directly over LAN or public IP.";
        };
      };
    }
  );
in
{
  options.services.netbird = {
    enable = mkEnableOption "NetBird daemon (default instance)" // { default = false; };
    package = mkOption {
      type = types.package;
      default = pkgs.netbird;
      defaultText = literalExpression "pkgs.netbird";
      description = "The package to use for the default NetBird instance.";
    };
    clients = mkOption {
      type = types.attrsOf clientSubmodule;
      default = {};
      example = {
        work = {
          port = 13132;
          logLevel = "debug";
          group = "netbird";
          config = {
            SetupKey = "12345678-1234-1234-1234-123456789012";
          };
        };
        home = {
          port = 13133;
          logLevel = "info";
          group = "netbird";
          config = {
            SetupKey = "87654321-4321-4321-4321-210987654321";
          };
        };
      };
      description = "Attribute set of NetBird client instances.";
    };
  };

  config = mkIf (cfg.enable || cfg.clients != {}) {
    environment.systemPackages =
      (optional cfg.enable cfg.package) ++
      (mapAttrsToList (n: t: t.package) (filterAttrs (n: t: t.enable) cfg.clients)) ++
      # Generate helper scripts for each client instance
      (mapAttrsToList (name: clientCfg:
        lib.optionalString clientCfg.enable (mkClientScript clientCfg)
      ) cfg.clients);

    # Create config directories and files for each client
    environment.etc = mapAttrs' (name: clientCfg:
      nameValuePair "netbird-${clientCfg.name}/config.d/50-nix-darwin.json" (
        mkIf clientCfg.enable {
          text = builtins.toJSON (clientCfg.config // {
            WgIface = clientCfg.interface;
            WgPort = clientCfg.port;
          });
        }
      )
    ) cfg.clients;

    launchd.daemons =
      (optionalAttrs cfg.enable {
        netbird = {
          script = ''
            mkdir -p /var/run/netbird /var/lib/netbird
            exec ${cfg.package}/bin/netbird service run
          '';
          serviceConfig = {
            EnvironmentVariables = getDefaultEnvVars;
            KeepAlive = true;
            RunAtLoad = true;
            StandardOutPath = "/var/log/netbird.out.log";
            StandardErrorPath = "/var/log/netbird.err.log";
          };
        };
      }) //
      (mapAttrs' (name: clientCfg: nameValuePair "netbird-${clientCfg.name}" (
        mkIf clientCfg.enable (let
          paths = getClientPaths clientCfg.name;
        in {
          script = ''
            # Create necessary directories
            mkdir -p ${paths.runtimeDir} ${paths.configDir} ${paths.configDirEtc}
            
            echo "Debug: Created directories for ${clientCfg.name}"
            echo "Debug: Config file: ${paths.configFile}"
            echo "Debug: Config.d directory: ${paths.configDirEtc}"
            
            # Initialize config.json if it doesn't exist
            if [ ! -f ${paths.configFile} ]; then
              echo '{}' > ${paths.configFile}
              echo "Debug: Created empty config.json"
            else
              echo "Debug: Using existing config.json"
            fi
            
            # Show what's in config.d
            echo "Debug: Contents of config.d:"
            ls -la ${paths.configDirEtc}/*.json 2>/dev/null || echo "Debug: No config.d files found"
            
            # Merge configuration files using jq (following NixOS pattern)
            if command -v jq >/dev/null 2>&1; then
              echo "Debug: jq found, attempting to merge configs"
              # Create a temporary merged config
              jq -sS 'reduce .[] as $i ({}; . * $i)' \
                ${paths.configFile} \
                ${paths.configDirEtc}/*.json \
                > ${paths.configFile}.new 2>/dev/null || true
              
              # Update config if merge was successful
              if [ -f ${paths.configFile}.new ] && [ -s ${paths.configFile}.new ]; then
                mv ${paths.configFile}.new ${paths.configFile}
                echo "Debug: Config merged successfully"
              else
                echo "Debug: Config merge failed or produced empty result"
              fi
            else
              echo "Debug: jq not found, skipping config merge"
            fi
            
            # Show final config content
            echo "Debug: Final config.json content:"
            cat ${paths.configFile}
            
            # Check if SetupKey is provided in the Nix configuration and automatically login if so
            if [ -n "${clientCfg.config.SetupKey or ""}" ]; then
              echo "SetupKey found in Nix configuration, attempting automatic login..."
              
              # Start the service first
              export NB_CONFIG=${paths.configFile}
              export NB_DAEMON_ADDR=${paths.socketAddr}
              export NB_INTERFACE_NAME=${clientCfg.interface}
              export NB_WIREGUARD_PORT=${toString clientCfg.port}
              export NB_LOG_LEVEL=${clientCfg.logLevel}
              
              ${clientCfg.package}/bin/netbird service run --config ${paths.configFile} &
              SERVICE_PID=$!
              
              # Wait a moment for the service to start
              sleep 2
              
              # Attempt automatic login with the SetupKey from Nix configuration
              echo "Attempting automatic login with SetupKey for ${clientCfg.name}..."
              if ${clientCfg.package}/bin/netbird up --setup-key "${clientCfg.config.SetupKey}" 2>/dev/null; then
                echo "Automatic login successful for ${clientCfg.name}"
              else
                echo "Automatic login failed for ${clientCfg.name}, continuing with service..."
              fi
              
              # Wait for the service process
              wait $SERVICE_PID
            else
              # No SetupKey, just run the service normally
              echo "Debug: No SetupKey found in Nix configuration, running service normally"
              exec ${clientCfg.package}/bin/netbird service run --config ${paths.configFile}
            fi
          '';
          serviceConfig = {
            EnvironmentVariables = getClientEnvVars clientCfg;
            KeepAlive = true;
            RunAtLoad = clientCfg.autoStart;
            StandardOutPath = paths.logOut;
            StandardErrorPath = paths.logErr;
            GroupName = clientCfg.group;
          };
        })
      )) cfg.clients);

    # Ensure NetBird services are bootstrapped if missing (e.g., after manual bootout)
    system.activationScripts.postActivation.text = lib.mkAfter (let
      labelPrefix = config.launchd.labelPrefix;
      enabledClients = lib.filterAttrs (n: t: t.enable) cfg.clients;
      clientLabels = lib.mapAttrsToList (n: t: "${labelPrefix}.netbird-${t.name}") enabledClients;
      defaultLabel = lib.optionals cfg.enable [ "${labelPrefix}.netbird" ];
      allLabels = defaultLabel ++ clientLabels;
      labelsString = lib.concatStringsSep " " allLabels;
    in ''
      for label in ${labelsString}; do
        if ! /bin/launchctl print "system/''${label}" >/dev/null 2>&1; then
          echo "bootstrapping netbird service ''${label}" >&2
          /bin/launchctl bootstrap system "/Library/LaunchDaemons/''${label}.plist" || true
          /bin/launchctl enable "system/''${label}" || true
          /bin/launchctl kickstart -k "system/''${label}" || true
        fi
      done
    '');
  };
}
