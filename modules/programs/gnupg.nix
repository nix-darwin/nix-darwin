{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let

  cfg = config.programs.gnupg;

in

{
  options.programs.gnupg = {
    agent.enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enables GnuPG agent for every user session.
      '';
    };

    agent.enableSSHSupport = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable SSH agent support in GnuPG agent. Also sets SSH_AUTH_SOCK
        environment variable correctly.
      '';
    };
  };

  config = mkIf cfg.agent.enable {
    launchd.user.agents.gnupg-agent.serviceConfig = {
      ProgramArguments = [
        "${pkgs.gnupg}/bin/gpg-connect-agent"
        "/bye"
      ];
      RunAtLoad = cfg.agent.enableSSHSupport;
      KeepAlive.SuccessfulExit = false;
    };

    environment.extraInit =
      ''
        # Bind gpg-agent to this TTY if gpg commands are used.
        export GPG_TTY=$(tty)
      ''
      + (optionalString cfg.agent.enableSSHSupport ''
        # SSH agent protocol doesn't support changing TTYs, so bind the agent
        # to every new TTY.
        ${pkgs.gnupg}/bin/gpg-connect-agent --quiet updatestartuptty /bye > /dev/null 2>&1

        export SSH_AUTH_SOCK=$(${pkgs.gnupg}/bin/gpgconf --list-dirs agent-ssh-socket)
      '');
  };
}
