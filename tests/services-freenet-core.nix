{
  config,
  pkgs,
  ...
}:

let
  freenet = pkgs.writeShellScriptBin "freenet" "";
  plist = "${config.out}/user/Library/LaunchAgents/org.nixos.freenet-core.plist";
in
{
  system.primaryUser = "test-freenet-user";

  services.freenet-core = {
    enable = true;
    package = freenet;
    dataDir = "/var/lib/freenet-data";
    configDir = "/var/lib/freenet-config";
    logDir = "/var/log/freenet";
    networkAddress = "192.0.2.1";
    networkPort = 31338;
    websocketAddress = "127.0.0.2";
    websocketPort = 7510;
    nice = 5;
    environment.FREENET_TEST = "enabled";
    extraArgs = [ "--telemetry-enabled" ];
  };

  test = ''
    echo >&2 "checking Freenet service in ~/Library/LaunchAgents"
    grep "org.nixos.freenet-core" ${plist}
    grep "${freenet}/bin/freenet" ${plist}
    grep -- "--disable-auto-update" ${plist}
    grep -- "--data-dir=/var/lib/freenet-data" ${plist}
    grep -- "--config-dir=/var/lib/freenet-config" ${plist}
    grep -- "--log-dir=/var/log/freenet" ${plist}
    grep -- "--network-address=192.0.2.1" ${plist}
    grep -- "--network-port=31338" ${plist}
    grep -- "--ws-api-address=127.0.0.2" ${plist}
    grep -- "--ws-api-port=7510" ${plist}
    grep -- "--telemetry-enabled" ${plist}
    grep "FREENET_TEST" ${plist}
    grep "enabled" ${plist}
    grep "<integer>5</integer>" ${plist}
    grep "<key>KeepAlive</key>" ${plist}
    grep "<key>SuccessfulExit</key>" ${plist}
    grep "<false/>" ${plist}
    grep "<key>ExitTimeOut</key>" ${plist}
    grep "<integer>45</integer>" ${plist}
  '';
}
