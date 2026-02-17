{ config, lib, pkgs, ... }:

let
  cfg = config.services.openssh;

  hostKeyOpts = {
    options = {
      type = lib.mkOption {
        type = lib.types.enum [ "dsa" "ecdsa" "ed25519" "rsa" ];
        description = ''
          Key type passed to `ssh-keygen -t`.
        '';
      };

      path = lib.mkOption {
        type = lib.types.str;
        description = ''
          Path to the private key file.
        '';
      };

      bits = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = ''
          Key size in bits. If `null`, `ssh-keygen` uses the default
          for the given key type (RSA=3072, ECDSA=256, ED25519=fixed).
        '';
      };

      comment = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          Comment for the key, passed to `ssh-keygen -C`.

          Defaults to an empty string to match Apple's built-in host key
          generation and avoid leaking the hostname.
        '';
      };
    };
  };

  hostKeysConfig = lib.concatMapStringsSep "\n"
    (k: "HostKey ${k.path}")
    cfg.hostKeys;

  keygenScript = lib.concatMapStrings (k:
    let
      escapedPath = lib.escapeShellArg k.path;
    in ''
      if ! [[ -s ${escapedPath} ]]; then
        if ! [[ -L ${escapedPath} ]]; then
          rm -f ${escapedPath}
        fi

        keygenArgs=(
          -t ${lib.escapeShellArg k.type}
          ${lib.optionalString (k.bits != null) "-b ${toString k.bits}"}
          -C ${lib.escapeShellArg k.comment}
          -f ${escapedPath}
          -N ""
        )

        mkdir -p "$(dirname ${escapedPath})"
        chmod 0755 "$(dirname ${escapedPath})"
        ${lib.getExe' pkgs.openssh "ssh-keygen"} "''${keygenArgs[@]}"
      fi
    '') cfg.hostKeys;
in
{
  options = {
    services.openssh = {
      enable = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = ''
          Whether to enable Apple's built-in OpenSSH server.

          The default is null which means let macOS manage the OpenSSH server.
        '';
      };

      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = ''
          Extra configuration text loaded in {file}`sshd_config`.
          See {manpage}`sshd_config(5)` for help.
        '';
      };

      hostKeys = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule hostKeyOpts);
        default = [
          { type = "rsa"; path = "/etc/ssh/ssh_host_rsa_key"; }
          { type = "ecdsa"; path = "/etc/ssh/ssh_host_ecdsa_key"; }
          { type = "ed25519"; path = "/etc/ssh/ssh_host_ed25519_key"; }
        ];
        description = ''
          SSH host key declarations. Each entry specifies a key type and path.
          `HostKey` directives are written to the sshd configuration for each
          entry.

          The default matches the keys that macOS automatically generates.
        '';
      };
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

    environment.etc."ssh/sshd_config.d/099-host-keys.conf" = lib.mkIf (cfg.hostKeys != []) {
      text = hostKeysConfig;
    };

    environment.etc."ssh/sshd_config.d/100-nix-darwin.conf".text = cfg.extraConfig;

    system.activationScripts.openssh.text = lib.mkIf (cfg.hostKeys != []) keygenScript;
  };
}
