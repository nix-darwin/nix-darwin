{ config, ... }:

{
  test = ''
    echo >&2 "checking for macOS defaults in /etc/ssh/sshd_config"
    grep --fixed-strings 'AuthorizedKeysFile .ssh/authorized_keys' ${config.out}/etc/ssh/sshd_config.d/100-nix-darwin.conf
  '';
}
