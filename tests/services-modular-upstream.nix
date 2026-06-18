{ config, pkgs, lib, ... }:
{
  system.primaryUser = "test-modular-upstream";

  system.services.ghostunnel = {
    imports = [ pkgs.ghostunnel.passthru.services.default ];
    ghostunnel.listen = "localhost:8443";
    ghostunnel.target = "localhost:8080";
    ghostunnel.disableAuthentication = true;
  };

  test = ''
    echo "checking ghostunnel daemon plist exists" >&2
    plist=${config.system.build.launchd}/Library/LaunchDaemons/org.nixos.ghostunnel.plist
    test -f "$plist" || (echo "missing $plist" >&2; exit 1)

    . ${./lib/assertions.sh}
    assertFileContent "$plist" ${./fixtures/services-modular/upstream-ghostunnel.plist}
  '';
}
