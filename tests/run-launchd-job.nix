# The Darwin build sandbox has /nix/store mounted but blocks /bin/wait4path.
# Treat the wait as successful so the fixture receives the service arguments.
{ lib, pkgs }: job:
lib.escapeShellArgs (
  map (lib.replaceStrings [ "/bin/wait4path" ] [ (lib.getExe' pkgs.coreutils "true") ])
    job.serviceConfig.ProgramArguments
)
