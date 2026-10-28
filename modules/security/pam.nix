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
    security.pam = {
      services.sudo_local = {
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

        u2fAuth = lib.mkOption {
          default = config.security.pam.u2f.enable;
          defaultText = lib.literalExpression "config.security.pam.u2f.enable";
          type = lib.types.bool;
          description = ''
            If set, users listed in
            {file}`$XDG_CONFIG_HOME/Yubico/u2f_keys` (or
            {file}`$HOME/.config/Yubico/u2f_keys` if XDG variable is
            not set) are able to log in with the associated U2F key. Path can be
            changed using {option}`security.pam.u2f.authFile` option.
            Note that on macOS, openpam is not able to drop privileges to read a user file,
            so the u2f_keys file must be placed in a root-accessible directory like {file}`/etc/u2f_mappings`.
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
      u2f = {
        enable = lib.mkOption {
          default = false;
          type = lib.types.bool;
          description = ''
            Enables U2F PAM (`pam-u2f`) module.

            If set, users listed in
            {file}`$XDG_CONFIG_HOME/Yubico/u2f_keys` (or
            {file}`$HOME/.config/Yubico/u2f_keys` if XDG variable is
            not set) are able to log in with the associated U2F key. The path can
            be changed using {option}`security.pam.u2f.authFile` option.

            File format is:
            ```
            <username1>:<KeyHandle1>,<UserKey1>,<CoseType1>,<Options1>:<KeyHandle2>,<UserKey2>,<CoseType2>,<Options2>:...
            <username2>:<KeyHandle1>,<UserKey1>,<CoseType1>,<Options1>:<KeyHandle2>,<UserKey2>,<CoseType2>,<Options2>:...
            ```
            This file can be generated using {command}`pamu2fcfg` command.

            More information can be found [here](https://developers.yubico.com/pam-u2f/).
          '';
        };
        control = lib.mkOption {
          default = "sufficient";
          type = lib.types.enum [
            "required"
            "requisite"
            "sufficient"
            "optional"
          ];
          description = ''
            This option sets pam "control".
            If you want to have multi factor authentication, use "required".
            If you want to use U2F device instead of regular password, use "sufficient".

            Read
            {manpage}`pam.conf(5)`
            for better understanding of this option.
          '';
        };
        settings = lib.mkOption {
          type = lib.types.submodule {
            freeformType =
              with lib.types;
              attrsOf (
                nullOr (oneOf [
                  bool
                  str
                  int
                  pathInStore
                ])
              );
            options = {
              authfile = lib.mkOption {
                default = null;
                type = with lib.types; nullOr path;
                description = ''
                  By default `pam-u2f` module reads the keys from
                  {file}`$XDG_CONFIG_HOME/Yubico/u2f_keys` (or
                  {file}`$HOME/.config/Yubico/u2f_keys` if XDG variable is
                  not set).

                  If you want to change auth file locations or centralize database (for
                  example use {file}`/etc/u2f-mappings`) you can set this
                  option.
                  Note that on macOS, openpam is not able to drop privileges to read a user file,
                  so the u2f_keys file must be placed in a root-accessible directory like {file}`/etc/u2f_mappings`.

                  File format is:
                  `username:first_keyHandle,first_public_key: second_keyHandle,second_public_key`
                  This file can be generated using {command}`pamu2fcfg` command.

                  More information can be found [here](https://developers.yubico.com/pam-u2f/).
                '';
              };

              appid = lib.mkOption {
                default = null;
                type = with lib.types; nullOr str;
                description = ''
                  By default `pam-u2f` module sets the application
                  ID to `pam://$HOSTNAME`.

                  When using {command}`pamu2fcfg`, you can specify your
                  application ID with the `-i` flag.

                  More information can be found [here](https://developers.yubico.com/pam-u2f/Manuals/pam_u2f.8.html)
                '';
              };

              origin = lib.mkOption {
                default = null;
                type = with lib.types; nullOr str;
                description = ''
                  By default `pam-u2f` module sets the origin
                  to `pam://$HOSTNAME`.
                  Setting origin to an host independent value will allow you to
                  reuse credentials across machines

                  When using {command}`pamu2fcfg`, you can specify your
                  application ID with the `-o` flag.

                  More information can be found [here](https://developers.yubico.com/pam-u2f/Manuals/pam_u2f.8.html)
                '';
              };

              debug = lib.mkOption {
                default = false;
                type = lib.types.bool;
                description = ''
                  Debug output to stderr.
                '';
              };

              interactive = lib.mkOption {
                default = false;
                type = lib.types.bool;
                description = ''
                  Set to prompt a message and wait before testing the presence of a U2F device.
                  Recommended if your device doesn’t have a tactile trigger.
                '';
              };

              cue = lib.mkOption {
                default = false;
                type = lib.types.bool;
                description = ''
                  By default `pam-u2f` module does not inform user
                  that he needs to use the u2f device, it just waits without a prompt.

                  If you set this option to `true`,
                  `cue` option is added to `pam-u2f`
                  module and reminder message will be displayed.
                '';
              };
            };
          };
          default = { };
          example = {
            authfile = "/etc/u2f_keys";
            authpending_file = "";
            userpresence = 0;
            pinverification = 1;
          };
          description = ''
            Options to pass to the PAM module.

            Boolean values render just the key if true, and nothing if false.
            Null values are ignored.
            All other values are rendered as key-value pairs.
          '';
        };
      };
    };
  };

  config =
    let
      u2fArgs = lib.concatLists (
        lib.flip lib.mapAttrsToList config.security.pam.u2f.settings (
          name: value:
          if lib.isBool value then
            lib.optional value name
          else
            lib.optional (value != null) "${name}=${toString value}"
        )
      );
    in
    {
      security.pam.services.sudo_local.text = lib.concatLines (
        (lib.optional cfg.reattach "auth       optional       ${pkgs.pam-reattach}/lib/pam/pam_reattach.so")
        ++ (lib.optional cfg.u2fAuth "auth       ${config.security.pam.u2f.control}${
          lib.concatStrings (lib.replicate (15 - lib.stringLength config.security.pam.u2f.control) " ")
        }${pkgs.pam_u2f}/lib/security/pam_u2f.so ${lib.concatStringsSep " " u2fArgs}")
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
