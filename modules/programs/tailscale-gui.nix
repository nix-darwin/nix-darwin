{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.programs.tailscale-gui;
in
{
  options = {
    programs.tailscale-gui = {
      enable = lib.mkEnableOption "the Tailscale GUI application";
      package = lib.mkPackageOption pkgs "Tailscale GUI" {
        default = [ "tailscale-gui" ];
      };
    };
  };

  config = lib.mkIf cfg.enable {
    system.activationScripts.applications.text = lib.mkAfter ''
      install -o root -g wheel -m0555 -d "/Applications/Tailscale.app"
      rsyncFlags=(
        --checksum
        --copy-unsafe-links
        --archive
        --delete
        --chmod=-w
        --no-group
        --no-owner
      )
      ${lib.getExe pkgs.rsync} "''${rsyncFlags[@]}" \
        ${cfg.package}/Applications/Tailscale.app/ /Applications/Tailscale.app
    '';
  };

  meta.maintainers = [
    lib.maintainers.anish
  ];
}
