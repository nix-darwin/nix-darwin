{ config, lib, pkgs, ... }:

let
  runJob = import ./run-launchd-job.nix { inherit lib pkgs; };
in
{
  system.primaryUser = "test-launchd-user";

  launchd.daemons.foo = {
    command = ''
      ${lib.getExe' pkgs.coreutils "printf"} '<%s>\n' fixed
    '';
    serviceConfig.ProgramArguments = lib.mkAfter [ "--first" "two words" "" "$HOME" "*" ];
  };
  launchd.agents.bar.command = ''
    ${lib.getExe' pkgs.coreutils "cat"} <<'EOF'
    payload
    EOF
  '';
  launchd.user.agents.baz.command = "baz";

  test = ''
    ${runJob config.launchd.daemons.foo} > actual
    diff -u - actual <<'ARGS'
    <fixed>
    <--first>
    <two words>
    <>
    <$HOME>
    <*>
    ARGS

    ${runJob config.launchd.agents.bar} > actual
    printf 'payload\n' | diff -u - actual

    echo "checking launchd load in /activate" >&2
    grep "launchctl load .* '/Library/LaunchDaemons/org.nixos.foo.plist" ${config.out}/activate
    grep "launchctl load .* '/Library/LaunchAgents/org.nixos.bar.plist" ${config.out}/activate
    echo "checking launchd user agent load in /activate" >&2
    grep "sudo --user=test-launchd-user -- launchctl load .* ~test-launchd-user/Library/LaunchAgents/org.nixos.baz.plist" ${config.out}/activate
    echo "checking LaunchAgents creation /activate" >&2
    grep "sudo --user=test-launchd-user -- mkdir -p ~test-launchd-user/Library/LaunchAgents" ${config.out}/activate
  '';
}
