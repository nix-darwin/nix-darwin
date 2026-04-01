{ config, lib, options, pkgs, ... }:

with lib;

let
  cfg = config.programs.zsh;
  opt = options.programs.zsh;

  zshVariables =
    mapAttrsToList (n: v: ''${n}="${v}"'') cfg.variables;

  fzfCompletion = ./fzf-completion.zsh;
  fzfGit = ./fzf-git.zsh;
  fzfHistory = ./fzf-history.zsh;
in

{
  options = {
    programs.zsh.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to configure zsh as an interactive shell.";
    };

    programs.zsh.variables = mkOption {
      type = types.attrsOf (types.either types.str (types.listOf types.str));
      default = {};
      description = ''
        A set of environment variables used in the global environment.
        These variables will be set on shell initialisation.
        The value of each variable can be either a string or a list of
        strings.  The latter is concatenated, interspersed with colon
        characters.
      '';
      apply = mapAttrs (n: v: if isList v then concatStringsSep ":" v else v);
    };

    programs.zsh.shellInit = mkOption {
      type = types.lines;
      default = "";
      description = "Shell script code called during zsh shell initialisation.";
    };

    programs.zsh.loginShellInit = mkOption {
      type = types.lines;
      default = "";
      description = "Shell script code called during zsh login shell initialisation.";
    };

    programs.zsh.interactiveShellInit = mkOption {
      type = types.lines;
      default = "";
      description = "Shell script code called during interactive zsh shell initialisation.";
    };

    programs.zsh.promptInit = mkOption {
      type = types.lines;
      default = "autoload -U promptinit && promptinit && prompt suse && setopt prompt_sp";
      description = "Shell script code used to initialise the zsh prompt.";
    };

    programs.zsh.histSize = mkOption {
      type = types.int;
      default = 2000;
      description = "Change history size.";
    };

    programs.zsh.histFile = mkOption {
      type = types.str;
      default = "$HOME/.zsh_history";
      description = "Change history file.";
    };

    programs.zsh.enableCompletion = mkOption {
      type = types.bool;
      default = true;
      description = "Enable zsh completion for all interactive zsh shells.";
    };

    programs.zsh.enableBashCompletion = mkOption {
      type = types.bool;
      default = true;
      description = "Enable bash completion for all interactive zsh shells.";
    };

    programs.zsh.enableGlobalCompInit = mkOption {
      type = types.bool;
      default = cfg.enableCompletion;
      defaultText = literalExpression "config.${opt.enableCompletion}";
      description = ''
        Enable execution of compinit call for all interactive zsh shells.

        This option can be disabled if the user wants to extend its
        `fpath` and a custom `compinit`
        call in the local config is required.
      '';
    };

    programs.zsh.enableFzfCompletion = mkOption {
      type = types.bool;
      default = false;
      description = "Enable fzf completion.";
    };

    programs.zsh.enableFzfGit = mkOption {
      type = types.bool;
      default = false;
      description = "Enable fzf keybindings for C-g git browsing.";
    };

    programs.zsh.enableFzfHistory = mkOption {
      type = types.bool;
      default = false;
      description = "Enable fzf keybinding for Ctrl-r history search.";
    };

    programs.zsh.enableAutosuggestions = mkOption {
      type = types.bool;
      default = false;
      description = "Enable zsh-autosuggestions.";
    };

    programs.zsh.enableSyntaxHighlighting = mkOption {
      type = types.bool;
      default = false;
      description = "Enable zsh-syntax-highlighting.";
    };

    programs.zsh.enableFastSyntaxHighlighting = mkEnableOption "zsh-fast-syntax-highlighting";
  };

  config = mkIf cfg.enable {

    assertions = [
      {
        assertion = !(cfg.enableSyntaxHighlighting && cfg.enableFastSyntaxHighlighting);
        message = "zsh-syntax-highlighting and zsh-fast-syntax-highlighting are mutually exclusive, please disable one of them.";
      }
    ];
    environment.systemPackages =
      [ # Include zsh package
        pkgs.zsh
      ] ++ optional cfg.enableCompletion pkgs.nix-zsh-completions
        ++ optional cfg.enableAutosuggestions pkgs.zsh-autosuggestions
        ++ optional cfg.enableSyntaxHighlighting pkgs.zsh-syntax-highlighting
        ++ optional cfg.enableFastSyntaxHighlighting pkgs.zsh-fast-syntax-highlighting;

    environment.pathsToLink = [ "/share/zsh" ];

    environment.etc."zshenv".text = ''
      # /etc/zshenv: DO NOT EDIT -- this file has been generated automatically.
      # This file is read for all shells.

      # Only execute this file once per shell.
      if [ -n "''${__ETC_ZSHENV_SOURCED-}" ]; then return; fi
      __ETC_ZSHENV_SOURCED=1

      if [[ -o rcs ]]; then
        if [ -z "''${__NIX_DARWIN_SET_ENVIRONMENT_DONE-}" ]; then
          . ${config.system.build.setEnvironment}
        fi

        # Tell zsh how to find installed completions
        for p in ''${(z)NIX_PROFILES}; do
          fpath=($p/share/zsh/site-functions $p/share/zsh/$ZSH_VERSION/functions $p/share/zsh/vendor-completions $fpath)
        done

        ${cfg.shellInit}
      fi

      # Read system-wide modifications.
      if test -f /etc/zshenv.local; then
        source /etc/zshenv.local
      fi
    '';

    environment.etc."zprofile".text = ''
      # /etc/zprofile: DO NOT EDIT -- this file has been generated automatically.
      # This file is read for login shells.

      # Only execute this file once per shell.
      if [ -n "''${__ETC_ZPROFILE_SOURCED-}" ]; then return; fi
      __ETC_ZPROFILE_SOURCED=1

      ${concatStringsSep "\n" zshVariables}
      ${config.system.build.setAliases.text}

      ${cfg.loginShellInit}

      # Read system-wide modifications.
      if test -f /etc/zprofile.local; then
        source /etc/zprofile.local
      fi
    '';

    environment.etc."zshrc".text = ''
      # /etc/zshrc: DO NOT EDIT -- this file has been generated automatically.
      # This file is read for interactive shells.

      # Only execute this file once per shell.
      if [ -n "$__ETC_ZSHRC_SOURCED" -o -n "$NOSYSZSHRC" ]; then return; fi
      __ETC_ZSHRC_SOURCED=1

      # Setup command line history.
      # Don't export these, otherwise other shells (bash) will try to use same HISTFILE.
      SAVEHIST=${builtins.toString cfg.histSize}
      HISTSIZE=${builtins.toString cfg.histSize}
      HISTFILE=${cfg.histFile}

      setopt HIST_IGNORE_DUPS SHARE_HISTORY HIST_FCNTL_LOCK

      bindkey -e

      ${config.environment.interactiveShellInit}
      ${cfg.interactiveShellInit}

      ${cfg.promptInit}

      ${optionalString cfg.enableGlobalCompInit "autoload -U compinit && compinit"}
      ${optionalString cfg.enableBashCompletion "autoload -U bashcompinit && bashcompinit"}

      ${optionalString cfg.enableAutosuggestions
        "source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
      }

      ${optionalString cfg.enableSyntaxHighlighting
        "source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
      }

      ${optionalString cfg.enableFastSyntaxHighlighting
        "source ${pkgs.zsh-fast-syntax-highlighting}/share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh"
      }

      ${optionalString cfg.enableFzfCompletion "source ${fzfCompletion}"}
      ${optionalString cfg.enableFzfGit "source ${fzfGit}"}
      ${optionalString cfg.enableFzfHistory "source ${fzfHistory}"}

      # Read system-wide modifications.
      if test -f /etc/zshrc.local; then
        source /etc/zshrc.local
      fi
    '';

    environment.etc."zprofile".knownSha256Hashes = [
      "db8422f92d8cff684e418f2dcffbb98c10fe544b5e8cd588b2009c7fa89559c5"
      "0235d3c1b6cf21e7043fbc98e239ee4bc648048aafaf6be1a94a576300584ef2"  # macOS
      "f320016e2cf13573731fbee34f9fe97ba867dd2a31f24893d3120154e9306e92"  # macOS 26b1 and higher
    ];

    environment.etc."zshrc".knownSha256Hashes = [
      "19a2d673ffd47b8bed71c5218ff6617dfc5e8533b240b9ba79142a45f8823c23"
      "fb5827cb4712b7e7932d438067ec4852c8955a9ff0f55e282473684623ebdfa1"  # macOS
      "4d1ab5704f9d167a042fecac0d056c8a79a8ebd71e032d3489536c8db9ffe3e0"  # macOS 26b1 and higher
      "c5a00c072c920f46216454978c44df044b2ec6d03409dc492c7bdcd92c94a110"  # official Nix installer
      "40b0d8751adae5b0100a4f863be5b75613a49f62706427e92604f7e04d2e2261"  # official Nix installer
      "bf76c5ed8e65e616f4329eccf662ee91be33b8bfd33713ce9946f2fe94fea7fa"  # official Nix installer (macOS 26b1 and higher)
      "2af1b563e389d11b76a651b446e858116d7a20370d9120a7e9f78991f3e5f336"  # DeterminateSystems installer
      "27274e44b88a1174787f9a3d437d3387edc4f9aaaf40356054130797f5dc7912"  # DeterminateSystems installer (macOS 26b1 and higher)
    ];

    environment.etc."zshenv".knownSha256Hashes = [
      "d07015be6875f134976fce84c6c7a77b512079c1c5f9594dfa65c70b7968b65f"  # DeterminateSystems installer
      "4e8f7cb9b699511f4ba5f9d5f8de1c9f5efb5c607de88faf5f58b8b9cb38edbf"  # experimental official Nix installer 2.33.3
    ];

  };
}
