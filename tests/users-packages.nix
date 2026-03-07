{ config, pkgs, ... }:

let
  hello = pkgs.runCommand "hello-0.0.0" { } ''
    mkdir -p $out/bin $out/lib
    touch $out/bin/hello $out/lib/libhello.dylib
  '';
in

{
  users.knownUsers = [ "foo" ];
  users.users.foo.uid = 42000;
  users.users.foo.gid = 42000;
  users.users.foo.description = "Foo user";
  users.users.foo.isHidden = false;
  users.users.foo.home = "/Users/foo";
  users.users.foo.shell = "/run/current-system/sw/bin/bash";
  users.users.foo.packages = [ hello ];

  test = ''
    echo checking hello binary in /etc/profiles/per-user/foo/bin >&2
    test -e ${config.out}/etc/profiles/per-user/foo/bin/hello
    test "$(readlink -f ${config.out}/etc/profiles/per-user/foo/bin/hello)" = "${hello}/bin/hello"

    echo checking for unexpected paths in /etc/profiles/per-user/foo/bin >&2
    test -e ${config.out}/etc/profiles/per-user/foo/lib/libhello.dylib && return

    echo "checking /etc/profiles/per-user/foo/bin in environment" >&2
    grep 'export PATH=.*:/etc/profiles/per-user/$USER/bin' ${config.system.build.setEnvironment}
  '';
}
