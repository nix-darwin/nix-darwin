{ config, lib, pkgs, ... }:

with lib;

let

  inherit (pkgs) stdenv;

  cfg = config.system;

  script = import ../lib/write-text.nix {
    inherit lib;
    mkTextDerivation = name: text: pkgs.writeScript "activate-${name}" text;
  };

  activationPath =
    lib.makeBinPath (
      [
        pkgs.gnugrep
        pkgs.coreutils
      ] ++ lib.optionals config.nix.enable [ config.nix.package ]
    )
    + lib.optionalString (!config.nix.enable) ''
      $(
        # If `nix.enable` is off, there might be an unmanaged Nix
        # installation (say in `/nix/var/nix/profiles/default`) that
        # activation scripts (such as Home Manager) want to find on the
        # `$PATH`. Search for it directly to avoid polluting the
        # activation script environment with everything on the
        # `environment.systemPath`.
        if nixEnvPath=$(
          PATH="${config.environment.systemPath}" command -v nix-env
        ); then
          printf ':'
          ${lib.getExe' pkgs.coreutils "dirname"} -- "$(
            ${lib.getExe' pkgs.coreutils "readlink"} \
              --canonicalize-missing \
              -- "$nixEnvPath"
          )"
        fi
      )''
    + ":/usr/bin:/bin:/usr/sbin:/sbin";
in

{
  options = {

    system.activationScripts = mkOption {
      internal = true;
      type = types.attrsOf (types.submodule script);
      default = {};
      description = ''
        A set of shell script fragments that are executed when a NixOS
        system configuration is activated.  Examples are updating
        /etc, creating accounts, and so on.  Since these are executed
        every time you boot the system or run
        {command}`nixos-rebuild`, it's important that they are
        idempotent and fast.
      '';
    };

  };

  config = {

    assertions =
      map
        (userActivationOption: {
          assertion = !config.system.activationScripts ? ${userActivationOption};
          message = ''
            The `system.activationScripts.${userActivationOption}` option has
            been removed, as all activation now takes place as `root`. Please
            restructure your custom activation scripts appropriately,
            potentially using `sudo` if you need to run commands as a user.
          '';
        })
        [
          "extraUserActivation"
          "preUserActivation"
          "postUserActivation"
        ];

    system.activationScripts.script.text = ''
      #!/usr/bin/env -i ${stdenv.shell}
      # shellcheck shell=bash
      # shellcheck disable=SC2096

      set -e
      set -o pipefail

      PATH="${activationPath}"

      export PATH
      export USER=root
      export LOGNAME=root
      export HOME=~root
      export MAIL=/var/mail/root
      export SHELL=$BASH
      export LANG=C
      export LC_CTYPE=UTF-8

      systemConfig=@out@

      # Ensure a consistent umask.
      umask 0022

      cd /

      if [[ $(id -u) -ne 0 ]]; then
        printf >&2 '\e[1;31merror: `activate` must be run as root\e[0m\n'
        exit 2
      fi

      ${cfg.activationScripts.preActivation.text}

      ${cfg.activationScripts.checks.text}
      ${cfg.activationScripts.createRun.text}
      ${cfg.activationScripts.extraActivation.text}
      ${cfg.activationScripts.groups.text}
      ${cfg.activationScripts.users.text}
      ${cfg.activationScripts.applications.text}
      ${cfg.activationScripts.pam.text}
      ${cfg.activationScripts.patches.text}
      ${cfg.activationScripts.openssh.text}
      ${cfg.activationScripts.etc.text}
      ${cfg.activationScripts.defaults.text}
      ${cfg.activationScripts.userDefaults.text}
      ${cfg.activationScripts.launchd.text}
      ${cfg.activationScripts.userLaunchd.text}
      ${cfg.activationScripts.nix-daemon.text}
      ${cfg.activationScripts.time.text}
      ${cfg.activationScripts.networking.text}
      ${cfg.activationScripts.power.text}
      ${cfg.activationScripts.keyboard.text}
      ${cfg.activationScripts.fonts.text}
      ${cfg.activationScripts.nvram.text}
      ${cfg.activationScripts.homebrew.text}

      ${cfg.activationScripts.postActivation.text}

      # Make this configuration the current configuration.
      # The readlink is there to ensure that when $systemConfig = /system
      # (which is a symlink to the store), /run/current-system is still
      # used as a garbage collection root.
      ln -sfn "$(readlink -f "$systemConfig")" /run/current-system

      # Prevent the current configuration from being garbage-collected.
      if [[ -d /nix/var/nix/gcroots ]]; then
        ln -sfn /run/current-system /nix/var/nix/gcroots/current-system
      fi
    '';

    # Extra activation scripts, that can be customized by users
    # don't use this unless you know what you are doing.
    system.activationScripts.extraActivation.text = mkDefault "";
    system.activationScripts.preActivation.text = mkDefault "";
    system.activationScripts.postActivation.text = mkDefault "";

  };
}
