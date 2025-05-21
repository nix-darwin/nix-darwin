{ config, lib, ... }:

let
  cfg = config.services.openssh;
in
{
  options = {
    services.openssh.enable = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Whether to enable Apple's built-in OpenSSH server.

        The default is null which means let macOS manage the OpenSSH server.
      '';
    };
  };

  config = {
    # We don't use `systemsetup -setremotelogin` as it requires Full Disk Access
    system.activationScripts.launchd.text = lib.mkIf (cfg.enable != null) (if cfg.enable then ''
      if [[ "$(systemsetup -getremotelogin | sed 's/Remote Login: //')" == "Off" ]]; then
        launchctl enable system/com.openssh.sshd
        launchctl bootstrap system /System/Library/LaunchDaemons/ssh.plist
      fi
    '' else ''
      if [[ "$(systemsetup -getremotelogin | sed 's/Remote Login: //')" == "On" ]]; then
        launchctl bootout system/com.openssh.sshd
        launchctl disable system/com.openssh.sshd
      fi
    '');

    environment.etc."ssh/sshd_config.d/50-nix-path-fallback.conf".text = let
      pathDirs = lib.splitString ":" config.environment.systemPath;
      filteredPathDirs = lib.filter (dir: !lib.hasInfix "$" dir) pathDirs;
      filteredPath = lib.concatStringsSep ":" filteredPathDirs;
    in ''
      # Set a fallback PATH that doesn't depend on any environment variables
      # for when SSH is run with a command i.e. `ssh root@localhost nix-store`
      # This is necessary for any users who have `/bin/sh` or `/bin/bash` as
      # their default shells (`root` by default), this isn't necessary for Zsh
      # as it will still execute `/etc/zshenv` whereas `/bin/sh` will not
      # execute any files.
      SetEnv PATH=${filteredPath}
    '';
  };
}
