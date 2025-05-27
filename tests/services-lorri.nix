{
  config,
  pkgs,
  lib,
  ...
}:

let
  plistPath = "${config.out}/user/Library/LaunchAgents/org.nixos.lorri.plist";
  expectedPath = "${lib.makeBinPath [
    config.nix.package
    pkgs.git
    pkgs.gnutar
    pkgs.gzip
  ]}";
  expectedNixPath = "${"nixpkgs=" + toString pkgs.path}";
in
{
  system.primaryUser = "test-lorri-user";

  services.lorri.enable = true;
  test = ''
    PATH=${
      lib.makeBinPath [
        pkgs.xcbuild
        pkgs.jq
      ]
    }:$PATH

    plutil -lint ${plistPath}
    plutil -convert json -o service.json ${plistPath}

    <service.json jq -e ".EnvironmentVariables.PATH     == \"${expectedPath}\""
    <service.json jq -e ".EnvironmentVariables.NIX_PATH == \"${expectedNixPath}\""
    <service.json jq -e ".KeepAlive                     == true"
    <service.json jq -e ".Label                         == \"org.nixos.lorri\""
    <service.json jq -e ".ProcessType                   == \"Background\""
    <service.json jq -e ".ProgramArguments|length       == 3"
    <service.json jq -e ".ProgramArguments[0]           == \"/bin/sh\""
    <service.json jq -e ".ProgramArguments[1]           == \"-c\""
    <service.json jq -e ".ProgramArguments[2]           == \"/bin/wait4path /nix/store && exec ${pkgs.lorri}/bin/lorri daemon\""
    <service.json jq -e ".RunAtLoad                     == true"
  '';
}
