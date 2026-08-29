{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.services.math-symbols-input;
  package = pkgs.callPackage ./package { };

  plist-base-path = "com.mathsymbolsinput.inputmethod.MathSymbolsInput.plist ";
  plist-full-path = "~/Library/Preferences/${plist-base-path}";

  commands-to-plist = pkgs.callPackage ./commands-to-plist.nix { };
  custom-commands-plist = "${commands-to-plist cfg.symbols}/${plist-base-path}";

  command-to-run = pkgs.writeScriptBin "write_defaults" ''
    defaults write ${plist-full-path} "$(defaults read ${custom-commands-plist} | sed 's|\\\\|\\|g')"
  '';
in {

  options.services.math-symbols-input = {
    enable = mkEnableOption ''
      LaTeX-style mathematical symbols input method for macOS
    '';

    symbols = mkOption {
      type = types.attrs;
      default = { };
      example = literalExample ''
        {
          "xd" = "😆";
        }
      '';
      description = "Custom symbols to add to Math Symbols Input";
    };
  };

  # Note that this only makes sense for homebrew
  config = mkIf cfg.enable {
    system.activationScripts.preActivation.text = ''
      echo "Setting up Math Symbols Input"

      if [ -d /Library/Input\ Methods/Math\ Symbols\ Input.app ]; then
        rm /Library/Input\ Methods/Math\ Symbols\ Input.app
      fi

      ln -s ${package}/Math\ Symbols\ Input.app /Library/Input\ Methods/

      if [ ! -f ${plist-full-path} ]; then
        defaults write ${plist-full-path} CustomCommands ""
        chmod 600 ${plist-full-path}
        chown $SUDO_USER:staff ${plist-full-path}
      fi

      # Force a cache reload by writing
      su - $SUDO_USER -c "${command-to-run}/bin/write_defaults"
    '';
  };
}
