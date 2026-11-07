{ config, ... }:

{
  environment.appleDeveloperTools.block = true;

  test = ''
    echo checking Apple developer tool blockers in systemPath >&2
    blockers=$(grep -oE '/nix/store/[^:]+-apple-developer-tools-blockers/bin' ${config.system.build.setEnvironment})
    grep -F "/nix/var/nix/profiles/default/bin:$blockers:/usr/local/bin" ${config.system.build.setEnvironment}

    for tool in gcc xcodebuild; do
      echo "checking $tool is blocked" >&2
      status=0
      "$blockers/$tool" > stdout 2> stderr || status=$?
      test "$status" -eq 127
      test ! -s stdout
      grep -F "$tool: Apple developer tools are blocked by nix-darwin" stderr
    done
  '';
}
