{ config, ... }:

{
  networking.enableHosts = true;

  networking.hosts = {
    "192.168.1.1" = [
      "myhost.local"
      "myhost"
    ];
    "10.0.0.1" = [ "gateway.local" ];
  };

  networking.extraHosts = ''
    172.16.0.1 docker-host
  '';

  test = ''
    echo "checking /etc/hosts activation script" >&2
    grep "setting up /etc/hosts" ${config.out}/activate

    echo "checking generated hosts file content" >&2
    hostsFile=$(grep -o '/nix/store/[^ ]*-hosts' ${config.out}/activate | head -1)
    echo "generated hosts file: $hostsFile" >&2

    grep "127.0.0.1 localhost" "$hostsFile"
    grep "::1 localhost" "$hostsFile"
    grep "192.168.1.1 myhost.local myhost" "$hostsFile"
    grep "10.0.0.1 gateway.local" "$hostsFile"
    grep "172.16.0.1 docker-host" "$hostsFile"

    echo "checking Nix-managed markers in activation script" >&2
    grep -F "printf '# BEGIN Nix-managed\n'" ${config.out}/activate
    grep -F "printf '# END Nix-managed\n'" ${config.out}/activate

    echo "checking existing content preservation logic" >&2
    grep -F "sed '/^# BEGIN Nix-managed\$/,/^# END Nix-managed\$/d'" ${config.out}/activate
  '';
}
