{ config, ... }:

{
  nix.enable = false;

  test = ''
    printf >&2 'checking for unexpected Nix binary in /sw/bin\n'
    [[ -e ${config.out}/sw/bin/nix-env ]] && exit 1

    printf >&2 'checking for unexpected nix-daemon plist in /Library/LaunchDaemons\n'
    [[ -e ${config.out}/Library/LaunchDaemons/org.nixos.nix-daemon.plist ]] && exit 1

    printf >&2 'checking for late‐bound Nix lookup in /activate\n'
    grep nixEnvPath= ${config.out}/activate

    printf >&2 'checking for late‐bound Nix lookup in activation service\n'
    script=$(cat ${config.out}/Library/LaunchDaemons/org.nixos.activate-system.plist | awk -F'[< ]' '$6 ~ "^/nix/store/.*" {print $6}')
    grep nixEnvPath= "$script"
  '';
}
