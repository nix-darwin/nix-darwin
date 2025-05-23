{ config, ... }:

{
  services.openssh.extraConfig = ''
    StreamLocalBindUnlink yes
  '';

  services.openssh.settings = {
    MACs = [
      "hmac-sha2-512-etm@openssh.com"
      "hmac-sha2-256-etm@openssh.com"
    ];
    AllowGroups = [
      "foo"
      "bar"
    ];
  };

  test = ''
    echo >&2 "checking for StreamLocalBindUnlink in /etc/ssh/sshd_config.d/100-nix-darwin.conf"
    grep 'StreamLocalBindUnlink yes' ${config.out}/etc/ssh/sshd_config.d/100-nix-darwin.conf

    echo >&2 "checking for correct comma-separation in /etc/ssh/sshd_config.d/100-nix-darwin.conf"
    grep --fixed-strings 'MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com' ${config.out}/etc/ssh/sshd_config.d/100-nix-darwin.conf

    echo >&2 "checking for correct space-separation in /etc/ssh/sshd_config.d/100-nix-darwin.conf"
    grep --fixed-strings 'AllowGroups foo bar' ${config.out}/etc/ssh/sshd_config.d/100-nix-darwin.conf
  '';
}
