{ config, extendModules, lib, pkgs, ... }:

let
  runJob = import ./run-launchd-job.nix { inherit lib pkgs; };
  agents = config.launchd.user.agents;
  withTLS = extendModules {
    modules = [ {
      services.synergy.client.tls = { enable = true; cert = "/certs/Client Identity.pem"; };
      services.synergy.server.tls = { enable = true; cert = "/certs/Server Identity.pem"; };
    } ];
  };
  tlsAgents = withTLS.config.launchd.user.agents;

  recorder = name: pkgs.writeShellScriptBin name ''
    printf '%s\n' ${name} "$@"
  '';
in

{
  system.primaryUser = "test-synergy-user";

  services.synergy.package = pkgs.symlinkJoin {
    name = "synergy";
    paths = map recorder [ "synergyc" "synergys" ];
  };

  services.synergy.client.enable = true;
  services.synergy.client.screenName = "client_screenName";
  services.synergy.client.serverAddress = "123.123.123.123:123";

  services.synergy.server.enable = true;
  services.synergy.server.configFile = "/tmp/synergy.conf";
  services.synergy.server.screenName = "server_screenName";
  services.synergy.server.address = "0.0.0.0:123";

  test = ''
    for role in client server; do
      grep -F "org.nixos.synergy-$role" "${config.out}/user/Library/LaunchAgents/org.nixos.synergy-$role.plist"
    done

    checkArgs() {
      printf '%s\n' "$@" | diff -u - actual
    }

    ${runJob agents.synergy-client} > actual
    checkArgs synergyc -f -n client_screenName 123.123.123.123:123
    ${runJob agents.synergy-server} > actual
    checkArgs synergys -c /tmp/synergy.conf -f -n server_screenName -a 0.0.0.0:123

    ${runJob tlsAgents.synergy-client} > actual
    checkArgs synergyc -f --enable-crypto --tls-cert '/certs/Client Identity.pem' \
      -n client_screenName 123.123.123.123:123
    ${runJob tlsAgents.synergy-server} > actual
    checkArgs synergys -c /tmp/synergy.conf -f --enable-crypto --tls-cert '/certs/Server Identity.pem' \
      -n server_screenName -a 0.0.0.0:123
  '';
}
