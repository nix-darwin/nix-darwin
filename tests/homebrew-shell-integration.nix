{ config, ... }:

{
  homebrew.enable = true;
  programs.bash.enable = true;
  programs.zsh.enable = true;
  programs.fish.enable = true;

  homebrew.user = "test-homebrew-user";

  homebrew.enableBashIntegration = true;
  homebrew.enableFishIntegration = true;
  homebrew.enableZshIntegration = true;

  test = ''
    echo >&2 "checking bash shell integration in /etc/bashrc"
    grep 'brew shellenv bash' ${config.out}/etc/bashrc
    echo >&2 "checking bash completions in /etc/bashrc"
    grep 'bash_completion' ${config.out}/etc/bashrc

    echo >&2 "checking zsh shell integration in /etc/zshrc"
    grep 'brew shellenv zsh' ${config.out}/etc/zshrc

    echo >&2 "checking fish shell integration in /etc/fish/config.fish"
    grep 'brew shellenv fish' ${config.out}/etc/fish/config.fish
    echo >&2 "checking fish completions in /etc/fish/config.fish"
    grep 'fish_complete_path' ${config.out}/etc/fish/config.fish
  '';
}
