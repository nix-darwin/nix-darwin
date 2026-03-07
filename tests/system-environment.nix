{ config, pkgs, ... }:

{
  programs.bash.enable = true;
  programs.fish.enable = true;
  programs.zsh.enable = true;

  test = ''
    echo checking setEnvironment in /etc/bashrc >&2
    fgrep '. ${config.system.build.setEnvironment}' ${config.out}/etc/bashrc

    echo checking setEnvironment in /etc/fish/nixos-env-preinit.fish >&2
    grep 'fenv source ${config.system.build.setEnvironment}' ${config.out}/etc/fish/nixos-env-preinit.fish

    echo checking setEnvironment in /etc/zshenv >&2
    fgrep '. ${config.system.build.setEnvironment}' ${config.out}/etc/zshenv
  '';
}
