{ config, ... }:

# Tests that no temporary file outlives an activation, whether it fails, is
# interrupted or was killed outright in an earlier run.

{
  networking.enableHosts = true;
  networking.hosts."192.168.1.1" = [ "myhost.local" ];

  test = ''
    set -e
    tmpDir=$(mktemp -d)
    hostsPath=$tmpDir/hosts

    sed -n '/^generateHosts() {/,/# Make this configuration the current configuration./{ /# Make this configuration/q; p; }' \
      ${config.out}/activate | sed "s#/etc/hosts#$hostsPath#g" > "$tmpDir/hosts-activate"

    leftovers() { ls -A "$tmpDir" | grep '^hosts\.nix\.' || true; }
    assertClean() {
      if [[ -n "$(leftovers)" ]]; then
        printf 'FAIL: %s: temporary files left behind: %s\n' "$1" "$(leftovers)" >&2
        exit 1
      fi
    }

    mkdir "$tmpDir/stubs"
    printf '%s\n' '#!/bin/sh' 'exit 1' > "$tmpDir/stubs/mv"
    printf '%s\n' '#!/bin/sh' 'exec sleep 30' > "$tmpDir/stubs/slow-mv"
    chmod +x "$tmpDir/stubs/mv" "$tmpDir/stubs/slow-mv"

    # A failure after the temporary file was created (as activation runs
    # with `set -e`) removes it and leaves /etc/hosts alone.
    printf '%s\n' 'custom unmanaged entry' > "$hostsPath"
    if PATH="$tmpDir/stubs:$PATH" bash -e "$tmpDir/hosts-activate" 2>/dev/null; then
      printf 'FAIL: expected the activation to fail\n' >&2
      exit 1
    fi
    assertClean 'failure'
    if [[ "$(cat "$hostsPath")" != 'custom unmanaged entry' ]]; then
      printf 'FAIL: /etc/hosts changed despite the failure\n' >&2
      exit 1
    fi

    # Interrupting a running activation, as Ctrl-C or a kill of its process
    # group would, removes it too.
    mkdir "$tmpDir/slow"
    cp "$tmpDir/stubs/slow-mv" "$tmpDir/slow/mv"
    set -m
    PATH="$tmpDir/slow:$PATH" bash -e "$tmpDir/hosts-activate" 2>/dev/null &
    pid=$!
    for _ in $(seq 100); do
      if [[ -n "$(leftovers)" ]]; then break; fi
      sleep 0.1
    done
    if [[ -z "$(leftovers)" ]]; then
      printf 'FAIL: the interrupted activation never created a temporary file\n' >&2
      exit 1
    fi
    kill -TERM -- "-$pid"
    wait "$pid" || true
    set +m
    assertClean 'interruption'

    # Leftovers of a run that could not clean up (SIGKILL, power loss) are
    # swept by the next one, even if /etc/hosts needs no update.
    bash "$tmpDir/hosts-activate"
    assertClean 'success'
    sleep 0 &
    deadPid=$!
    wait "$deadPid"
    touch "$hostsPath.nix.$deadPid.AbC123"
    bash "$tmpDir/hosts-activate"
    assertClean 'sweep'

    # ... but not those of an activation that is still running, e.g. in
    # another terminal.
    sleep 60 &
    livePid=$!
    touch "$hostsPath.nix.$livePid.AbC123"
    bash "$tmpDir/hosts-activate"
    kill "$livePid"
    if [[ ! -e "$hostsPath.nix.$livePid.AbC123" ]]; then
      printf 'FAIL: removed the temporary file of a running activation\n' >&2
      exit 1
    fi
  '';
}
