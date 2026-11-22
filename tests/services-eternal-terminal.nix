{ config, extendModules, lib, pkgs, ... }:

with lib;

let
  eternal-terminal = pkgs.runCommand "eternal-terminal-0.0.0" { } "mkdir $out";
  withPackagePath = extendModules {
    modules = [ { services.eternal-terminal.package = lib.mkForce eternal-terminal.outPath; } ];
  };

in {
  services.eternal-terminal.enable = true;
  services.eternal-terminal.package = eternal-terminal;
  services.eternal-terminal.port = 2222;
  services.eternal-terminal.silent = true;

  test = ''
    echo >&2 "checking eternal-terminal service in /Library/LaunchDaemons"
    for system in ${config.out} ${withPackagePath.config.out}; do
      plist="$system/Library/LaunchDaemons/org.nixos.eternal-terminal.plist"
      grep -F "org.nixos.eternal-terminal" "$plist"
      grep -F "${lib.getExe' eternal-terminal "etserver"}" "$plist"
    done
  '';
}
