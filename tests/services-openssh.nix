{ config, pkgs, ... }:

{
  services.openssh.extraConfig = ''
    StreamLocalBindUnlink yes
  '';

  test = ''
    echo >&2 "checking for StreamLocalBindUnlink in /etc/ssh/ssh_known_hosts"
    grep 'StreamLocalBindUnlink yes' ${config.out}/etc/ssh/sshd_config.d/100-nix-darwin.conf
  '';
}
