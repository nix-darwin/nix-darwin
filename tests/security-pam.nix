{ config, pkgs, ... }:

{
  security.pam.services.sudo_local = {
    enable = true;
    touchIdAuth = true;
    watchIdAuth = true;
    reattach = true;
    u2fAuth = true;
  };

  security.pam.u2f = {
    enable = true;
    control = "sufficient";
    settings = {
      authfile = "/etc/u2f_keys";
      cue = true;
      debug = true;
    };
  };

  test = ''
    echo >&2 "checking for /etc/pam.d/sudo_local file"
    test -f ${config.out}/etc/pam.d/sudo_local

    echo >&2 "checking for pam_u2f.so in sudo_local"
    grep 'auth       sufficient     ${pkgs.pam_u2f}/lib/security/pam_u2f.so authfile=/etc/u2f_keys cue debug' ${config.out}/etc/pam.d/sudo_local

    echo >&2 "checking for pam_reattach.so in sudo_local"
    grep 'auth       optional       ${pkgs.pam-reattach}/lib/pam/pam_reattach.so' ${config.out}/etc/pam.d/sudo_local

    echo >&2 "checking for pam_tid.so in sudo_local"
    grep 'auth       sufficient     pam_tid.so' ${config.out}/etc/pam.d/sudo_local

    echo >&2 "checking for pam_watchid.so in sudo_local"
    grep 'auth       sufficient     ${pkgs.pam-watchid}/lib/pam_watchid.so' ${config.out}/etc/pam.d/sudo_local

    echo >&2 "checking for sudo_local include in activation script"
    grep "sudo_local" ${config.out}/activate

    echo >&2 "checking for pam activation script setup"
    grep "setting up pam..." ${config.out}/activate

    echo >&2 "checking for sed command to add sudo_local include"
    grep "auth       include        sudo_local # nix-darwin: security.pam.services.sudo_local" ${config.out}/activate
  '';
}
