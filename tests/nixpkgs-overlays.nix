{ config, pkgs, ... }:

{
  nixpkgs.overlays = [
    (self: super: {
      hello = super.runCommand "hello" { } "mkdir $out";
    })
  ];

  test = ''
    echo checking /bin/hello >&2
    (! ${pkgs.hello}/bin/hello)
  '';
}
