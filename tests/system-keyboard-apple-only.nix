{ config, pkgs, ... }:

{
  system.keyboard.enableKeyMapping = true;
  system.keyboard.appleKeyboardsOnly = true;
  system.keyboard.remapCapsLockToControl = true;
  system.keyboard.remapCapsLockToEscape = true;

  test = ''
    echo checking Apple keyboards only mappings in /activate >&2
    grep "hidutil property .* --matching '{\"VendorID\":0}'" ${config.out}/activate
  '';
}
