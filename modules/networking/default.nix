{ config, lib, ... }:

with lib;

let
  cfg = config.networking;

  hostnameRegEx = ''^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$'';

  emptyList = lst: if lst != [ ] then lst else [ "empty" ];

  onOff = cond: if cond then "on" else "off";

  setLocations = optionalString (cfg.knownNetworkServices != [ ] && cfg.location != { }) ''
    curr_location=$(networksetup -getcurrentlocation)

    readarray -t curr_locations_array < <(networksetup -listlocations)

    declare -A curr_locations
    for location in "''${curr_locations_array[@]}"; do
      curr_locations[$location]=1
    done

    declare -A goal_locations
    for location in ${strings.escapeShellArgs (builtins.attrNames cfg.location)}; do
      goal_locations[$location]=1
    done

    for location in "''${!goal_locations[@]}"; do
      if [[ ! -v curr_locations[$location] ]]; then
        networksetup -createlocation "$location" populate > /dev/null
      fi
    done

    # switch to a location that surely does not need to be deleted
    networksetup -switchtolocation ${strings.escapeShellArg (builtins.head (builtins.attrNames cfg.location))} > /dev/null

    for location in "''${!curr_locations[@]}"; do
      if [[ ! -v goal_locations[$location] ]]; then
        networksetup -deletelocation "$location" > /dev/null
      fi
    done

    ${concatMapStringsSep "\n" (location: ''
      networksetup -switchtolocation ${strings.escapeShellArg location} > /dev/null

      networkservices=$(networksetup -listallnetworkservices)
      ${concatMapStringsSep "\n" (srv: ''
        case "$networkservices" in
          *${lib.escapeShellArg srv}*)
            networksetup -setdnsservers ${
              lib.escapeShellArgs ([ srv ] ++ (emptyList cfg.location.${location}.dns))
            }
            networksetup -setsearchdomains ${
              lib.escapeShellArgs ([ srv ] ++ (emptyList cfg.location.${location}.search))
            }
            ;;
        esac
      '') cfg.knownNetworkServices}
    '') (builtins.attrNames cfg.location)}

    if [[ -v goal_locations[$curr_location] ]]; then
      networksetup -switchtolocation "$curr_location" > /dev/null
    fi
  '';
in

{
  imports = [
    (mkAliasOptionModule
      [
        "networking"
        "dns"
      ]
      [
        "networking"
        "location"
        "Automatic"
        "dns"
      ]
    )
    (mkAliasOptionModule
      [
        "networking"
        "search"
      ]
      [
        "networking"
        "location"
        "Automatic"
        "search"
      ]
    )
  ];

  options = {
    networking.computerName = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "John’s MacBook Pro";
      description = ''
        The user-friendly name for the system, set in System Preferences > Sharing > Computer Name.

        Setting this option is equivalent to running `scutil --set ComputerName`.

        This name can contain spaces and Unicode characters.
      '';
    };

    networking.hostName = mkOption {
      type = types.nullOr (types.strMatching hostnameRegEx);
      default = null;
      example = "Johns-MacBook-Pro";
      description = ''
        The hostname of your system, as visible from the command line and used by local and remote
        networks when connecting through SSH and Remote Login.

        Setting this option is equivalent to running the command `scutil --set HostName`.

        (Note that networking.localHostName defaults to the value of this option.)
      '';
    };

    networking.localHostName = mkOption {
      type = types.nullOr (types.strMatching hostnameRegEx);
      default = cfg.hostName;
      example = "Johns-MacBook-Pro";
      description = ''
        The local hostname, or local network name, is displayed beneath the computer's name at the
        top of the Sharing preferences pane. It identifies your Mac to Bonjour-compatible services.

        Setting this option is equivalent to running the command `scutil --set LocalHostName`, where
        running, e.g., `scutil --set LocalHostName 'Johns-MacBook-Pro'`, would set
        the systems local hostname to "Johns-MacBook-Pro.local". The value of this option defaults
        to the value of the networking.hostName option.

        By default on macOS the local hostname is your computer's name with ".local" appended, with
        any spaces replaced with hyphens, and invalid characters omitted.
      '';
    };

    networking.knownNetworkServices = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [
        "Wi-Fi"
        "Ethernet Adaptor"
        "Thunderbolt Ethernet"
      ];
      description = ''
        List of network services that should be configured.

        To display a list of all the network services on the server's
        hardware ports, use {command}`networksetup -listallnetworkservices`.
      '';
    };

    networking.location = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            dns = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = [
                "8.8.8.8"
                "8.8.4.4"
                "2001:4860:4860::8888"
                "2001:4860:4860::8844"
              ];
              description = "The list of DNS servers used when resolving domain names.";
            };

            search = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "The list of search paths used when resolving domain names.";
            };
          };
        }
      );
      default = { };
      description = ''
        Set of network locations to configure.

        By default, a system comes with a single location called "Automatic", but you can
        define additional locations to switch between different network configurations.

        If you define any locations here, you must also explicitly define the "Automatic"
        location if you want it to exist.
      '';
    };

    networking.wakeOnLan.enable = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Enable Wake-on-LAN for the device.

        Battery powered devices may require being connected to power.
      '';
    };
  };

  config = {

    warnings = [
      (mkIf (
        cfg.knownNetworkServices == [ ]
        && (builtins.any (l: l.dns != [ ]) (builtins.attrValues cfg.location))
      ) "networking.knownNetworkServices is empty, DNS servers will not be configured.")
      (mkIf (
        cfg.knownNetworkServices == [ ]
        && (builtins.any (l: l.search != [ ]) (builtins.attrValues cfg.location))
      ) "networking.knownNetworkServices is empty, DNS search domains will not be configured.")
    ];

    system.activationScripts.networking.text = ''
      echo "configuring networking..." >&2

      ${optionalString (cfg.computerName != null) ''
        scutil --set ComputerName ${escapeShellArg cfg.computerName}
      ''}
      ${optionalString (cfg.hostName != null) ''
        scutil --set HostName ${escapeShellArg cfg.hostName}
      ''}
      ${optionalString (cfg.localHostName != null) ''
        scutil --set LocalHostName ${escapeShellArg cfg.localHostName}
      ''}

      ${setLocations}

      ${optionalString (cfg.wakeOnLan.enable != null) ''
        systemsetup -setWakeOnNetworkAccess '${onOff cfg.wakeOnLan.enable}' &> /dev/null
      ''}

      if [ -e /etc/hosts.before-nix-darwin ]; then
        echo "restoring /etc/hosts..." >&2
        sudo mv /etc/hosts{.before-nix-darwin,}
      fi
    '';

  };
}
