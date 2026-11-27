{ config, ... }:

# Tests that updating /etc/hosts keeps the metadata of the existing file
# (mode, ACLs, extended attributes), and gives a new one sensible defaults.

{
  networking.enableHosts = true;
  networking.hosts."192.168.1.1" = [ "myhost.local" ];

  test = ''
    set -e
    tmpDir=$(mktemp -d)
    hostsPath=$tmpDir/hosts

    sed -n '/^generateHosts() {/,/# Make this configuration the current configuration./{ /# Make this configuration/q; p; }' \
      ${config.out}/activate | sed "s#/etc/hosts#$hostsPath#g" > "$tmpDir/hosts-activate"

    mode() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }

    printf '%s\n' 'custom unmanaged entry' > "$hostsPath"
    chmod 0640 "$hostsPath"
    # Not every build environment allows these, so only check what applies.
    haveXattr=
    if /usr/bin/xattr -w com.example.test hello "$hostsPath" 2>/dev/null; then haveXattr=1; fi
    haveAcl=
    if /bin/chmod +a 'everyone allow read' "$hostsPath" 2>/dev/null; then haveAcl=1; fi

    bash "$tmpDir/hosts-activate"

    if ! grep -Fx '192.168.1.1 myhost.local' "$hostsPath" >/dev/null; then
      printf 'FAIL: expected the hosts file to be updated\n' >&2
      exit 1
    fi
    if [[ "$(mode "$hostsPath")" != 640 ]]; then
      printf 'FAIL: expected mode 640 to be kept, got %s\n' "$(mode "$hostsPath")" >&2
      exit 1
    fi
    if [[ -n "$haveXattr" && "$(/usr/bin/xattr -p com.example.test "$hostsPath")" != hello ]]; then
      printf 'FAIL: extended attribute was lost\n' >&2
      exit 1
    fi
    if [[ -n "$haveAcl" ]] && ! /bin/ls -le "$hostsPath" | grep -q 'everyone allow read'; then
      printf 'FAIL: ACL was lost\n' >&2
      exit 1
    fi

    # A new file is world-readable.
    rm "$hostsPath"
    bash "$tmpDir/hosts-activate"
    if [[ "$(mode "$hostsPath")" != 644 ]]; then
      printf 'FAIL: expected mode 644 for a new file, got %s\n' "$(mode "$hostsPath")" >&2
      exit 1
    fi
  '';
}
