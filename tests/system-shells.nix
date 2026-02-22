{ config, pkgs, ... }:

{
  environment.shells = [ pkgs.zsh ];

  test = ''
    echo checking zsh in /etc/shells >&2
    grep '/run/current-system/sw/bin/zsh' ${config.out}/etc/shells
  '';
}
