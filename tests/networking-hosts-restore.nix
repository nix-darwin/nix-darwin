{ config, ... }:

{
  networking.enableHosts = true;
  # Deliberately no networking.hosts, extraHosts, or hostFiles set
  # (tests the "content is empty / restore" path)

  test = ''
    echo "checking activation script runs even without host content" >&2
    grep "setting up /etc/hosts" ${config.out}/activate

    echo "checking sed stripping logic is present" >&2
    grep -F "sed '/^# BEGIN Nix-managed\$/,/^# END Nix-managed\$/d'" ${config.out}/activate

    echo "checking original content preservation is in the script" >&2
    grep "hostsOriginal" ${config.out}/activate

    echo "checking restore path writes original back (no Nix block)" >&2
    grep "hostsOriginal.*> /etc/hosts" ${config.out}/activate

    echo "checking Nix-managed markers are NOT written" >&2
    if grep -F "printf '# BEGIN Nix-managed\n'" ${config.out}/activate; then
      echo "FAIL: Nix-managed block should not be written when no content" >&2
      exit 1
    fi
    if grep -F "printf '# END Nix-managed\n'" ${config.out}/activate; then
      echo "FAIL: Nix-managed END marker should not be written" >&2
      exit 1
    fi

    echo "ok: restore path verified" >&2
  '';
}
