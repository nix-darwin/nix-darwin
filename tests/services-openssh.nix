{ config, ... }:

{
  services.openssh.enable = true;
  services.openssh.generateHostKeys = true;
  services.openssh.extraConfig = ''
    StreamLocalBindUnlink yes
  '';
  services.openssh.hostKeys = [
    { type = "ed25519"; path = "/etc/ssh/custom_host_ed25519_key"; comment = "my-host"; }
    { type = "rsa"; path = "/etc/ssh/custom_host_rsa_key"; bits = 4096; }
  ];

  test = ''
    echo >&2 "checking for StreamLocalBindUnlink in /etc/ssh/sshd_config.d/100-nix-darwin.conf"
    grep 'StreamLocalBindUnlink yes' ${config.out}/etc/ssh/sshd_config.d/100-nix-darwin.conf

    echo >&2 "checking for HostKey directives in /etc/ssh/sshd_config.d/099-host-keys.conf"
    grep 'HostKey /etc/ssh/custom_host_ed25519_key' ${config.out}/etc/ssh/sshd_config.d/099-host-keys.conf
    grep 'HostKey /etc/ssh/custom_host_rsa_key' ${config.out}/etc/ssh/sshd_config.d/099-host-keys.conf

    echo >&2 "checking that default keys are absent from config"
    (! grep 'HostKey /etc/ssh/ssh_host_rsa_key' ${config.out}/etc/ssh/sshd_config.d/099-host-keys.conf)
    (! grep 'HostKey /etc/ssh/ssh_host_ecdsa_key' ${config.out}/etc/ssh/sshd_config.d/099-host-keys.conf)
    (! grep 'HostKey /etc/ssh/ssh_host_ed25519_key' ${config.out}/etc/ssh/sshd_config.d/099-host-keys.conf)

    echo >&2 "checking for ssh-keygen commands in activation script"
    grep 'ssh-keygen.*-t.*ed25519.*-C my-host.*-f.*/etc/ssh/custom_host_ed25519_key' ${config.out}/activate
    grep 'ssh-keygen.*-t.*rsa.*-b 4096.*-f.*/etc/ssh/custom_host_rsa_key' ${config.out}/activate
  '';
}
