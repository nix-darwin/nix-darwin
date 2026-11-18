{ config, ... }:

{
  programs.vim.enable = true;
  programs.vim.enableSensible = true;
  programs.vim.vimConfig = ''
    set mouse=a
    let g:mapleader = ","
  '';

  test = ''
    echo "checking vimrc in /etc/vimrc" >&2
    grep "set nocompatible" ${config.out}/etc/vimrc
    grep "syntax on" ${config.out}/etc/vimrc
    grep "set mouse=a" ${config.out}/etc/vimrc
    grep 'let g:mapleader = ","' ${config.out}/etc/vimrc
    grep "source /etc/vimrc.local" ${config.out}/etc/vimrc
  '';
}
