{ lib, path, stdenv, writeShellApplication }:

let
  uninstallSystem = import ../../eval-config.nix {
    inherit lib;
    modules = [
      ./configuration.nix
      {
        nixpkgs.source = path;
        nixpkgs.hostPlatform = stdenv.hostPlatform.system;
        system.tools.darwin-uninstaller.enable = false;
      }
    ];
  };
in writeShellApplication {
  name = "darwin-uninstaller";
  text = ''
    while [ "$#" -gt 0 ]; do
      i="$1"; shift 1
      case "$i" in
        --help)
          echo "darwin-uninstaller: [--help]"
          exit
          ;;
      esac
    done

    echo >&2
    echo >&2 "Uninstalling nix-darwin, this will:"
    echo >&2
    echo >&2 "    - remove /Applications/Nix Apps symlink"
    echo >&2 "    - cleanup static /etc files"
    echo >&2 "    - disable and remove all launchd services managed by nix-darwin"
    if [[
      -e /run/current-system/Library/LaunchDaemons/org.nixos.nix-daemon.plist
      && -e /nix/var/nix/profiles/default/Library/LaunchDaemons/org.nixos.nix-daemon.plist
    ]]; then
      echo >&2 "    - restore nix-daemon service from the Nix installer"
    fi
    echo >&2

    if [[ -t 0 ]]; then
      read -r -p "Proceed? [y/n] " i
      case "$i" in
        y|Y)
          ;;
        *)
          exit 3
          ;;
      esac
    fi

    ${uninstallSystem.system}/sw/bin/darwin-rebuild activate

    if [[ -L /run/current-system ]]; then
      rm /run/current-system
    fi

    if [[ -L /run ]]; then
      if [[ -e /etc/synthetic.conf ]]; then
        sed -i -E '/^run[[:space:]]/d' /etc/synthetic.conf
        /System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -t &>/dev/null || true
        echo >&2 "NOTE: the /run symlink will be removed on reboot"
      else
        rm /run
      fi
    fi

    echo >&2
    echo >&2 "NOTE: The /nix/var/nix/profiles/system* profiles still exist and won't be garbage collected."
    echo >&2
    echo >&2 "Done!"
    echo >&2
  '';

  derivationArgs.passthru.tests.uninstaller = writeShellApplication {
    name = "post-uninstall-test";
    text = ''
      echo >&2 "running uninstaller tests..."
      echo >&2

      echo >&2 "checking darwin channel"
      nix-instantiate --find-file darwin && exit 1
      echo >&2 "checking /etc"
      test -e /etc/static && exit 1
      echo >&2 "checking /run/current-system"
      test -e /run/current-system && exit 1
      if [[ $(stat -f '%Su' /nix/store) == "root" ]]; then
        echo >&2 "checking nix-daemon service"
        launchctl print system/org.nixos.nix-daemon
        pgrep -l nix-daemon
        test -e /Library/LaunchDaemons/org.nixos.nix-daemon.plist
        [[ "$(shasum -a 256 /Library/LaunchDaemons/org.nixos.nix-daemon.plist | awk '{print $1}')" == "$(shasum -a 256 /nix/var/nix/profiles/default/Library/LaunchDaemons/org.nixos.nix-daemon.plist | awk '{print $1}')" ]]
        nix-store --store daemon -q --hash ${stdenv.shell}
      fi
      echo >&2 ok
    '';
  };
}
