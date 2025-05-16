{ lib, mkTextDerivation }:

{ config, name, ... }:

with lib;

let
  fileName = file: last (splitString "/" file);
  mkDefaultIf = cond: value: mkIf cond (mkDefault value);

  drv = mkTextDerivation (fileName name) config.text;
in

{
  options = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether this file should be generated.
        This option allows specific files to be disabled.
      '';
    };

    text = mkOption {
      type = types.lines;
      default = "";
      description = ''
        Text of the file.
      '';
    };

    target = mkOption {
      type = types.str;
      default = "/${name}";
      description = ''
        Name of symlink.  Defaults to the attribute name preceded by a slash (the root directory).
      '';
    };

    source = mkOption {
      type = types.path;
      description = ''
        Path of the source file.
      '';
    };
  };

  config = {
    source = mkDefault drv;
  };
}
