{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.openssh;
  # Lifted from nixpkgs: https://github.com/squat/nixpkgs/blob/e52d633a638c607533ececf4eb9653ec1f93e3d4/nixos/modules/services/networking/ssh/sshd.nix#L20-L78.
  settingsFormat =
    let
      # reports boolean as yes / no
      mkValueString =
        v:
        if lib.isInt v then
          toString v
        else if lib.isString v then
          v
        else if true == v then
          "yes"
        else if false == v then
          "no"
        else
          throw "unsupported type ${builtins.typeOf v}: ${(lib.generators.toPretty { }) v}";

      base = pkgs.formats.keyValue {
        mkKeyValue = lib.generators.mkKeyValueDefault { inherit mkValueString; } " ";
      };
      # OpenSSH is very inconsistent with options that can take multiple values.
      # For some of them, they can simply appear multiple times and are appended, for others the
      # values must be separated by whitespace or even commas.
      # Consult either sshd_config(5) or, as last resort, the OpehSSH source for parsing
      # the options at servconf.c:process_server_config_line_depth() to determine the right "mode"
      # for each. But fortunaly this fact is documented for most of them in the manpage.
      commaSeparated = [
        "Ciphers"
        "KexAlgorithms"
        "MACs"
      ];
      spaceSeparated = [
        "AuthorizedKeysFile"
        "AllowGroups"
        "AllowUsers"
        "DenyGroups"
        "DenyUsers"
        "Include"
        "Subsystem"
      ];
    in
    {
      inherit (base) type;
      generate =
        name: value:
        let
          transformedValue = lib.mapAttrs (
            key: val:
            if lib.isList val then
              if lib.elem key commaSeparated then
                lib.concatStringsSep "," val
              else if lib.elem key spaceSeparated then
                lib.concatStringsSep " " val
              else
                throw "list value for unknown key ${key}: ${(lib.generators.toPretty { }) val}"
            else
              val
          ) value;
        in
        base.generate name transformedValue;
    };

  sshConfSettings = settingsFormat.generate "sshd.conf-settings" (
    lib.filterAttrs (n: v: v != null) cfg.settings
  );
  sshConfNixDarwin = pkgs.runCommand "sshd.conf-nix-darwin" { } ''
    cat ${sshConfSettings} - > $out <<EOF
    ${cfg.extraConfig}
    EOF
  '';

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

      settings = lib.mkOption {
        description = "Configuration for `sshd_config(5)`.";
        default = { };
        example = lib.literalExpression ''
          {
            UseDns = true;
            PasswordAuthentication = false;
          }
        '';
        type = lib.types.submodule (
          { name, ... }:
          {
            freeformType = settingsFormat.type;
            options = {
              AuthorizedPrincipalsFile = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = "none"; # upstream default
                description = ''
                  Specifies a file that lists principal names that are accepted for certificate authentication. The default
                  is `"none"`, i.e. not to use	a principals file.
                '';
              };
              LogLevel = lib.mkOption {
                type = lib.types.nullOr (
                  lib.types.enum [
                    "QUIET"
                    "FATAL"
                    "ERROR"
                    "INFO"
                    "VERBOSE"
                    "DEBUG"
                    "DEBUG1"
                    "DEBUG2"
                    "DEBUG3"
                  ]
                );
                default = "INFO"; # upstream default
                description = ''
                  Gives the verbosity level that is used when logging messages from {manpage}`sshd(8)`. Logging with a DEBUG level
                  violates the privacy of users and is not recommended.
                '';
              };
              UsePAM = lib.mkEnableOption "PAM authentication" // {
                default = false; # upstream default
                type = lib.types.nullOr lib.types.bool;
              };
              UseDns = lib.mkOption {
                type = lib.types.nullOr lib.types.bool;
                default = false;
                description = ''
                  Specifies whether {manpage}`sshd(8)` should look up the remote host name, and to check that the resolved host name for
                  the remote IP address maps back to the very same IP address.
                  If this option is set to no (the default) then only addresses and not host names may be used in
                  ~/.ssh/authorized_keys from and sshd_config Match Host directives.
                '';
              };
              X11Forwarding = lib.mkOption {
                type = lib.types.nullOr lib.types.bool;
                default = false; # upstream default
                description = ''
                  Whether to allow X11 connections to be forwarded.
                '';
              };
              PasswordAuthentication = lib.mkOption {
                type = lib.types.nullOr lib.types.bool;
                default = true; # upstream default
                description = ''
                  Specifies whether password authentication is allowed.
                '';
              };
              PermitRootLogin = lib.mkOption {
                default = "prohibit-password"; # upstream default
                type = lib.types.nullOr (
                  lib.types.enum [
                    "yes"
                    "without-password"
                    "prohibit-password"
                    "forced-commands-only"
                    "no"
                  ]
                );
                description = ''
                  Whether the root user can login using ssh.
                '';
              };
              KbdInteractiveAuthentication = lib.mkOption {
                type = lib.types.nullOr lib.types.bool;
                default = true; # upstream default
                description = ''
                  Specifies whether keyboard-interactive authentication is allowed.
                '';
              };
              GatewayPorts = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = "no"; # upstream default
                description = ''
                  Specifies whether remote hosts are allowed to connect to
                  ports forwarded for the client.  See
                  {manpage}`sshd_config(5)`.
                '';
              };
              KexAlgorithms = lib.mkOption {
                type = lib.types.nullOr (lib.types.listOf lib.types.str);
                default = [
                  "mlkem768x25519-sha256"
                  "sntrup761x25519-sha512"
                  "sntrup761x25519-sha512@openssh.com"
                  "curve25519-sha256"
                  "curve25519-sha256@libssh.org"
                  "diffie-hellman-group-exchange-sha256"
                ]; # NixOS default for security
                description = ''
                  Allowed key exchange algorithms

                  Uses the lower bound recommended in both
                  <https://stribika.github.io/2015/01/04/secure-secure-shell.html>
                  and
                  <https://infosec.mozilla.org/guidelines/openssh#modern-openssh-67>
                '';
              };
              MACs = lib.mkOption {
                type = lib.types.nullOr (lib.types.listOf lib.types.str);
                default = [
                  "hmac-sha2-512-etm@openssh.com"
                  "hmac-sha2-256-etm@openssh.com"
                  "umac-128-etm@openssh.com"
                ]; # NixOS default for security
                description = ''
                  Allowed MACs

                  Defaults to recommended settings from both
                  <https://stribika.github.io/2015/01/04/secure-secure-shell.html>
                  and
                  <https://infosec.mozilla.org/guidelines/openssh#modern-openssh-67>
                '';
              };
              StrictModes = lib.mkOption {
                type = lib.types.nullOr (lib.types.bool);
                default = true; # upstream default
                description = ''
                  Whether sshd should check file modes and ownership of directories
                '';
              };
              Ciphers = lib.mkOption {
                type = lib.types.nullOr (lib.types.listOf lib.types.str);
                default = [
                  "chacha20-poly1305@openssh.com"
                  "aes256-gcm@openssh.com"
                  "aes128-gcm@openssh.com"
                  "aes256-ctr"
                  "aes192-ctr"
                  "aes128-ctr"
                ]; # upstream default
                description = ''
                  Allowed ciphers

                  Defaults to recommended settings from both
                  <https://stribika.github.io/2015/01/04/secure-secure-shell.html>
                  and
                  <https://infosec.mozilla.org/guidelines/openssh#modern-openssh-67>
                '';
              };
              AllowUsers = lib.mkOption {
                type = lib.types.nullOr (lib.types.listOf lib.types.str);
                default = null; # upstream default
                description = ''
                  If specified, login is allowed only for the listed users.
                  See {manpage}`sshd_config(5)` for details.
                '';
              };
              DenyUsers = lib.mkOption {
                type = lib.types.nullOr (lib.types.listOf lib.types.str);
                default = null; # upstream default
                description = ''
                  If specified, login is denied for all listed users. Takes
                  precedence over [](#opt-services.openssh.settings.AllowUsers).
                  See {manpage}`sshd_config(5)` for details.
                '';
              };
              AllowGroups = lib.mkOption {
                type = lib.types.nullOr (lib.types.listOf lib.types.str);
                default = null; # upstream default
                description = ''
                  If specified, login is allowed only for users part of the
                  listed groups.
                  See {manpage}`sshd_config(5)` for details.
                '';
              };
              DenyGroups = lib.mkOption {
                type = lib.types.nullOr (lib.types.listOf lib.types.str);
                default = null; # upstream default
                description = ''
                  If specified, login is denied for all users part of the listed
                  groups. Takes precedence over
                  [](#opt-services.openssh.settings.AllowGroups). See
                  {manpage}`sshd_config(5)` for details.
                '';
              };
              PrintMotd = lib.mkOption {
                type = lib.types.nullOr lib.types.bool;
                default = true; # upstream default
                description = ''
                  Specifies whether sshd should print /etc/motd when a user logs in interactively.
                '';
              };
              Include = lib.mkOption {
                type = lib.types.nullOr (lib.types.listOf lib.types.str);
                default = null;
                description = ''
                  Include  the  specified  configuration file(s).
                  Multiple pathnames may be specified and each pathname may contain glob(7)
                  wildcards that will be expanded and processed in lexical order.
                  Files without absolute paths are assumed to be in /etc/ssh.
                '';
              };
              Subsystem = lib.mkOption {
                type = lib.types.nullOr (lib.types.listOf lib.types.str);
                default = [
                  "sftp"
                  "/usr/libexec/sftp-server"
                ]; # macOS default
                description = ''
                  Configures an external subsystem (e.g. file transfer daemon).
                  Arguments  should be a subsystem name and a command
                  (with optional arguments) to execute upon subsystem request.
                '';
              };
              PubkeyAuthentication = lib.mkOption {
                type = lib.types.nullOr (lib.types.bool);
                default = true; # upstream default
                description = ''
                  Whether sshd should allow public key authentication
                '';
              };
              AuthorizedKeysFile = lib.mkOption {
                type = lib.types.nullOr (lib.types.listOf lib.types.str);
                default = [ ".ssh/authorized_keys" ]; # macOS default
                description = ''
                  Specifies a file that lists principal names that are accepted for certificate authentication. The default
                  is `"none"`, i.e. not to use	a principals file.
                '';
              };
            };
          }
        );
      };
    };
  };

  config = {
    # We don't use `systemsetup -setremotelogin` as it requires Full Disk Access
    system.activationScripts.launchd.text = lib.mkIf (cfg.enable != null) (
      if cfg.enable then
        ''
          if [[ "$(systemsetup -getremotelogin | sed 's/Remote Login: //')" == "Off" ]]; then
            launchctl enable system/com.openssh.sshd
            launchctl bootstrap system /System/Library/LaunchDaemons/ssh.plist
          fi
        ''
      else
        ''
          if [[ "$(systemsetup -getremotelogin | sed 's/Remote Login: //')" == "On" ]]; then
            launchctl bootout system/com.openssh.sshd
            launchctl disable system/com.openssh.sshd
          fi
        ''
    );

    environment.etc."ssh/sshd_config.d/100-nix-darwin.conf".source = sshConfNixDarwin;

    system.checks.text = lib.mkAfter ''
      ${pkgs.openssh.override { withPAM = true; }}/bin/sshd -G -T -f ${sshConfNixDarwin} > /dev/null
    '';
  };
}
