{ config, lib, ... }:

let
  cfg = config.system.resumeApps;
in

{
  options.system.resumeApps.enable = lib.mkOption {
    type = lib.types.nullOr lib.types.bool;
    default = null;
    example = false;
    description = ''
      Whether to reopen apps when logging back in after a logout, restart,
      or shutdown. This sets the "Reopen windows when logging back in"
      checkbox in the logout, restart, and shutdown dialogs.

      Applies to {option}`system.primaryUser`. When null, this option leaves
      the preference unmanaged. The macOS default is true.
      The user can change this setting in those dialogs after activation.
    '';
  };

  config = lib.mkIf (cfg.enable != null) {
    system = {
      requiresPrimaryUser = [ "system.resumeApps.enable" ];
      defaults.CustomUserPreferences."com.apple.loginwindow".TALLogoutSavesState = cfg.enable;
    };
  };
}
