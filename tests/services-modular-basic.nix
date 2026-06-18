{ config, pkgs, ... }:

{
  system.primaryUser = "test-modular-user";

  system.services.foo = {
    process.argv = [ "${pkgs.hello}/bin/hello" "--greeting=hi" ];
  };

  test = ''
    echo "checking modular daemon plist exists" >&2
    plist=${config.system.build.launchd}/Library/LaunchDaemons/org.nixos.foo.plist
    test -f "$plist" || (echo "missing $plist" >&2; exit 1)

    . ${./lib/assertions.sh}
    assertFileContent "$plist" ${./fixtures/services-modular/basic-foo.plist}
  '';
}
