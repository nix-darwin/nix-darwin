{ config, lib, pkgs, ... }:

let
  runJob = import ./run-launchd-job.nix { inherit lib pkgs; };
in
{
  system.primaryUser = "test-synergy-user";
  services.synergy.package = pkgs.writeShellScriptBin "synergys" ''
    printf '%s\n' "$@"
  '';
  services.synergy.server = {
    enable = true;
    screenName = "Server Mac";
    address = "localhost:24800";
    configFile = "/configs/Synergy Server.conf";
    tls.enable = true;
    tls.cert = "/certs/Server Identity.pem";
  };

  test = ''
    ${runJob config.launchd.user.agents.synergy-server} > server-args
    diff -u - server-args <<'ARGS'
    -c
    /configs/Synergy Server.conf
    -f
    --enable-crypto
    --tls-cert
    /certs/Server Identity.pem
    -n
    Server Mac
    -a
    localhost:24800
    ARGS
  '';
}
