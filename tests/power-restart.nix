{ config, pkgs, ... }:

{
  power.restartAfterPowerFailure = true;
  power.restartAfterFreeze = true;

  test = ''
    echo checking restart power settings in /activate >&2
    grep "systemsetup -setRestartPowerFailure" ${config.out}/activate
    grep "systemsetup -setRestartFreeze" ${config.out}/activate
  '';
}
