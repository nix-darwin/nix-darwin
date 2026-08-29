{ lib, ... }:

{
  options = {
    system.defaults.TextInputMenuAgent."NSStatusItem VisibleCC Item-0" = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      apply = v: if v == null then null else if v then 1 else 0;
      default = null;
      description = ''
        Show Text Input in the menu bar.

        Available settings:
          true   - Show in Menu Bar
          false  - Don't Show in Menu Bar

        This option mirrors the setting found in:
          System Settings > Control Center > Text Input
      '';
    };
  };
}
