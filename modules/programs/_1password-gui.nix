{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.programs._1password-gui;
in
{
  options = {
    programs._1password-gui = {
      enable = lib.mkEnableOption "the 1Password GUI application";

      package = lib.mkPackageOption pkgs "1Password GUI" {
        default = [ "_1password-gui" ];
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Based on https://github.com/reckenrode/nixos-configs/blob/22b8357fc6ffbd0df5ce50dc417c23a807a268a2/modules/by-name/1p/1password/darwin-module.nix
    system.activationScripts.applications.text = lib.mkAfter ''
      install -o root -g wheel -m0555 -d "/Applications/1Password.app"

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

      ${lib.getExe pkgs.rsync} "''${rsyncFlags[@]}" \
        ${cfg.package}/Applications/1Password.app/ /Applications/1Password.app
    '';
  };
}

