{ config, ... }:

{
  system.primaryUser = "test-apple-developer-tools-user";
  environment.appleDeveloperTools.block = true;

  test = ''
    developerDir=${config.environment.variables.DEVELOPER_DIR}
    echo checking DEVELOPER_DIR in shell and launchd environments >&2
    grep -F "export DEVELOPER_DIR=\"$developerDir\"" ${config.system.build.setEnvironment}
    grep -F "launchctl setenv DEVELOPER_DIR '$developerDir'" ${config.out}/activate

    expectBlocked() {
      tool=$1
      shift
      status=0
      "$@" > stdout 2> stderr || status=$?
      test "$status" -eq 127
      test ! -s stdout
      grep -F "$tool: blocked by environment.appleDeveloperTools.block." stderr
    }

    echo checking the stub names the requested tool >&2
    expectBlocked git "$developerDir/usr/bin/xcrun" git --version
    expectBlocked xcrun "$developerDir/usr/bin/xcrun" --show-sdk-path
    expectBlocked xcrun "$developerDir/usr/bin/xcrun" not-an-apple-tool
    expectBlocked xcrun "$developerDir/usr/bin/xcrun"

    echo checking an Apple shim dispatches to the stub >&2
    DEVELOPER_DIR="$developerDir" expectBlocked git /usr/bin/git --version
  '';
}
