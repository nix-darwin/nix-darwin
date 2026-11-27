{ config, pkgs, ... }:

{
  system.primaryUser = "test-modular-user";

  system.services.foo = {
    process.argv = [ "${pkgs.hello}/bin/hello" ];
    configData."hello.conf".text = ''
      port = 8080
    '';
  };

  test = ''
    echo "checking configData etc entry created" >&2
    plist=${config.system.build.launchd}/Library/LaunchDaemons/org.nixos.foo.plist
    test -f "$plist" || (echo "missing $plist" >&2; exit 1)

    conf=${config.system.build.etc}/etc/system-services/foo/hello.conf
    test -e "$conf" || (echo "missing $conf" >&2; exit 1)

    . ${./lib/assertions.sh}
    assertFileContent "$plist" ${./fixtures/services-modular/configdata-foo.plist}
    assertFileContent "$conf" ${./fixtures/services-modular/configdata-foo-hello.conf}
  '';
}
