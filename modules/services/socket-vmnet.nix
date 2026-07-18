{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.socket-vmnet;
in
{
  options.services.socket-vmnet = {
    enable = mkEnableOption "socket-vmnet, a vmnet.framework wrapper exposing a socket for QEMU/other VMMs";

    package = mkOption {
      type = types.package;
      default = pkgs.socket-vmnet;
      defaultText = literalExpression "pkgs.socket-vmnet";
      description = "The socket_vmnet package to use.";
    };

    socketPath = mkOption {
      type = types.str;
      default = "/var/run/socket_vmnet";
      description = "Path to the unix socket socket_vmnet listens on.";
    };

    socketGroup = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Socket group name (\"staff\" if unset).";
    };

    vmnetMode = mkOption {
      type = types.nullOr (
        types.enum [
          "host"
          "shared"
          "bridged"
        ]
      );
      default = null;
      description = "vmnet mode (\"shared\" if unset).";
    };

    vmnetInterface = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "en0";
      description = "Interface used for \"bridged\" vmnetMode.";
    };

    vmnetGateway = mkOption {
      type = types.nullOr types.str;
      default = "192.168.105.1";
      description = "Gateway used for host/shared modes. Upstream's own launchd plist pins this explicitly rather than relying on macOS's auto-picked default.";
    };

    vmnetDhcpEnd = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "End of DHCP range; requires vmnetGateway to be set.";
    };

    vmnetMask = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "255.255.255.0";
      description = "Subnet mask; requires vmnetGateway to be set.";
    };

    vmnetInterfaceId = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "vmnet interface UUID (random if unset).";
    };

    vmnetNetworkIdentifier = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "UUID identifying an isolated network (host mode only, no DHCP).";
    };

    vmnetNat66Prefix = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "IPv6 ULA prefix (fd00::/8) to use with shared mode (random if unset).";
    };

    pidfile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Path to save the pid file.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.vmnetDhcpEnd == null || cfg.vmnetGateway != null;
        message = "services.socket_vmnet.vmnetDhcpEnd requires vmnetGateway to be set.";
      }
      {
        assertion = cfg.vmnetMask == null || cfg.vmnetGateway != null;
        message = "services.socket_vmnet.vmnetMask requires vmnetGateway to be set.";
      }
      {
        assertion = cfg.vmnetInterface == null || cfg.vmnetMode == "bridged";
        message = "services.socket_vmnet.vmnetInterface only applies when vmnetMode is \"bridged\".";
      }
    ];

    system.activationScripts.preActivation.text = ''
      mkdir -p /var/log/socket_vmnet
    '';

    launchd.daemons.socket_vmnet = {
      serviceConfig = {
        Label = "io.github.lima-vm.socket_vmnet";
        Program = "${lib.getExe cfg.package}";
        ProgramArguments =
          let
            args = [
              "${lib.getExe cfg.package}"
            ]
            ++ optional (cfg.socketGroup != null) "--socket-group=${cfg.socketGroup}"
            ++ optional (cfg.vmnetMode != null) "--vmnet-mode=${cfg.vmnetMode}"
            ++ optional (cfg.vmnetInterface != null) "--vmnet-interface=${cfg.vmnetInterface}"
            ++ optional (cfg.vmnetGateway != null) "--vmnet-gateway=${cfg.vmnetGateway}"
            ++ optional (cfg.vmnetDhcpEnd != null) "--vmnet-dhcp-end=${cfg.vmnetDhcpEnd}"
            ++ optional (cfg.vmnetMask != null) "--vmnet-mask=${cfg.vmnetMask}"
            ++ optional (cfg.vmnetInterfaceId != null) "--vmnet-interface-id=${cfg.vmnetInterfaceId}"
            ++ optional (
              cfg.vmnetNetworkIdentifier != null
            ) "--vmnet-network-identifier=${cfg.vmnetNetworkIdentifier}"
            ++ optional (cfg.vmnetNat66Prefix != null) "--vmnet-nat66-prefix=${cfg.vmnetNat66Prefix}"
            ++ optional (cfg.pidfile != null) "--pidfile=${cfg.pidfile}"
            ++ [ cfg.socketPath ];
          in
          args;
        RunAtLoad = true;
        KeepAlive = true;
        UserName = "root";
        ProcessType = "Interactive";
        StandardOutPath = "/var/log/socket_vmnet/stdout";
        StandardErrorPath = "/var/log/socket_vmnet/stderr";
      };
    };
  };
}
