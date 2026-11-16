{ config, pkgs, ... }:

let
  tailscale = pkgs.runCommand "tailscale-0.0.0" { meta.mainProgram = "tailscale"; } ''
    mkdir -p $out/bin
    cat <<'EOF' > $out/bin/tailscaled
    #!/bin/sh
    exit 0
    EOF
    chmod +x $out/bin/tailscaled
  '';
in

{
  services.tailscale.enable = true;
  services.tailscale.package = tailscale;

  test = ''
    echo "checking tailscale daemon in /Library/LaunchDaemons" >&2
    grep "<string>com.tailscale.tailscaled</string>" ${config.out}/Library/LaunchDaemons/com.tailscale.tailscaled.plist
    grep "<string>${tailscale}/bin/tailscaled</string>" ${config.out}/Library/LaunchDaemons/com.tailscale.tailscaled.plist
    grep "<key>RunAtLoad</key>" ${config.out}/Library/LaunchDaemons/com.tailscale.tailscaled.plist

    echo "checking tailscale resolver configuration in /etc/resolver" >&2
    grep "nameserver 100.100.100.100" ${config.out}/etc/resolver/ts.net

    echo "checking tailscale cleanup script in /activate" >&2
    grep "rm /etc/resolver/ts.net.before-nix-darwin" ${config.out}/activate
  '';
}
