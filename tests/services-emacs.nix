{ config, lib, pkgs, ... }:

let
  runJob = import ./run-launchd-job.nix { inherit lib pkgs; };
in
{
  system.primaryUser = "test-emacs-user";
  services.emacs = {
    enable = true;
    package = lib.mkDefault (pkgs.writeShellScriptBin "emacs" ''
      printf '%s\n' "$@"
    '');
  };
  launchd.user.agents.emacs.serviceConfig.ProgramArguments = lib.mkAfter [ "--debug-init" ];

  test = ''
    ${runJob config.launchd.user.agents.emacs} > emacs-args
    diff -u - emacs-args <<'ARGS'
    --fg-daemon
    --debug-init
    ARGS
  '';
}
