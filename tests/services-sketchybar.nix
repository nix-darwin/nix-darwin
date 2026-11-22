{ config, lib, pkgs, ... }:

let
  runJob = import ./run-launchd-job.nix { inherit lib pkgs; };
  sketchybar = pkgs.writeShellScriptBin "sketchybar" ''
    [[ $# == 2 && $1 == --config ]] || exit 1
    cat "$2"
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
    ${runJob config.launchd.user.agents.sketchybar} > sketchybarrc
    grep -Fx 'sketchybar --bar height=24' sketchybarrc
    grep -Fx 'sketchybar --update' sketchybarrc
    grep "${dummyPkg}/bin" ${config.out}/user/Library/LaunchAgents/org.nixos.sketchybar.plist
    grep "<key>KeepAlive</key>" ${config.out}/user/Library/LaunchAgents/org.nixos.sketchybar.plist
    grep "<key>RunAtLoad</key>" ${config.out}/user/Library/LaunchAgents/org.nixos.sketchybar.plist
  '';
}
