{ config, lib, pkgs, ... }:

let
  runJob = import ./run-launchd-job.nix { inherit lib pkgs; };
in
{
  system.primaryUser = "test-synergy-user";
  services.synergy.package = pkgs.writeShellScriptBin "synergyc" ''
    printf '%s\n' "$@"
  '';
  services.synergy.client = {
    enable = true;
    screenName = "Studio Mac";
    serverAddress = "server.example.org";
    tls.enable = true;
    tls.cert = "/certs/Client Identity.pem";
  };

  test = ''
    ${runJob config.launchd.user.agents.synergy-client} > client-args
    diff -u - client-args <<'ARGS'
    -f
    --enable-crypto
    --tls-cert
    /certs/Client Identity.pem
    -n
    Studio Mac
    server.example.org
    ARGS
  '';
}
