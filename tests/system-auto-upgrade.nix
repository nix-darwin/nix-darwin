{ config, pkgs, ... }:

let
  nix = pkgs.runCommand "nix-2.2" { } "mkdir -p $out/bin";
  darwin-rebuild = pkgs.runCommand "darwin-rebuild" { } "mkdir -p $out/bin";
in

{
  system.autoUpgrade.enable = true;
  system.autoUpgrade.flake = "github:sinrohit/nixos-config";
  system.autoUpgrade.flags = [
    "--update-input"
    "nixpkgs"
  ];
  system.autoUpgrade.interval = [
    {
      Weekday = 7;
      Hour = 3;
      Minute = 15;
    }
  ];

  nix.package = nix;
  system.build.darwin-rebuild = darwin-rebuild;

  test = ''
    echo checking nix-darwin-upgrade service in /Library/LaunchDaemons >&2
    grep "<string>org.nixos.nix-darwin-upgrade</string>" ${config.out}/Library/LaunchDaemons/org.nixos.nix-darwin-upgrade.plist

    echo checking ProgramArguments references start script >&2
    grep "nix-darwin-upgrade-start" ${config.out}/Library/LaunchDaemons/org.nixos.nix-darwin-upgrade.plist

    echo checking StartCalendarInterval >&2
    grep "<key>StartCalendarInterval</key>" ${config.out}/Library/LaunchDaemons/org.nixos.nix-darwin-upgrade.plist
    grep "<key>Weekday</key>" ${config.out}/Library/LaunchDaemons/org.nixos.nix-darwin-upgrade.plist
    grep "<integer>7</integer>" ${config.out}/Library/LaunchDaemons/org.nixos.nix-darwin-upgrade.plist
    grep "<key>Hour</key>" ${config.out}/Library/LaunchDaemons/org.nixos.nix-darwin-upgrade.plist
    grep "<integer>3</integer>" ${config.out}/Library/LaunchDaemons/org.nixos.nix-darwin-upgrade.plist
    grep "<key>Minute</key>" ${config.out}/Library/LaunchDaemons/org.nixos.nix-darwin-upgrade.plist
    grep "<integer>15</integer>" ${config.out}/Library/LaunchDaemons/org.nixos.nix-darwin-upgrade.plist

    echo checking log paths >&2
    grep "<string>/var/log/nix-darwin-upgrade/nix-darwin-upgrade.log</string>" ${config.out}/Library/LaunchDaemons/org.nixos.nix-darwin-upgrade.plist

    echo checking RunAtLoad is false >&2
    grep -A1 "<key>RunAtLoad</key>" ${config.out}/Library/LaunchDaemons/org.nixos.nix-darwin-upgrade.plist | grep "<false/>"
  '';
}
