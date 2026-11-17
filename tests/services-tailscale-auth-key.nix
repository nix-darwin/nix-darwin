{
  config,
  pkgs,
  ...
}:

let
  tailscale = pkgs.runCommand "tailscale-0.0.0" { } "mkdir -p $out/bin";
in
{
  services.tailscale = {
    enable = true;
    package = tailscale;
    authKeyFile = "/run/agenix/tailscale-auth-key";
    extraUpFlags = [
      "--login-server=https://headscale.example.com"
      "--hostname=mac"
    ];
  };

  test = ''
    plist=${config.out}/Library/LaunchDaemons/org.nixos.tailscaled-autoconnect.plist

    echo >&2 "checking tailscaled-autoconnect service in /Library/LaunchDaemons"
    test -f "$plist"
    script=$(grep -o '/nix/store/[^ <]*-tailscaled-autoconnect-start' -- "$plist")

    echo >&2 "checking tailscale up arguments"
    grep -q -- '--auth-key "file:/run/agenix/tailscale-auth-key"' "$script"
    grep -q -- "'--login-server=https://headscale.example.com' '--hostname=mac'" "$script"
  '';
}
