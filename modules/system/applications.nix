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

      # Clean up for links created at the old location in HOME
      if ourLink ~/Applications; then
        rm ~/Applications
      elif ourLink ~/Applications/'Nix Apps'; then
        rm ~/Applications/'Nix Apps'
      fi

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
