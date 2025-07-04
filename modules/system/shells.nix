{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.environment;
in

{
  options = {
    environment.shells = mkOption {
      type = types.listOf (types.either types.shellPackage types.path);
      default = [ ];
      example = literalExpression "[ pkgs.bashInteractive pkgs.zsh ]";
      description = ''
        A list of permissible login shells for user accounts.

        The default macOS shells will be automatically included:
          - /bin/bash
          - /bin/csh
          - /bin/dash
          - /bin/ksh
          - /bin/sh
          - /bin/tcsh
          - /bin/zsh
      '';
      apply = map (v: if types.shellPackage.check v then "/run/current-system/sw${v.shellPath}" else v);
    };
  };

  config = mkIf (cfg.shells != [ ]) {

    environment.etc."shells".text = ''
      # List of acceptable shells for chpass(1).
      # Ftpd will not allow users to connect who are not using
      # one of these shells.

      /bin/bash
      /bin/csh
      /bin/dash
      /bin/ksh
      /bin/sh
      /bin/tcsh
      /bin/zsh

      # List of shells managed by nix.
      ${concatStringsSep "\n" cfg.shells}
    '';

    environment.etc."shells".knownSha256Hashes = [
      "9d5aa72f807091b481820d12e693093293ba33c73854909ad7b0fb192c2db193" # macOS
    ];

  };
}
