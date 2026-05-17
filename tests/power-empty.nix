{ config, ... }:

{
  # Intentionally no `power.*` configuration. The activation script for the power module should be
  # empty when nothing is set, and there should be no `pmset` or power-related `systemsetup`
  # invocations or `configuring power...` log line in the rendered activate script.

  test = ''
    echo "checking that empty power config produces no power activation output" >&2
    if grep -qF 'configuring power...' ${config.out}/activate; then
      echo "found 'configuring power...' line despite empty power config"
      exit 1
    fi
    if grep -qE '^[[:space:]]*pmset ' ${config.out}/activate; then
      echo "found pmset invocation despite empty power config"
      exit 1
    fi
    for flag in -setrestartfreeze -setrestartpowerfailure -setallowpowerbuttontosleepcomputer -setwaitforstartupafterpowerfailure; do
      if grep -qF "systemsetup $flag" ${config.out}/activate; then
        echo "found systemsetup $flag despite empty power config"
        exit 1
      fi
    done
  '';
}
