{ config, pkgs, ... }:

{
  power.sleep.ac.computer = "never";
  power.sleep.ac.display = 10;
  power.sleep.battery.computer = 15;
  power.sleep.battery.harddisk = 5;

  test = ''
    echo checking per-source power sleep settings in /activate >&2
    grep "pmset -c sleep 0" ${config.out}/activate
    grep "pmset -c displaysleep 10" ${config.out}/activate
    grep "pmset -b sleep 15" ${config.out}/activate
    grep "pmset -b disksleep 5" ${config.out}/activate
    (! grep "pmset -c disksleep" ${config.out}/activate)
    (! grep "pmset -b displaysleep" ${config.out}/activate)
  '';
}
