{
  config,
  lib,
  pkgs,
  ...
}:

let
  nebula =
    pkgs.runCommand "nebula-0.0.0" { }
      "mkdir -p $out/bin && touch $out/bin/nebula && chmod +x $out/bin/nebula";
  mynetPlist = "${config.out}/Library/LaunchDaemons/org.nixos.nebula-mynet.plist";
  lighthousePlist = "${config.out}/Library/LaunchDaemons/org.nixos.nebula-lighthouse.plist";
in

{
  services.nebula.package = nebula;

  services.nebula.networks."mynet" = {
    ca = "/etc/nebula/ca.crt";
    cert = "/etc/nebula/host.crt";
    key = "/etc/nebula/host.key";
    lighthouses = [ "192.168.100.1" ];
    firewall.outbound = [
      {
        port = "any";
        proto = "any";
        host = "any";
      }
    ];
    firewall.inbound = [
      {
        port = "any";
        proto = "any";
        host = "any";
      }
    ];
  };

  services.nebula.networks."lighthouse" = {
    ca = "/etc/nebula/ca.crt";
    cert = "/etc/nebula/lighthouse.crt";
    key = "/etc/nebula/lighthouse.key";
    isLighthouse = true;
  };

  test = ''
    echo >&2 "checking nebula-mynet daemon plist"
    grep "org.nixos.nebula-mynet" ${mynetPlist}
    grep "${nebula}/bin/nebula" ${mynetPlist}
    grep "nebula-config-mynet.yml" ${mynetPlist}

    echo >&2 "checking nebula-lighthouse daemon plist"
    grep "org.nixos.nebula-lighthouse" ${lighthousePlist}
    grep "${nebula}/bin/nebula" ${lighthousePlist}

    echo >&2 "checking launchd service config"
    grep "<key>KeepAlive</key>" ${mynetPlist}

    echo >&2 "checking generated YAML configs"
    # Extract config file paths from plists
    mynet_config=$(grep -o '/nix/store/[^ ]*nebula-config-mynet\.yml' ${mynetPlist} | head -1)
    lighthouse_config=$(grep -o '/nix/store/[^ ]*nebula-config-lighthouse\.yml' ${lighthousePlist} | head -1)
    test -f "$mynet_config" || { echo >&2 "FAIL: mynet config not found"; exit 1; }
    test -f "$lighthouse_config" || { echo >&2 "FAIL: lighthouse config not found"; exit 1; }

    echo >&2 "checking tun.dev is absent when tun.device is null (Darwin uses utun)"
    ! grep 'dev:' "$mynet_config"

    echo >&2 "checking lighthouse defaults to port 4242"
    grep 'port: 4242' "$lighthouse_config"

    echo >&2 "checking basic node defaults to port 0"
    grep 'port: 0' "$mynet_config"

    echo >&2 "checking lighthouse am_lighthouse is true"
    grep 'am_lighthouse: true' "$lighthouse_config"
  '';
}
