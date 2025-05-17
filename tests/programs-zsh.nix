{ config, pkgs, ... }:

{
   environment.systemPath = [ pkgs.hello ];
   environment.shellAliases.ls = "ls -G";
   environment.interactiveShellInit = "source /etc/environment.d/*.conf";

   programs.zsh.enable = true;
   programs.zsh.enableCompletion = true;
   programs.zsh.enableBashCompletion = false;
   programs.zsh.enableAutosuggestions = true;

   programs.zsh.shellInit = "source /etc/zshenv.d/*.conf";
   programs.zsh.interactiveShellInit = "source /etc/zshrc.d/*.conf";
   programs.zsh.loginShellInit = "source /etc/zprofile.d/*.conf";
   programs.zsh.promptInit = "autoload -U promptinit && promptinit && prompt off";

   programs.zsh.variables.FOO = "42";

   test = ''
     echo >&2 "checking for share/zsh in /sw"
     test -e ${config.out}/sw/share/zsh

     echo >&2 "checking setEnvironment in /etc/zshenv"
     fgrep '. ${config.system.build.setEnvironment}' ${config.out}/etc/zshenv
     echo >&2 "checking zshenv.d in /etc/zshenv"
     grep 'source /etc/zshenv.d/\*.conf' ${config.out}/etc/zshenv

     echo >&2 "checking environment.d in /etc/zshrc"
     grep 'source /etc/environment.d/\*.conf' ${config.out}/etc/zshrc
     echo >&2 "checking zshrc.d in /etc/zshrc"
     grep 'source /etc/zshrc.d/\*.conf' ${config.out}/etc/zshrc
     echo >&2 "checking prompt off in /etc/zshrc"
     grep 'prompt off' ${config.out}/etc/zshrc
     echo >&2 "checking compinit in /etc/zshrc"
     grep 'autoload -U compinit && compinit' ${config.out}/etc/zshrc
     echo >&2 "checking bashcompinit in /etc/zshrc"
     (! grep 'bashcompinit' ${config.out}/etc/zshrc)
     echo >&2 "checking zsh-autosuggestions in /etc/zshrc"
     grep 'source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh' ${config.out}/etc/zshrc

     echo >&2 "checking zprofile.d in /etc/zprofile"
     grep 'source /etc/zprofile.d/\*.conf' ${config.out}/etc/zprofile
     echo >&2 "checking zsh variables in /etc/zprofile"
     grep 'FOO="42"' ${config.out}/etc/zprofile
     echo >&2 "checking shell aliases in /etc/zprofile"
     grep "alias ls='ls -G'" ${config.out}/etc/zprofile
   '';
}
