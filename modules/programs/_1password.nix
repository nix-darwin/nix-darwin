{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.programs._1password;
in
{
  options = {
    programs._1password = {
      enable = lib.mkEnableOption "the 1Password CLI tool";

      package = lib.mkPackageOption pkgs "1Password CLI" {
        default = [ "_1password-cli" ];
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Integration with the 1Password GUI will only work if the CLI at `/usr/local/bin/op`
    # Based on https://github.com/reckenrode/nixos-configs/blob/22b8357fc6ffbd0df5ce50dc417c23a807a268a2/modules/by-name/1p/1password/darwin-module.nix
    system.activationScripts.applications.text = lib.mkAfter ''
      install -o root -g wheel -m0555 -D \
        ${lib.getExe cfg.package} /usr/local/bin/op
    '';
  };
}

