{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.tailscale;

in
{
  imports = [
    (mkRemovedOptionModule [ "services" "tailscale" "domain" ] "Tailscale no longer requires setting the search domain manually.")
    (mkRemovedOptionModule [ "services" "tailscale" "magicDNS" ] "MagicDNS no longer requires overriding the DNS servers, if this is necessary you can use `services.tailscale.overrideLocalDns`.")
  ];

  options.services.tailscale = {
    enable = mkEnableOption "Tailscale client daemon";

    package = mkOption {
      type = types.package;
      default = pkgs.tailscale;
      defaultText = literalExpression "pkgs.tailscale";
      description = "The package to use for tailscale";
    };

    overrideLocalDns = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        This option implements `Override local DNS` as it is not yet implemented in Tailscaled-on-macOS.

        To use this option, in the Tailscale control panel:
          1. at least one DNS server is added
          2. `Override local DNS` is enabled

        As this option sets 100.100.100.100 and fd7a:115c:a1e0::53 as your sole DNS servers, if the requirements above are not met,
        all non-MagicDNS queries WILL fail.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [{
      assertion = cfg.overrideLocalDns -> (builtins.any (x: x != "100.100.100.100" || x != "fd7a:115c:a1e0::53") config.networking.dns);
      message = ''
        DNS servers should be configured on the Tailscale control panel when `services.tailscale.overrideLocalDns` is enabled.

        A race condition can occur when DNS servers are set locally, leading to MagicDNS to not work.
      '';
    }];

    environment.systemPackages = [ cfg.package ];

    launchd.daemons.tailscaled = {
      # derived from
      # https://github.com/tailscale/tailscale/blob/main/cmd/tailscaled/install_darwin.go#L30
      command = lib.getExe' cfg.package "tailscaled";
      serviceConfig = {
        Label = "com.tailscale.tailscaled";
        RunAtLoad = true;
      };
    };

    networking.dns = mkIf cfg.overrideLocalDns [ "100.100.100.100" "fd7a:115c:a1e0::53" ];

    # Ensures Tailscale MagicDNS always works even without adding 100.100.100.100 to DNS servers
    environment.etc."resolver/ts.net".text = ''
      nameserver 100.100.100.100
      nameserver fd7a:115c:a1e0::53
    '';

    # This file gets created by tailscaled when `Override local DNS` is turned off
    environment.etc."resolver/ts.net".knownSha256Hashes = [
      "2c28f4fe3b4a958cd86b120e7eb799eee6976daa35b228c885f0630c55ef626c"
    ];

    # Cleaning up the .before-nix-darwin file is necessary as any files in /etc/resolver will be used.
    system.activationScripts.etc.text = mkAfter ''
      if [ -e /etc/resolver/ts.net.before-nix-darwin ]; then
        rm /etc/resolver/ts.net.before-nix-darwin
      fi
    '';
  };
}
