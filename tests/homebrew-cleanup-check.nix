{ config, ... }:

let
  brewBundleInstallCmd = config.homebrew.onActivation.brewBundleCmd { onlyCheck = false; };
in

{
  homebrew.enable = true;
  homebrew.user = "test-homebrew-user";
  homebrew.onActivation.cleanup = "check";

  test = ''
    echo "checking that cleanup check is present in system checks" >&2
    grep "brew bundle --file='.*-Brewfile' cleanup" ${config.out}/activate

    echo "checking that brew bundle [install] command does not have --cleanup flag" >&2
    if echo "${brewBundleInstallCmd}" | grep -F -- '--cleanup' > /dev/null; then
      echo "Expected no --cleanup flag in brewBundleInstallCmd"
      echo "Actual: ${brewBundleInstallCmd}"
      exit 1
    fi
  '';
}
