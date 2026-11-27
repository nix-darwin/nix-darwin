{ config, pkgs, ... }:

let
  nix = pkgs.runCommand "nix-2.2" { } "mkdir -p $out";
in

{
  nix.optimise.automatic = true;
  nix.package = nix;

  test = ''
    echo checking nix-optimise service in /Library/LaunchDaemons >&2
    grep "<string>org.nixos.nix-optimise</string>" \
      ${config.out}/Library/LaunchDaemons/org.nixos.nix-optimise.plist
    grep -F "${nix}/bin/nix-store --optimise" \
      ${config.out}/Library/LaunchDaemons/org.nixos.nix-optimise.plist
    (! grep "<key>KeepAlive</key>" ${config.out}/Library/LaunchDaemons/org.nixos.nix-optimise.plist)
  '';
}
