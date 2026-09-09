{ config, lib, ... }:

with lib;

{
  options = {
    system.defaults.spaces.spans-displays = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Apple menu > System Preferences > Mission Control

        Displays have separate Spaces (note a logout is required before
        this setting will take effect).

        false = each physical display has a separate space (Mac default);
        true = one space spans across all physical displays
      '';
    };
  };
}
