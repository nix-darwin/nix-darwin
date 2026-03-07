{ config, lib, ... }:

with lib;

{
  options = {

    system.defaults.magicmouse.MouseButtonMode = mkOption {
      type = types.nullOr (
        types.enum [
          "OneButton"
          "TwoButton"
        ]
      );
      default = null;
      description = ''
        "OneButton": any tap is a left click.  "TwoButton": allow left-
        and right-clicking.
      '';
    };

  };
}
