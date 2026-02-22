{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.system;

  mkNvramVariables = lib.attrsets.mapAttrsToList (
    name: value: "nvram ${lib.escapeShellArg name}=${lib.escapeShellArg value}"
  ) cfg.nvram.variables;
in

{
  meta.maintainers = [
    lib.maintainers.samasaur or "samasaur"
  ];

  options = {
    system.nvram.variables = lib.mkOption {
      type = with lib.types; attrsOf str;
      default = { };
      internal = true;
      example = {
        "StartupMute" = "%01";
      };
      description = ''
        Non-volatile RAM variables to set. Removing a key-value pair from this
        list will **not** return the variable to its previous value, but will
        no longer set its value on system configuration activations.
      '';
    };
  };

  config = {
    system.activationScripts.nvram.text = ''
      echo "setting nvram variables..." >&2

      ${builtins.concatStringsSep "\n" mkNvramVariables}
    '';
  };
}
