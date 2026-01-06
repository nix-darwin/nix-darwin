{
  config,
  lib,
  pkgs,
  ...
}:

let
  gnupg = pkgs.runCommand "gnupg-0.0.0" { } "mkdir -p $out/bin";
in

{
  system.primaryUser = "test-gnupg-user";

  programs.gnupg.package = gnupg;
  programs.gnupg.agent.enable = true;
  programs.gnupg.agent.enableSSHSupport = true;

  test = ''
    echo >&2 "checking gnupg-agent service in ~/Library/LaunchAgents"
    grep "org.nixos.gnupg-agent" ${config.out}/user/Library/LaunchAgents/org.nixos.gnupg-agent.plist
    grep "${gnupg}/bin/gpg-connect-agent" ${config.out}/user/Library/LaunchAgents/org.nixos.gnupg-agent.plist

    echo >&2 "checking GPG_TTY in set-environment"
    grep 'export GPG_TTY=\$(tty)' ${config.system.build.setEnvironment}

    echo >&2 "checking SSH support in set-environment"
    grep "${gnupg}/bin/gpg-connect-agent --quiet updatestartuptty /bye" ${config.system.build.setEnvironment}
    grep "${gnupg}/bin/gpgconf --list-dirs agent-ssh-socket" ${config.system.build.setEnvironment}
  '';
}
