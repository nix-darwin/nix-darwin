{ config, ... }:

let
  mkTest = filter: result: ''
    if ! grep -F '${filter}' ${config.out}/activate | grep -wF '${result}' > /dev/null; then
      echo "Expected '${result}' in line matching '${filter}'"
      echo "Lines matching filter:"
      grep -F '${filter}' ${config.out}/activate || echo "(filter '${filter}' not found)"
      exit 1
    fi
  '';
in

{
  # Legacy option paths must still work via `mkRenamedOptionModule` and route to the same
  # `pmset`/`systemsetup` writes the new option paths produce.
  power.sleep.computer = "never";
  power.sleep.display = 15;
  power.sleep.harddisk = 5;
  power.sleep.allowSleepByPowerButton = false;
  power.restartAfterPowerFailure = true;
  power.restartAfterFreeze = true;
  networking.wakeOnLan.enable = true;

  test = ''
    echo "checking sleep timer renames produce pmset writes" >&2
    ${mkTest "pmset -a" "sleep 0"}
    ${mkTest "pmset -a" "displaysleep 15"}
    ${mkTest "pmset -a" "disksleep 5"}

    echo "checking restartAfterPowerFailure rename to autoRestart.afterPowerFailure" >&2
    ${mkTest "systemsetup -setrestartpowerfailure" "on"}
    # Negative: `afterPowerFailure` should continue to route through `systemsetup`, not pmset's
    # `autorestart` key. Guards against a regression where the module accidentally wires it
    # through pmset instead.
    if grep -qE 'pmset -[abcu]\b.*autorestart\b' ${config.out}/activate; then
      echo 'found `pmset autorestart` write; `afterPowerFailure` should go through systemsetup only'
      exit 1
    fi

    echo "checking networking.wakeOnLan.enable renames to wakeOnNetworkAccess" >&2
    ${mkTest "pmset -a" "womp 1"}

    echo "checking non-pmset settings still write via systemsetup" >&2
    ${mkTest "systemsetup -setrestartfreeze" "on"}
    ${mkTest "systemsetup -setallowpowerbuttontosleepcomputer" "off"}
  '';
}
