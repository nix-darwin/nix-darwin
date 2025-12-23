{ config, lib, inputs, pkgs, ... }:

{
  system.primaryUser = "lnl";

  system.defaults.NSGlobalDomain.AppleKeyboardUIMode = 3;
  system.defaults.NSGlobalDomain.ApplePressAndHoldEnabled = false;
  system.defaults.NSGlobalDomain.InitialKeyRepeat = 10;
  system.defaults.NSGlobalDomain.KeyRepeat = 1;
  system.defaults.NSGlobalDomain.NSAutomaticCapitalizationEnabled = false;
  system.defaults.NSGlobalDomain.NSAutomaticInlinePredictionEnabled = false;
  system.defaults.NSGlobalDomain.NSAutomaticDashSubstitutionEnabled = false;
  system.defaults.NSGlobalDomain.NSAutomaticPeriodSubstitutionEnabled = false;
  system.defaults.NSGlobalDomain.NSAutomaticQuoteSubstitutionEnabled = false;
  system.defaults.NSGlobalDomain.NSAutomaticSpellingCorrectionEnabled = false;
  system.defaults.NSGlobalDomain.NSNavPanelExpandedStateForSaveMode = true;
  system.defaults.NSGlobalDomain.NSNavPanelExpandedStateForSaveMode2 = true;
  system.defaults.NSGlobalDomain._HIHideMenuBar = true;

  system.defaults.dock.autohide = true;
  system.defaults.dock.mru-spaces = false;
  system.defaults.dock.orientation = "left";
  system.defaults.dock.showhidden = true;

  system.defaults.finder.AppleShowAllExtensions = true;
  system.defaults.finder.QuitMenuItem = true;
  system.defaults.finder.FXEnableExtensionChangeWarning = false;

  system.defaults.trackpad.Clicking = true;
  system.defaults.trackpad.TrackpadThreeFingerDrag = true;

  system.keyboard.enableKeyMapping = true;
  system.keyboard.remapCapsLockToControl = true;

  environment.systemPackages =
    [
      config.programs.vim.package

      pkgs.awscli
      pkgs.brotli
      pkgs.ctags
      pkgs.curl
      pkgs.direnv
      pkgs.entr
      pkgs.fzf
      pkgs.gettext
      pkgs.git
      pkgs.gnupg
      pkgs.htop
      pkgs.jq
      pkgs.ripgrep
      pkgs.shellcheck
    ];

  services.yabai.enable = true;
  services.yabai.package = pkgs.yabai;
  services.skhd.enable = true;

  # security.sandbox.profiles.fetch-nixpkgs-updates.closure = [ pkgs.cacert pkgs.git ];
  # security.sandbox.profiles.fetch-nixpkgs-updates.allowNetworking = true;
  # security.sandbox.profiles.fetch-nixpkgs-updates.writablePaths = [ (toString ~/Code/nixos/nixpkgs) ];

  # launchd.user.agents.fetch-nixpkgs-updates = {
  #   command = "/usr/bin/sandbox-exec -f ${config.security.sandbox.profiles.fetch-nixpkgs-updates.profile} ${pkgs.git}/bin/git -C ${toString ~/Code/nixos/nixpkgs} fetch origin master";
  #   environment.HOME = "";
  #   environment.NIX_SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  #   serviceConfig.KeepAlive = false;
  #   serviceConfig.ProcessType = "Background";
  #   serviceConfig.StartInterval = 360;
  # };

  # Dotfiles.
  # launchd.user.agents.letty = {
  #   serviceConfig.Program = "${pkgs.lnl.letty}/bin/letty-blink";
  #   serviceConfig.WatchPaths = ["/var/mail/lnl"];
  #   serviceConfig.KeepAlive = false;
  #   serviceConfig.ProcessType = "Background";
  # };

  # services.nix-daemon.enableSocketListener = true;

  nix.extraOptions = ''
    gc-keep-derivations = true
    gc-keep-outputs = true
    min-free = 17179870000
    max-free = 17179870000
    log-lines = 128
  '';

  nix.settings.trusted-public-keys = [ "cache.daiderd.com-1:R8KOWZ8lDaLojqD+v9dzXAqGn29gEzPTTbr/GIpCTrI=" ];
  nix.settings.trusted-substituters = [ "https://d3i7ezr9vxxsfy.cloudfront.net" ];

  nix.settings.sandbox = true;
  nix.settings.extra-sandbox-paths = [ "/private/tmp" "/private/var/tmp" "/usr/bin/env" ];

  programs.nix-index.enable = true;

  # programs.gnupg.agent.enable = true;
  # programs.gnupg.agent.enableSSHSupport = true;

  programs.tmux.enable = true;
  programs.tmux.enableSensible = true;
  programs.tmux.enableMouse = true;
  programs.tmux.enableFzf = true;
  programs.tmux.enableVim = true;

  programs.tmux.extraConfig = ''
    bind 0 set status
    bind S choose-session

    bind-key -r "<" swap-window -t -1
    bind-key -r ">" swap-window -t +1

    bind-key -n M-c run "tmux send-keys -t .+ C-\\\\ && tmux send-keys -t .+ C-a C-k C-l Up && tmux send-keys -t .+ Enter"
    bind-key -n M-r run "tmux send-keys -t .+ C-a C-k C-l Up && tmux send-keys -t .+ Enter"

    set -g pane-active-border-style fg=black
    set -g pane-border-style fg=black
    set -g status-bg black
    set -g status-fg white
    set -g status-right '#[fg=white]#(id -un)@#(hostname)   #(jq --raw-output '.darwinLabel' /run/current-system/darwin-version.json)'
  '';

  environment.etc."nix/user-sandbox.sb".text = ''
    (version 1)
    (allow default)
    (deny file-write*
          (subpath "/nix"))
    (allow file-write*
           (subpath "/nix/var/nix/gcroots/per-user")
           (subpath "/nix/var/nix/profiles/per-user"))

    (allow process-exec
          (literal "/bin/ps")
          (with no-sandbox))
  '';

  # programs.vim.enable = true;
  # programs.vim.enableSensible = true;
  programs.vim.package = pkgs.neovim.override {
    configure = {
      packages.darwin.start = with pkgs.vimPlugins; [
        vim-sensible
        vim-surround
        ReplaceWithRegister
        polyglot
        fzfWrapper
        ale
        deoplete-nvim
      ];

      customRC = ''
        set completeopt=menuone
        set encoding=utf-8
        set hlsearch
        set list
        set number
        set showcmd
        set splitright

        cnoremap %% <C-r>=expand('%:h') . '/'<CR>
        nnoremap // :nohlsearch<CR>

        let mapleader = ' '

        " fzf
        nnoremap <Leader>p :FZF<CR>

        " vim-surround
        vmap s S

        " ale
        nnoremap <Leader>d :ALEGoToDefinition<CR>
        nnoremap <Leader>D :ALEGoToDefinitionInVSplit<CR>
        nnoremap <Leader>k :ALESignature<CR>
        nnoremap <Leader>K :ALEHover<CR>
        nnoremap [a :ALEPreviousWrap<CR>
        nnoremap ]a :ALENextWrap<CR>

        " deoplete
        inoremap <expr><C-g> deoplete#undo_completion()
        inoremap <expr><C-l> deoplete#refresh()
        inoremap <silent><expr><C-Tab> deoplete#mappings#manual_complete()
        inoremap <silent><expr><Tab> pumvisible() ? "\<C-n>" : "\<TAB>"

        let g:deoplete#enable_at_startup = 1
      '';
    };
  };

  # Dotfiles.
  # programs.vim.package = mkForce pkgs.lnl.vim;

  programs.bash.completion.enable = true;

  programs.zsh.enable = true;
  programs.zsh.enableBashCompletion = true;
  programs.zsh.enableFzfCompletion = true;
  programs.zsh.enableFzfGit = true;
  programs.zsh.enableFzfHistory = true;

  programs.zsh.variables.cfg = "/etc/nix-darwin/configuration.nix";
  programs.zsh.variables.darwin = "$HOME/.nix-defexpr/darwin";
  programs.zsh.variables.nixpkgs = "$HOME/.nix-defexpr/nixpkgs";


  programs.zsh.promptInit = ''
    autoload -U promptinit && promptinit

    setopt PROMPTSUBST

    _prompt_nix() {
      [ -z "$IN_NIX_SHELL" ] || echo "%F{yellow}%B[''${name:+$name}]%b%f "
    }

    PS1='%F{red}%B%(?..%? )%b%f%# '
    RPS1='$(_prompt_nix)%F{green}%~%f'

    if [ -n "$IN_NIX_SANDBOX" ]; then
      PS1+='%F{red}[sandbox]%f '
    fi
  '';

  programs.zsh.loginShellInit = ''
    reexec() {
        unset __NIX_DARWIN_SET_ENVIRONMENT_DONE
        unset __ETC_ZPROFILE_SOURCED __ETC_ZSHENV_SOURCED __ETC_ZSHRC_SOURCED
        exec $SHELL -c 'echo >&2 "reexecuting shell: $SHELL" && exec $SHELL -l'
    }

    reexec-tmux() {
        unset __NIX_DARWIN_SET_ENVIRONMENT_DONE
        unset __ETC_ZPROFILE_SOURCED __ETC_ZSHENV_SOURCED __ETC_ZSHRC_SOURCED
        exec tmux new-session -A -s _ "$@"
    }

    reexec-sandbox() {
        unset __NIX_DARWIN_SET_ENVIRONMENT_DONE
        unset __ETC_ZPROFILE_SOURCED __ETC_ZSHENV_SOURCED __ETC_ZSHRC_SOURCED
        export IN_NIX_SANDBOX=1
        exec /usr/bin/sandbox-exec -f /etc/nix/user-sandbox.sb $SHELL -l
    }

    ls() {
        ${pkgs.coreutils}/bin/ls --color=auto "$@"
    }

    install_name_tool() {
        ${pkgs.darwin.cctools}/bin/install_name_tool "$@"
    }

    nm() {
        ${pkgs.darwin.cctools}/bin/nm "$@"
    }

    otool() {
        ${pkgs.darwin.cctools}/bin/otool "$@"
    }
  '';

  programs.zsh.interactiveShellInit = ''
    setopt AUTOCD AUTOPUSHD

    autoload -U down-line-or-beginning-search
    autoload -U up-line-or-beginning-search
    bindkey '^[[A' down-line-or-beginning-search
    bindkey '^[[A' up-line-or-beginning-search
    zle -N down-line-or-beginning-search
    zle -N up-line-or-beginning-search
  '';

  environment.variables.SHELL = "${pkgs.zsh}/bin/zsh";

  environment.variables.LANG = "en_US.UTF-8";

  environment.shellAliases.g = "git log --pretty=color -32";
  environment.shellAliases.gb = "git branch";
  environment.shellAliases.gc = "git checkout";
  environment.shellAliases.gcb = "git checkout -B";
  environment.shellAliases.gd = "git diff --minimal --patch";
  environment.shellAliases.gf = "git fetch";
  environment.shellAliases.ga = "git log --pretty=color --all";
  environment.shellAliases.gg = "git log --pretty=color --graph";
  environment.shellAliases.gl = "git log --pretty=nocolor";
  environment.shellAliases.grh = "git reset --hard";
  environment.shellAliases.l = "ls -lh";

  environment.extraInit = ''
    # Load and export variables from environment.d.
    if [ -d /etc/environment.d ]; then
        set -a
        . /etc/environment.d/*
        set +a
    fi
  '';

  nixpkgs.config.allowUnfree = true;

  nixpkgs.overlays = [
    (self: super: {
      vim_configurable = super.vim_configurable.override {
        guiSupport = "no";
      };
    })
  ];

  # Dotfiles.
  # nixpkgs.overlays = mkAfter inputs.dotfiles.darwinOverlays;

  # Dotfiles.
  # services.yabai.enable = true;
  # services.yabai.package = pkgs.yabai;
  # services.skhd.skhdConfig = builtins.readFile "${inputs.dotfiles}/skhd/skhdrc";
  # services.yabai.extraConfig = builtins.readFile "${inputs.dotfiles}/yabai/yabairc";

  # Dotfiles.
  # $ cat ~/.gitconfig
  # [include]
  #     path = /etc/per-user/lnl/gitconfig
  # environment.etc."per-user/lnl/gitconfig".text = builtins.readFile "${inputs.dotfiles}/git/gitconfig";

  nix.nrBuildUsers = 32;

  system.stateVersion = 6;
}
