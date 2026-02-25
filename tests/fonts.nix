{ config, pkgs, ... }:

let
  font = pkgs.runCommand "font-0.0.0" { } ''
    mkdir -p $out
    touch $out/Font.ttf
  '';
in

{
  fonts.packages = [ font ];

  test = ''
    echo "checking fonts in /Library/Fonts/Nix Fonts" >&2
    test -e "${config.out}/Library/Fonts/Nix Fonts"/*/Font.ttf

    echo "checking activation of fonts in /activate" >&2
    grep '/Library/Fonts/Nix Fonts' ${config.out}/activate
  '';
}
