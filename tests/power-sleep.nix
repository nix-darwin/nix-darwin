{ config, pkgs, ... }:

{
  power.sleep.computer = "never";
  power.sleep.display = 15;
  power.sleep.harddisk = 5;
  power.sleep.allowSleepByPowerButton = false;

  test = ''
    echo checking power sleep settings in /activate >&2
    grep "systemsetup -setComputerSleep 'never'" ${config.out}/activate
    grep "systemsetup -setDisplaySleep '15'" ${config.out}/activate
    grep "systemsetup -setHardDiskSleep '5'" ${config.out}/activate
    grep "systemsetup -setAllowPowerButtonToSleepComputer" ${config.out}/activate
  '';
}
