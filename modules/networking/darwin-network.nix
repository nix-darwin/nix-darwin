{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.darwin.network;

  routeOptions = {
    Gateway = lib.mkOption {
      type = lib.types.str;
      description = "Gateway address (IPv4 or IPv6)";
    };

    GatewayOnLink = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether the gateway is directly reachable on link";
    };

    Destination = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Destination prefix. If null, creates default route.";
    };
  };

  matchConfigOptions = {
    MACAddress = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "10:ff:e0:b9:59:d9";
      description = "MAC address to match against";
    };

    Name = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "en0";
      description = "Interface name to match against";
    };
  };

  networkOptions =
    { name, ... }:
    {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Whether to enable this network configuration";
        };

        matchConfig = lib.mkOption {
          type = lib.types.submodule { options = matchConfigOptions; };
          default = { };
          description = "Match configuration to identify the interface";
        };

        address = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [
            "192.168.1.100/24"
            "2001:db8::1/64"
          ];
          description = "List of addresses (format: address/prefix)";
        };

        gateway = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "List of gateway addresses";
        };

        routes = lib.mkOption {
          type = lib.types.listOf (lib.types.submodule { options = routeOptions; });
          default = [ ];
          example = [
            {
              Gateway = "192.168.1.1";
              GatewayOnLink = true;
            }
          ];
          description = "List of routes to configure";
        };

        dns = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [
            "1.1.1.1"
            "8.8.8.8"
          ];
          description = "List of DNS servers";
        };

        linkConfig = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          description = "Link configuration (supported: MTUBytes)";
        };

        networkConfig = lib.mkOption {
          type = lib.types.attrsOf (lib.types.either lib.types.bool lib.types.str);
          default = { };
          description = "Network configuration (supported: DHCP)";
        };
      };
    };

  isIPv6 = addr: builtins.match ".*:.*" addr != null;

  parseAddress =
    addr:
    let
      parts = builtins.match "([^/]+)/([0-9]+)" addr;
    in
    if parts != null then
      {
        address = builtins.elemAt parts 0;
        prefix = builtins.elemAt parts 1;
      }
    else
      {
        address = addr;
        prefix = if isIPv6 addr then "128" else "32";
      };

  prefixToNetmask =
    prefix:
    let
      p = if builtins.isString prefix then lib.strings.toInt prefix else prefix;
      masks = {
        "0" = "0.0.0.0";
        "8" = "255.0.0.0";
        "16" = "255.255.0.0";
        "24" = "255.255.255.0";
        "25" = "255.255.255.128";
        "26" = "255.255.255.192";
        "27" = "255.255.255.224";
        "28" = "255.255.255.240";
        "29" = "255.255.255.248";
        "30" = "255.255.255.252";
        "31" = "255.255.255.254";
        "32" = "255.255.255.255";
      };
    in
    masks.${toString p} or "255.255.255.255";

  mkNetworkScript =
    name: netCfg:
    let
      ipv4Addrs = builtins.filter (a: !(isIPv6 (parseAddress a).address)) netCfg.address;
      ipv6Addrs = builtins.filter (a: isIPv6 (parseAddress a).address) netCfg.address;
      ipv4Routes = builtins.filter (r: !(isIPv6 r.Gateway)) netCfg.routes;
      ipv6Routes = builtins.filter (r: isIPv6 r.Gateway) netCfg.routes;

      firstIPv4Gateway =
        let
          gws = (map (r: r.Gateway) ipv4Routes) ++ netCfg.gateway;
          ipv4Gws = builtins.filter (g: !(isIPv6 g)) gws;
        in
        if ipv4Gws != [ ] then builtins.head ipv4Gws else null;

      firstIPv6Gateway =
        let
          gws = map (r: r.Gateway) ipv6Routes;
        in
        if gws != [ ] then builtins.head gws else null;

      findByMAC = mac: ''
        NETWORK_SERVICE=""
        NETWORK_INTERFACE=""
        while IFS= read -r line; do
          case "$line" in
            "Hardware Port:"*) current_port="''${line#Hardware Port: }" ;;
            "Device:"*) current_device="''${line#Device: }" ;;
            "Ethernet Address:"*)
              current_mac="''${line#Ethernet Address: }"
              if [ "$(echo "$current_mac" | tr '[:upper:]' '[:lower:]')" = "$(echo "${mac}" | tr '[:upper:]' '[:lower:]')" ]; then
                NETWORK_SERVICE="$current_port"
                NETWORK_INTERFACE="$current_device"
                break
              fi
              ;;
          esac
        done < <(networksetup -listallhardwareports)
        if [ -z "$NETWORK_SERVICE" ]; then
          echo "ERROR: Could not find interface with MAC ${mac}" >&2
          exit 1
        fi
      '';

      findByName = ifname: ''
        NETWORK_INTERFACE="${ifname}"
        NETWORK_SERVICE=""
        while IFS= read -r line; do
          case "$line" in
            "Hardware Port:"*) current_port="''${line#Hardware Port: }" ;;
            "Device:"*)
              current_device="''${line#Device: }"
              if [ "$current_device" = "${ifname}" ]; then
                NETWORK_SERVICE="$current_port"
                break
              fi
              ;;
          esac
        done < <(networksetup -listallhardwareports)
        [ -z "$NETWORK_SERVICE" ] && NETWORK_SERVICE="${ifname}"
      '';

      ipv4Script =
        let
          firstAddr = if ipv4Addrs != [ ] then parseAddress (builtins.head ipv4Addrs) else null;
        in
        lib.optionalString (firstAddr != null) (
          if firstIPv4Gateway != null then
            ''
              networksetup -setmanual "$NETWORK_SERVICE" "${firstAddr.address}" "${prefixToNetmask firstAddr.prefix}" "${firstIPv4Gateway}"
            ''
          else
            ''
              networksetup -setmanual "$NETWORK_SERVICE" "${firstAddr.address}" "${prefixToNetmask firstAddr.prefix}"
            ''
        );

      ipv6Script =
        let
          firstAddr = if ipv6Addrs != [ ] then parseAddress (builtins.head ipv6Addrs) else null;
        in
        lib.optionalString (firstAddr != null) (
          if firstIPv6Gateway != null then
            ''
              networksetup -setv6manual "$NETWORK_SERVICE" "${firstAddr.address}" "${firstAddr.prefix}" "${firstIPv6Gateway}"
            ''
          else
            ''
              networksetup -setv6manual "$NETWORK_SERVICE" "${firstAddr.address}" "${firstAddr.prefix}"
            ''
        );

      routesScript =
        let
          mkIPv4Route =
            route:
            lib.optionalString route.GatewayOnLink ''
              if ! netstat -rn | grep -q "^default.*${route.Gateway}"; then
                route delete default 2>/dev/null || true
                route add -host ${route.Gateway} -interface "$NETWORK_INTERFACE"
                route add default ${route.Gateway}
              fi
            '';
          mkIPv6Route =
            route:
            lib.optionalString route.GatewayOnLink ''
              if ! netstat -rn | grep -q "^default.*${route.Gateway}"; then
                route delete -inet6 default 2>/dev/null || true
                route add -inet6 -host ${route.Gateway} -interface "$NETWORK_INTERFACE"
                route add -inet6 default ${route.Gateway}
              fi
            '';
        in
        lib.concatMapStrings mkIPv4Route ipv4Routes + lib.concatMapStrings mkIPv6Route ipv6Routes;

      dnsScript = lib.optionalString (netCfg.dns != [ ]) ''
        networksetup -setdnsservers "$NETWORK_SERVICE" ${lib.concatStringsSep " " netCfg.dns}
      '';

      mtuScript = lib.optionalString (netCfg.linkConfig ? MTUBytes) ''
        ifconfig "$NETWORK_INTERFACE" mtu ${netCfg.linkConfig.MTUBytes}
      '';

      dhcpScript =
        let
          dhcp = netCfg.networkConfig.DHCP or null;
        in
        lib.optionalString (dhcp != null) (
          if dhcp == "yes" || dhcp == true then
            ''
              networksetup -setdhcp "$NETWORK_SERVICE"
            ''
          else if dhcp == "ipv4" then
            ''
              networksetup -setdhcp "$NETWORK_SERVICE"
            ''
          else if dhcp == "ipv6" then
            ''
              networksetup -setv6automatic "$NETWORK_SERVICE"
            ''
          else
            ""
        );

    in
    {
      full = ''
        ${
          if netCfg.matchConfig.MACAddress != null then
            findByMAC netCfg.matchConfig.MACAddress
          else if netCfg.matchConfig.Name != null then
            findByName netCfg.matchConfig.Name
          else
            ''
              echo "ERROR: No matchConfig for network ${name}" >&2
              exit 1
            ''
        }
        ${dhcpScript}
        ${ipv4Script}
        ${ipv6Script}
        ${routesScript}
        ${dnsScript}
        ${mtuScript}
      '';

      routesOnly = ''
        ${
          if netCfg.matchConfig.MACAddress != null then
            findByMAC netCfg.matchConfig.MACAddress
          else if netCfg.matchConfig.Name != null then
            findByName netCfg.matchConfig.Name
          else
            ""
        }
        ${routesScript}
      '';
    };

  enabledNetworks = lib.filterAttrs (n: v: v.enable) cfg.networks;
  scripts = lib.mapAttrsToList mkNetworkScript enabledNetworks;
  fullScript = lib.concatMapStrings (s: s.full) scripts;
  routesOnlyScript = lib.concatMapStrings (s: s.routesOnly) scripts;

  hasGatewayOnLink = lib.any (netCfg: lib.any (r: r.GatewayOnLink) netCfg.routes) (
    lib.attrValues enabledNetworks
  );

  routeScript = pkgs.writeScript "darwin-network-routes" ''
    #!/bin/bash
    sleep 5
    ${routesOnlyScript}
  '';

in
{
  options.darwin.network = {
    networks = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule networkOptions);
      default = { };
      description = "Network configurations (similar to systemd.network.networks)";
    };
  };

  config = lib.mkIf (enabledNetworks != { }) {

    system.activationScripts.postActivation.text = lib.mkBefore ''
      launchctl disable system/netbiosd 2>/dev/null || true
      launchctl bootout system/netbiosd 2>/dev/null || true
      ${fullScript}
    '';

    launchd.daemons.darwin-network-routes = lib.mkIf hasGatewayOnLink {
      script = ''
        ${routeScript}
      '';
      serviceConfig = {
        Label = "org.nixos.darwin-network-routes";
        RunAtLoad = true;
        KeepAlive = false;
        StandardOutPath = "/var/log/darwin-network-routes.log";
        StandardErrorPath = "/var/log/darwin-network-routes.log";
      };
    };
  };
}
