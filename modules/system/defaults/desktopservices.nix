{ config, lib, ... }:

with lib;
{
  options = {

    system.defaults.desktopservices.DSDontWriteNetworkStores = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Disable creation of metadata files (.DS_Store/AppleDouble files) on network volumes.
        Default is to create (false).
      '';
    };

    system.defaults.desktopservices.DSDontWriteUSBStores = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Disable creation of metadata files (.DS_Store/AppleDouble files) on USB volumes.
        Default is to create (false).
      '';
    };
  };
}
