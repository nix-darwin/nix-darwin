{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  eternal-terminal = pkgs.runCommand "eternal-terminal-0.0.0" { } "mkdir $out";

in
{
  services.eternal-terminal.enable = true;
  services.eternal-terminal.package = eternal-terminal;
  services.eternal-terminal.port = 2222;
  services.eternal-terminal.silent = true;

  test = ''
    echo >&2 "checking eternal-terminal service in /Library/LaunchDaemons"
    grep "org.nixos.eternal-terminal" ${config.out}/Library/LaunchDaemons/org.nixos.eternal-terminal.plist
    grep "${eternal-terminal}/bin/etserver" ${config.out}/Library/LaunchDaemons/org.nixos.eternal-terminal.plist
  '';
}
