{ config, lib, ... }:

with lib;

let
  cfg = config.security.sudo;
in
{
  meta.maintainers = [
    lib.maintainers.samasaur or "samasaur"
  ];

  options = {
    security.sudo.adminNeedsPassword = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether users of the `admin` group must provide a password to run
        commands as super user via {command}`sudo`.
      '';
    };

    security.sudo.extraConfig = mkOption {
      type = types.nullOr types.lines;
      default = null;
      description = ''
        Extra configuration text appended to {file}`sudoers`.
      '';
    };
  };

  config = {
    # Early so later rules can override it, yet late enough for a user to `mkBefore` it.
    security.sudo.extraConfig = mkIf (!cfg.adminNeedsPassword) (mkOrder 600 "%admin ALL=(ALL) NOPASSWD: ALL");

    environment.etc = {
      "sudoers.d/10-nix-darwin-extra-config" = mkIf (cfg.extraConfig != null) {
        text = cfg.extraConfig;
      };
    };
  };
}
