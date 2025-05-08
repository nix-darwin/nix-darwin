{ config, lib, pkgs, ... }:

let
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
  imports = [
    (lib.mkRemovedOptionModule [ "services" "activate-system" "enable" ] "The `activate-system` service is now always enabled as it is necessary for a working `nix-darwin` setup.")
  ];

  config = {
    launchd.daemons.activate-system = {
      script = ''
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

        systemConfig=$(cat ${config.system.profile}/systemConfig)

        # Make this configuration the current configuration.
        # The readlink is there to ensure that when $systemConfig = /system
        # (which is a symlink to the store), /run/current-system is still
        # used as a garbage collection root.
        ln -sfn $(cat ${config.system.profile}/systemConfig) /run/current-system

        # Prevent the current configuration from being garbage-collected.
        if [[ -d /nix/var/nix/gcroots ]]; then
          ln -sfn /run/current-system /nix/var/nix/gcroots/current-system
        fi

        ${config.system.activationScripts.checks.text}
        ${config.system.activationScripts.etc.text}
        ${config.system.activationScripts.keyboard.text}
      '';
      serviceConfig.RunAtLoad = true;
    };
  };
}
