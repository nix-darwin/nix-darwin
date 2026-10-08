{ config, pkgs, ... }:

{
  security.sudo.adminNeedsPassword = false;

  test = ''
    echo checking admin sudo rule in /etc/sudoers.d >&2
    grep "%admin ALL=(ALL) NOPASSWD: ALL" ${config.out}/etc/sudoers.d/10-nix-darwin-extra-config
  '';
}
