{ config, pkgs, ... }:

let
  hello = pkgs.runCommand "hello-0.0.0" { } ''
    mkdir -p $out/bin $out/lib
    touch $out/bin/hello $out/lib/libhello.dylib
  '';
in

{
  environment.systemPackages = [ hello ];

  test = ''
    echo checking hello binary in /sw/bin >&2
    test -e ${config.out}/sw/bin/hello
    test "$(readlink -f ${config.out}/sw/bin/hello)" = "${hello}/bin/hello"

    echo checking for unexpected paths in /sw/bin >&2
    test -e ${config.out}/sw/lib/libhello.dylib && return
  '';
}
