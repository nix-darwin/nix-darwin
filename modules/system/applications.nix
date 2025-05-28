{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.system;
in

{
  options = {
  };

  config = {

    system.checks.text = lib.mkAfter ''
      # touch can show multiple errors
      # Operation not permitted: Likely means that you do not have application management permission yet
      # Permission denied: Likely means that you do not have full disk access permission or do not have enough privileges
      isMissingPermissionToModifyApps() {
        for appBundle in /Applications/Nix\ Apps/*.app; do
            if [ -d "$appBundle" ]; then
                touch "$appBundle/.DS_Store" || return 0
            fi
        done
        return 1
      }
      if isMissingPermissionToModifyApps; then
          printf >&2 '\e[1;31merror: Missing permission to modify apps, aborting activation\e[0m\n'
          printf >&2 'The current Application you are using to execute darwin-rebuild switch\n'
          printf >&2 'is missing one of the required permissions to modify the Applications in\n'
          printf >&2 '/Applications/Nix Apps.\n'
          printf >&2 '\n'
          printf >&2 'This means that you will either have to accept the permission prompt\n'
          printf >&2 'by MacOS, or add the permission manually in System Preferences.\n'
          printf >&2 '\n'
          printf >&2 'To add the necessary permission manually, go to System Preferences,\n'
          printf >&2 'Security & Privacy, Privacy tab, and add the current Application to\n'
          printf >&2 '"Full Disk Access" and "App Management".\n'
          exit 2
      fi
    '';

    system.build.applications = pkgs.buildEnv {
      name = "system-applications";
      paths = config.environment.systemPackages;
      pathsToLink = "/Applications";
    };

    system.activationScripts.applications.text = ''
      # Set up applications.
      echo "setting up /Applications/Nix Apps..." >&2

      ourLink () {
        local link
        link=$(readlink "$1")
        [ -L "$1" ] && [ "''${link#*-}" = 'system-applications/Applications' ]
      }

      ${lib.optionalString (config.system.primaryUser != null) ''
        # Clean up for links created at the old location in HOME
        # TODO: Remove this in 25.11.
        if ourLink ~${config.system.primaryUser}/Applications; then
          rm ~${config.system.primaryUser}/Applications
        elif ourLink ~${config.system.primaryUser}/Applications/'Nix Apps'; then
          rm ~${config.system.primaryUser}/Applications/'Nix Apps'
        fi
      ''}

      targetFolder='/Applications/Nix Apps'

      # Clean up old style symlink to nix store
      if [ -e "$targetFolder" ] && ourLink "$targetFolder"; then
        rm "$targetFolder"
      fi

      mkdir -p "$targetFolder"

      rsyncFlags=(
        # mtime is standardized in the nix store, which would leave only file size to distinguish files.
        # Thus we need checksums, despite the speed penalty.
        --checksum
        # Converts all symlinks pointing outside of the copied tree (thus unsafe) into real files and directories.
        # This neatly converts all the symlinks pointing to application bundles in the nix store into
        # real directories, without breaking any relative symlinks inside of application bundles.
        # This is good enough, because the make-symlinks-relative.sh setup hook converts all $out internal
        # symlinks to relative ones.
        --copy-unsafe-links
        --archive
        --delete
        --chmod=-w
        --no-group
        --no-owner
      )

      ${lib.getExe pkgs.rsync} "''${rsyncFlags[@]}" ${cfg.build.applications}/Applications/ "$targetFolder"
    '';

  };
}
