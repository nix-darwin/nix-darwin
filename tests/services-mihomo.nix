{
  config,
  lib,
  pkgs,
  ...
}:

let
  mihomo = pkgs.writeShellScriptBin "mihomo" "";
  configFile = "/etc/mihomo/config.yaml";
  webui = pkgs.runCommand "mihomo-webui" { } "mkdir -p $out";
in
{
  services.mihomo = {
    enable = true;
    package = mihomo;
    inherit configFile webui;
    extraOpts = "--log-level info";
  };

  test = ''
    serviceFile=${config.out}/Library/LaunchDaemons/org.nixos.mihomo.plist
    grep -q "org.nixos.mihomo" "$serviceFile"
    grep -q "mihomo" "$serviceFile"
    grep -q -- "-d" "$serviceFile"
    grep -q "/var/db/mihomo" "$serviceFile"
    grep -q -- "-f" "$serviceFile"
    grep -q "/etc/mihomo/config.yaml" "$serviceFile"
    grep -q "webui" "$serviceFile"
    grep -q -- "--log-level info" "$serviceFile"
    grep -q "<key>UserName</key>" "$serviceFile"
    grep -q "<string>root</string>" "$serviceFile"
    grep -q "/var/db/mihomo" ${config.out}/activate
  '';
}
