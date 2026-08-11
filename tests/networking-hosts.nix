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
    set -e
    tmpDir=$(mktemp -d)
    hostsPath=$tmpDir/hosts
    printf '%s\n' 'custom unmanaged entry' > "$hostsPath"

    sed -n '/setting up \/etc\/hosts/,/# Make this configuration the current configuration./{ /# Make this configuration/q; p; }' \
      ${config.out}/activate | sed "s#/etc/hosts#$hostsPath#g" > "$tmpDir/hosts-activate"
    if [[ ! -s "$tmpDir/hosts-activate" ]]; then
      printf 'FAIL: generated hosts activation fragment is empty\n' >&2
      exit 1
    fi
    bash "$tmpDir/hosts-activate"

    assertLine() {
      if ! grep -Fx "$1" "$hostsPath" >/dev/null; then
        printf 'FAIL: expected hosts line: %s\n' "$1" >&2
        printf '%s\n' 'Actual hosts file:' >&2
        nl -ba "$hostsPath" >&2
        exit 1
      fi
    }
    assertLine 'custom unmanaged entry'
    assertLine '127.0.0.1 localhost'
    assertLine '::1 localhost'
    assertLine '192.168.1.1 myhost.local myhost'
    assertLine '10.0.0.1 gateway.local'
    assertLine '172.16.0.1 docker-host'
  '';
}
