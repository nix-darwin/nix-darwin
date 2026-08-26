{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.easytier;
  easytier_dir = config.launchd.daemons."easytier-test".serviceConfig.WorkingDirectory;
in
{
  services.easytier.enable = true;

  services.easytier.package = pkgs.writeShellScriptBin "easytier-core" "exit 0" // {
    meta.mainProgram = "easytier-core";
  };
  services.easytier.allowSystemForward = true;

  services.easytier.instances.test = {
    enable = true;
    settings = {
      network_name = "test_network";
      network_secret = "test_secret";
      ipv4 = "10.144.144.1/24";
      dhcp = true;
      peers = [ "tcp://example.com:11010" ];
    };
  };

  test = ''
    echo >&2 "checking easytier service in Library/LaunchDaemons"

    # Check that the plist file was generated and contains the expected Label
    grep "org.nixos.easytier-test" ${config.out}/Library/LaunchDaemons/org.nixos.easytier-test.plist

    # Extract the launch script path
    script_path=$(grep -oE '/nix/store/[a-zA-Z0-9.-]+easytier-test-start' ${config.out}/Library/LaunchDaemons/org.nixos.easytier-test.plist | head -n 1)

    echo >&2 "checking execution script: $script_path"

    # Extract the generated .toml config file path
    conf=$(grep -oE '/nix/store/[a-zA-Z0-9.-]+easytier-test\.toml' "$script_path" | head -n 1)

    echo >&2 "checking config in $conf"
    grep 'network_name = "${cfg.instances.test.settings.network_name}"' "$conf"
    grep 'network_secret = "${cfg.instances.test.settings.network_secret}"' "$conf"
    grep 'ipv4 = "${cfg.instances.test.settings.ipv4}"' "$conf"
    grep 'dhcp = ${lib.boolToString cfg.instances.test.settings.dhcp}' "$conf"
    grep 'uri = "${builtins.head cfg.instances.test.settings.peers}"' "$conf"

    echo >&2 "checking easytier state directory setup in activate script"

    # Verify the activation script has the postActivation hook to create the directory
    grep "Setting up EasyTier directory for test" ${config.out}/activate
    grep ${lib.escapeShellArg "install -dm700 ${lib.escapeShellArg easytier_dir}"} ${config.out}/activate

    echo >&2 "checking sysctl config"

    # Verify that the system forward properties are written to /etc/sysctl.conf
    grep "net.inet.ip.forwarding=1" ${config.out}/etc/sysctl.conf
    grep "net.inet6.ip6.forwarding=1" ${config.out}/etc/sysctl.conf
  '';
}
