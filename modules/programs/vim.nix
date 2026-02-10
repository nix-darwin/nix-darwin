{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.vim;

  text = import ../lib/write-text.nix {
    inherit lib;
    mkTextDerivation = name: text: pkgs.writeText "vim-options-${name}" text;
  };

  vimOptions = concatMapStringsSep "\n" (attr: attr.text) (attrValues cfg.vimOptions);
in

{
  options = {
    programs.vim.enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to configure vim.";
    };

    programs.vim.enableSensible = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = "Enable sensible configuration options for vim.";
    };

    programs.vim.extraKnownPlugins = mkOption {
      type = types.attrsOf types.package;
      default = {};
      example = literalExpression
        ''
        {
          vim-jsx = pkgs.vimUtils.buildVimPluginFrom2Nix {
            name = "vim-javascript-2016-07-29";
            src = pkgs.fetchgit {
              url = "git://github.com/mxw/vim-jsx";
              rev = "261114c925ea81eeb4db1651cc1edced66d6b5d6";
              sha256 = "17pffzwnvsimnnr4ql1qifdh4a0sqqsmcwfiqqzgglvsnzw5vpls";
            };
            dependencies = [];

          };
        }
        '';
      description = "Custom plugin declarations to add to VAM's knownPlugins.";
    };

    programs.vim.plugins = mkOption {
      type = types.listOf types.attrs;
      default = [];
      example = [ { names = [ "surround" "vim-nix" ]; } ];
      description = "VAM plugin dictionaries to use for vim_configurable.";
    };

    programs.vim.package = mkOption {
      internal = true;
      type = types.package;
    };

    programs.vim.vimOptions = mkOption {
      internal = true;
      type = types.attrsOf (types.submodule text);
      default = {};
    };

    programs.vim.vimConfig = mkOption {
      type = types.lines;
      default = "";
      description = "Extra vimrcConfig to use for vim_configurable.";
    };
  };

  config = mkIf cfg.enable {

    environment.systemPackages =
      [ # Include vim-full package.
        cfg.package
      ];

    environment.variables.EDITOR = "${cfg.package}/bin/vim";

    environment.etc."vimrc".text = ''
      ${vimOptions}
      ${cfg.vimConfig}

      if filereadable('/etc/vimrc.local')
        source /etc/vimrc.local
      endif
    '';

    programs.vim.package = pkgs.vim-full.customize {
      name = "vim";
      vimrcConfig.customRC = config.environment.etc."vimrc".text;
      vimrcConfig.vam = {
        knownPlugins = pkgs.vimPlugins // cfg.extraKnownPlugins;
        pluginDictionaries = cfg.plugins;
      };
    };

    programs.vim.plugins = mkIf cfg.enableSensible [
      { names = [ "fugitive" "surround" "vim-nix" ]; }
    ];

    programs.vim.vimOptions.sensible.text = mkIf cfg.enableSensible ''
      set nocompatible
      filetype plugin indent on
      syntax on

      set et sw=2 ts=2
      set bs=indent,start

      set hlsearch
      set incsearch
      nnoremap // :nohlsearch<CR>

      set list
      set listchars=tab:»·,trail:·,extends:⟩,precedes:⟨
      set fillchars+=vert:\ ,stl:\ ,stlnc:\ 

      set number

      set lazyredraw
      set nowrap
      set showcmd
      set showmatch
    '';

  };
}
