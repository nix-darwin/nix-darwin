{ config, pkgs, ... }:

let
  sketchybar = pkgs.runCommand "sketchybar-0.0.0" { meta.mainProgram = "sketchybar"; } ''
    mkdir -p $out/bin
    cat <<'EOF' > $out/bin/sketchybar
    #!/bin/sh
    exit 0
    EOF
    chmod +x $out/bin/sketchybar
  '';

  dummyPkg = pkgs.runCommand "dummy-tool-0.0.0" { } "mkdir -p $out/bin";
in

{
  system.primaryUser = "test-sketchybar-user";

  services.sketchybar.enable = true;
  services.sketchybar.package = sketchybar;
  services.sketchybar.extraPackages = [ dummyPkg ];
  services.sketchybar.config = ''
    sketchybar --bar height=24
    sketchybar --update
  '';

  test = ''
    echo "checking sketchybar user launch agent in ~/Library/LaunchAgents" >&2
    grep "<string>org.nixos.sketchybar</string>" ${config.out}/user/Library/LaunchAgents/org.nixos.sketchybar.plist
    grep "<string>${sketchybar}/bin/sketchybar</string>" ${config.out}/user/Library/LaunchAgents/org.nixos.sketchybar.plist
    grep "<string>--config</string>" ${config.out}/user/Library/LaunchAgents/org.nixos.sketchybar.plist
    grep "<string>${dummyPkg}</string>" ${config.out}/user/Library/LaunchAgents/org.nixos.sketchybar.plist
    grep "<key>KeepAlive</key>" ${config.out}/user/Library/LaunchAgents/org.nixos.sketchybar.plist
    grep "<key>RunAtLoad</key>" ${config.out}/user/Library/LaunchAgents/org.nixos.sketchybar.plist
  '';
}
