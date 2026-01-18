{ config, lib, ... }:

with lib;

let
  cfg = config.networking;

  hostnameRegEx = ''^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])$'';

  emptyList = lst: if lst != [] then lst else ["empty"];

  onOff = cond: if cond then "on" else "off";

  setNetworkServices = optionalString (cfg.knownNetworkServices != []) ''
    networkservices=$(networksetup -listallnetworkservices)
    ${concatMapStringsSep "\n" (srv: ''
      case "$networkservices" in
        *${lib.escapeShellArg srv}*)
          networksetup -setdnsservers ${lib.escapeShellArgs ([ srv ] ++ (emptyList cfg.dns))}
          networksetup -setsearchdomains ${lib.escapeShellArgs ([ srv ] ++ (emptyList cfg.search))}
          ${optionalString (cfg.dhcpClientId != null) ''
            networksetup -setdhcp ${lib.escapeShellArgs [ srv cfg.dhcpClientId ]}
          ''}
          ;;
      esac
    '') cfg.knownNetworkServices}
  '';
in

{
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

    networking.domain = mkOption {
      default = null;
      example = "home.arpa";
      type = types.nullOr types.str;
      description = ''
        The domain.  It can be left empty if it is auto-detected through DHCP.
      '';
    };

    networking.fqdn = mkOption {
      type = types.str;
      default =
        if (cfg.hostName != "" && cfg.domain != null) then
          "${cfg.hostName}.${cfg.domain}"
        else
          throw ''
            The FQDN is required but cannot be determined from `networking.hostName`
            and `networking.domain`. Please ensure these options are set properly or
            set `networking.fqdn` directly.
          '';
      defaultText = literalExpression ''"''${networking.hostName}.''${networking.domain}"'';
      description = ''
        The fully qualified domain name (FQDN) of this host. By default, it is
        the result of combining `networking.hostName` and `networking.domain.`

        Using this option will result in an evaluation error if the hostname is empty or
        no domain is specified.

        Modules that accept a mere `networking.hostName` but prefer a fully qualified
        domain name may use `networking.fqdnOrHostName` instead.
      '';
    };

    networking.fqdnOrHostName = mkOption {
      readOnly = true;
      type = types.str;
      default = if cfg.domain == null then cfg.hostName else cfg.fqdn;
      defaultText = literalExpression ''
        if cfg.domain == null then cfg.hostName else cfg.fqdn
      '';
      description = ''
        Either the fully qualified domain name (FQDN), or just the host name if
        it does not exists.

        This is a convenience option for modules to read instead of `fqdn` when
        a mere `hostName` is also an acceptable value; this option does not
        throw an error when `domain` is unset.
      '';
    };

    networking.knownNetworkServices = mkOption {
      type = types.listOf types.str;
      default = [];
      example = [ "Wi-Fi" "Ethernet Adaptor" "Thunderbolt Ethernet" ];
      description = ''
        List of networkservices that should be configured.

        To display a list of all the network services on the server's
        hardware ports, use {command}`networksetup -listallnetworkservices`.
      '';
    };

    networking.dhcpClientId = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "my-client-id";
      description = ''
        The DHCP client identifier to use when requesting an IP address from a DHCP server.

        If this option is set, it will be used by the system when requesting an IP address.
        If not set, no changes will be made.

        Set to the string "empty" to clear any previously configured client ID
        and restore the system default behavior.
      '';
    };

    networking.dns = mkOption {
      type = types.listOf types.str;
      default = [];
      example = [ "8.8.8.8" "8.8.4.4" "2001:4860:4860::8888" "2001:4860:4860::8844" ];
      description = "The list of dns servers used when resolving domain names.";
    };

    networking.search = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "The list of search paths used when resolving domain names.";
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
      (mkIf (cfg.knownNetworkServices == [] && cfg.dns != []) "networking.knownNetworkServices is empty, dns servers will not be configured.")
      (mkIf (cfg.knownNetworkServices == [] && cfg.search != []) "networking.knownNetworkServices is empty, dns searchdomains will not be configured.")
      (mkIf (cfg.knownNetworkServices == [] && cfg.dhcpClientId != null) "networking.knownNetworkServices is empty, dhcp client ID will not be configured.")
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

      ${setNetworkServices}

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
