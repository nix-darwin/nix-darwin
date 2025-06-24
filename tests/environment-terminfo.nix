{ config, ... }:

{
  environment.enableAllTerminfo = true;

  test = ''
    set -v

    echo checking /usr/share/terminfo in environment >&2
    grep 'export TERMINFO_DIRS=.*:/usr/share/terminfo' ${config.system.build.setEnvironment}

    # https://serverfault.com/a/225827
    echo checking /etc/terminfo contains lots of terminfos >&2
    find -L ${config.system.path} -name alacritty | grep .
    find -L ${config.system.path} -name xterm-kitty | grep .
    find -L ${config.system.path} -name wezterm | grep .
  '';
}
