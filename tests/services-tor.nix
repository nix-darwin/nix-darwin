{
  config,
  pkgs,
  ...
}:

let
  tor = pkgs.runCommand "tor-0.0.0" { } "mkdir $out";
in
{
  services.tor = {
    enable = true;
    package = tor;
    client.enable = true;
    client.dns = {
      enable = true;
      listenAddress = "127.0.0.1:9999";
    };
    settings = {
      ControlPort = 9051;
      Log = [ "notice stdout" ];
      DisableNetwork = null;
    };
    relay.onionServices.example = {
      map = [
        { port = 80; target = { port = 8080; }; }
        { port = 22; }
      ];
      authorizedClients = [
        "descriptor:x25519:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
      ];
    };
  };

  test = ''
    plist=${config.out}/Library/LaunchDaemons/org.nixos.tor.plist

    echo >&2 "checking tor daemon registration"
    grep -q "org.nixos.tor" -- "$plist"
    grep -q "/usr/bin/sandbox-exec" -- "$plist"
    grep -q "${tor}/bin/tor" -- "$plist"

    echo >&2 "checking _tor service user/group"
    grep -q "<string>_tor</string>" -- "$plist"

    echo >&2 "checking torrc path is wired into launchd"
    grep -qE "/nix/store/[^<]*-torrc" -- "$plist"

    echo >&2 "checking sandbox profile path is wired into launchd"
    grep -qE "/nix/store/[^<]*-sandbox\.sb" -- "$plist"

    echo >&2 "checking log paths"
    grep -q "/var/lib/tor/tor.log" -- "$plist"
  '';

  assertions = [
    {
      assertion = config.services.tor.settings.SOCKSPort == 9050;
      message = "client.enable should default SOCKSPort to 9050";
    }
    {
      assertion = config.services.tor.settings.DNSPort == "127.0.0.1:9999";
      message = "client.dns.enable should set DNSPort to listenAddress";
    }
    {
      assertion = config.services.tor.settings.ControlPort == 9051;
      message = "freeform settings should pass ControlPort through";
    }
    {
      assertion = config.users.users._tor.home == "/var/lib/tor";
      message = "_tor service user's home should be /var/lib/tor";
    }
    {
      assertion =
        let svc = config.services.tor.relay.onionServices.example;
            e0 = builtins.elemAt svc.map 0;
            e1 = builtins.elemAt svc.map 1;
        in e0.target.port == 8080 && e1.target == null;
      message = "onion map should accept both explicit target and null (default) target";
    }
  ];
}
