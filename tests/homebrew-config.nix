# Test homebrew configuration on the system

{ config, lib, ... }:

{
  homebrew.enable = true;

  test = ''
    echo 'checking Homebrew analytics' >&2
    noanalytics=$(bash -c 'source ${config.system.build.setEnvironment}; echo $HOMEBREW_NO_ANALYTICS')
    test "$noanalytics" = "1"
    # This setting is also used when brew is invoked by the activation script
    grep HOMEBREW_NO_ANALYTICS=1 ${config.out}/activate*
  '';
}
