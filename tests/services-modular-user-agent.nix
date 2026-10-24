{ config, pkgs, ... }:

{
  system.primaryUser = "alice";

  users.users.alice.services.foo = {
    process.argv = [ "${pkgs.hello}/bin/hello" ];
    configData."hello.conf".text = "port = 8080";
  };

  test = ''
    echo "checking user agent plist exists" >&2
    plist=${config.system.build.launchd}/user/Library/LaunchAgents/org.nixos.foo.plist
    test -f "$plist" || (echo "missing $plist" >&2; exit 1)

    . ${./lib/assertions.sh}
    assertFileContent "$plist" ${./fixtures/services-modular/user-agent.plist}

    echo "checking activation snippet wires ~alice/.config/system-services" >&2
    grep -F '~alice/.config/system-services' ${config.out}/activate || \
      (echo "expected ~alice/.config/system-services in activate script" >&2; exit 1)
  '';
}
