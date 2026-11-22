{ config, extendModules, lib, pkgs, ... }:

with lib;

let
  runJob = import ./run-launchd-job.nix { inherit lib pkgs; };
  yabai = pkgs.writeShellScriptBin "yabai" ''
    [[ $# == 2 && $1 == -c ]] || exit 1
    cat "$2"
  '';
  withPackagePath = extendModules {
    modules = [ { services.yabai.package = lib.mkForce yabai.outPath; } ];
  };
in

{
  system.primaryUser = "test-yabai-user";

  services.yabai.enable = true;
  services.yabai.package = yabai;
  services.yabai.config = { focus_follows_mouse = "autoraise"; };
  services.yabai.extraConfig = "yabai -m rule --add app='System Preferences' manage=off";

  test = ''
    echo >&2 "checking yabai service in ~/Library/LaunchAgents"
    grep "org.nixos.yabai" ${config.out}/user/Library/LaunchAgents/org.nixos.yabai.plist
    grep -F "${lib.getExe yabai}" ${config.out}/user/Library/LaunchAgents/org.nixos.yabai.plist

    ${runJob config.launchd.user.agents.yabai} > yabairc
    diff -u - yabairc <<'CONFIG'
    yabai -m config focus_follows_mouse autoraise
    yabai -m rule --add app='System Preferences' manage=off
    CONFIG

    ${runJob withPackagePath.config.launchd.user.agents.yabai} > yabairc-from-path
    cmp yabairc yabairc-from-path
  '';
}
