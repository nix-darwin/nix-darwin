{ config, ... }:

# Tests that enabling networking.enableHosts without any entry to add does
# not touch /etc/hosts, including when networking.hosts only maps addresses
# to empty lists of hostnames, which generate no line.

{
  networking.enableHosts = true;
  networking.hosts = {
    "192.168.1.1" = [ ];
  };

  test = ''
    set -e
    tmpDir=$(mktemp -d)
    hostsPath=$tmpDir/hosts
    printf '%s\n' 'only unmanaged' > "$hostsPath"
    inodeBefore=$(ls -i "$hostsPath" | cut -d' ' -f1)

    sed -n '/^generateHosts() {/,/# Make this configuration the current configuration./{ /# Make this configuration/q; p; }' \
      ${config.out}/activate | sed "s#/etc/hosts#$hostsPath#g" > "$tmpDir/hosts-activate"
    output=$(bash "$tmpDir/hosts-activate" 2>&1)

    inodeAfter=$(ls -i "$hostsPath" | cut -d' ' -f1)
    if [[ "$inodeBefore" != "$inodeAfter" ]] || [[ "$(cat "$hostsPath")" != 'only unmanaged' ]]; then
      printf 'FAIL: expected hosts file to be left untouched\n' >&2
      nl -ba "$hostsPath" >&2
      exit 1
    fi

    if [[ -n "$output" ]]; then
      printf 'FAIL: expected no output when there is nothing to do, got: %s\n' "$output" >&2
      exit 1
    fi

    # ... and a missing one is not created.
    rm "$hostsPath"
    output=$(bash "$tmpDir/hosts-activate" 2>&1)
    if [[ -n "$output" ]]; then
      printf 'FAIL: expected no output when there is nothing to do, got: %s\n' "$output" >&2
      exit 1
    fi
    if [[ -e "$hostsPath" ]]; then
      printf 'FAIL: expected a missing /etc/hosts to stay missing\n' >&2
      exit 1
    fi
  '';
}
