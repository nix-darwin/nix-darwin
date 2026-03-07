{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.security.pam.services.sudo_local;
in
{
  imports = [
    (lib.mkRemovedOptionModule [ "security" "pam" "enableSudoTouchIdAuth" ] ''
      This option has been renamed to `security.pam.services.sudo_local.touchIdAuth` for consistency with NixOS.
    '')
  ];

  options = {
    security.pam.services.sudo_local = {
      enable = lib.mkEnableOption "managing {file}`/etc/pam.d/sudo_local` with nix-darwin" // {
        default = true;
        example = false;
      };

      text = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = ''
          Contents of {file}`/etc/pam.d/sudo_local`
        '';
      };

      touchIdAuth = lib.mkEnableOption "" // {
        description = ''
          Whether to enable Touch ID with sudo.

          This will also allow your Apple Watch to be used for sudo. If this doesn't work,
          you can go into `System Settings > Touch ID & Password` and toggle the switch for
          your Apple Watch.
        '';
      };

      watchIdAuth = lib.mkEnableOption "" // {
        description = ''
          Use Apple Watch for sudo authentication, for devices without Touch ID or 
          laptops with lids closed, consider using this.

          When enabled, you can use your Apple Watch to authenticate sudo commands.
          If this doesn't work, you can go into `System Settings > Touch ID & Password`
          and toggle the switch for your Apple Watch.
        '';
      };

      reattach = lib.mkEnableOption "" // {
        description = ''
          Whether to enable reattaching a program to the user's bootstrap session.

          This fixes Touch ID for sudo not working inside tmux and screen.

          This allows programs like tmux and screen that run in the background to
          survive across user sessions to work with PAM services that are tied to the
          bootstrap session.
        '';
      };
    };
  };

  config = {
    security.pam.services.sudo_local.text = lib.concatLines (
      (lib.optional cfg.reattach "auth       optional       ${pkgs.pam-reattach}/lib/pam/pam_reattach.so")
      ++ (lib.optional cfg.touchIdAuth "auth       sufficient     pam_tid.so")
      ++ (lib.optional cfg.watchIdAuth "auth       sufficient     ${pkgs.pam-watchid}/lib/pam_watchid.so")
    );

    environment.etc."pam.d/sudo_local" = {
      inherit (cfg) enable text;
    };

    system.activationScripts.pam.text =
      let
        file = "/etc/pam.d/sudo";
        marker = "security.pam.services.sudo_local";
        deprecatedOption = "security.pam.enableSudoTouchIdAuth";
        sed = lib.getExe pkgs.gnused;
      in
      ''
        # PAM settings
        echo >&2 "setting up pam..."

        # REMOVEME when macOS 13 no longer supported as macOS automatically
        # nukes this file on system upgrade
        # Always clear out older implementation if it is present
        if grep '${deprecatedOption}' ${file} > /dev/null; then
          ${sed} -i '/${deprecatedOption}/d' ${file}
        fi

        ${
          if cfg.enable then
            ''
              # REMOVEME when macOS 13 no longer supported
              # `sudo_local` is automatically included after macOS 14
              if ! grep 'sudo_local' ${file} > /dev/null; then
                ${sed} -i '2iauth       include        sudo_local # nix-darwin: ${marker}' ${file}
              fi
            ''
          else
            ''
              # Remove include line if we added it
              if grep '${marker}' ${file} > /dev/null; then
                ${sed} -i '/${marker}/d' ${file}
              fi
            ''
        }
      '';
  };
}
