{ config, ... }:

{
  homebrew.enable = true;
  homebrew.user = "test-homebrew-user";
  homebrew.onActivation.cleanup = "check";

  test = ''
    echo "checking that cleanup check is present in system checks" >&2
    grep 'brew bundle cleanup --file=' ${config.out}/activate

    echo "checking that brew bundle command does not have --cleanup flag" >&2
    if echo "${config.homebrew.onActivation.brewBundleCmd}" | grep -F -- '--cleanup' > /dev/null; then
      echo "Expected no --cleanup flag in brewBundleCmd"
      echo "Actual: ${config.homebrew.onActivation.brewBundleCmd}"
      exit 1
    fi
  '';
}
