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
  power.universal = {
    sleep = {
      systemAfter = "never";
      displayAfter = 15;
      diskAfter = 5;
    };
    powerNap = false;
    tcpKeepAlive = true;
    wakeOnNetworkAccess = true;
    ttysKeepAwake = true;
    powerMode = "automatic";
    standby = true;
    autoRestart = {
      afterPowerFailure = true;
      afterSystemFreeze = true;
      afterPowerFailureDelay = 30;
      onPowerConnect = true;
    };
    allowSleepByPowerButton = false;
    extraPmsetSettings = {
      lidwake = "1";
      gpuswitch = "0";
    };
  };

  power.ac = {
    sleep.systemAfter = 60;
    powerMode = "high"; # tests powerMode "high" → 2
  };

  power.battery = {
    sleep.systemAfter = 5;
    sleep.displayAfter = 2;
    reduceBrightness = true;
    powerMode = "low";
    standby = true;
    # Precedence test: typed option says true (would render `tcpkeepalive 1`), extra overrides to
    # "0". Asserted below to render `tcpkeepalive 0`.
    tcpKeepAlive = true;
    extraPmsetSettings.tcpkeepalive = "0";
  };

  power.ups = {
    standby = false;
    halt = {
      batteryLevel = "never"; # tests halt-level "never" → -1
      elapsedMinutes = "never";
      remainingMinutes = 30;
    };
  };

  test = ''
    echo "checking universal pmset entries (typed)" >&2
    ${mkTest "pmset -a" "sleep 0"}
    ${mkTest "pmset -a" "displaysleep 15"}
    ${mkTest "pmset -a" "disksleep 5"}
    ${mkTest "pmset -a" "powernap 0"}
    ${mkTest "pmset -a" "tcpkeepalive 1"}
    ${mkTest "pmset -a" "womp 1"}
    ${mkTest "pmset -a" "ttyskeepawake 1"}
    ${mkTest "pmset -a" "autorestartatconnect 1"}
    ${mkTest "pmset -a" "powermode 0"}
    ${mkTest "pmset -a" "standby 1"}

    echo "checking universal pmset entries (extraPmsetSettings)" >&2
    ${mkTest "pmset -a" "lidwake 1"}
    ${mkTest "pmset -a" "gpuswitch 0"}

    echo "checking non-pmset (systemsetup) settings" >&2
    ${mkTest "systemsetup -setrestartfreeze" "on"}
    ${mkTest "systemsetup -setrestartpowerfailure" "on"}
    ${mkTest "systemsetup -setwaitforstartupafterpowerfailure" "30"}
    ${mkTest "systemsetup -setallowpowerbuttontosleepcomputer" "off"}

    echo "checking AC source" >&2
    ${mkTest "pmset -c" "sleep 60"}
    ${mkTest "pmset -c" "powermode 2"}

    echo "checking battery source" >&2
    ${mkTest "pmset -b" "sleep 5"}
    ${mkTest "pmset -b" "displaysleep 2"}
    ${mkTest "pmset -b" "lessbright 1"}
    ${mkTest "pmset -b" "powermode 1"}
    ${mkTest "pmset -b" "standby 1"}

    echo "checking UPS source" >&2
    ${mkTest "pmset -u" "haltlevel -1"}
    ${mkTest "pmset -u" "haltafter -1"}
    ${mkTest "pmset -u" "haltremain 30"}
    ${mkTest "pmset -u" "standby 0"}

    echo "checking extraPmsetSettings precedence over typed options" >&2
    ${mkTest "pmset -b" "tcpkeepalive 0"}
    if grep -F 'pmset -b' ${config.out}/activate | grep -F 'tcpkeepalive 1' > /dev/null; then
      echo "extraPmsetSettings.tcpkeepalive=\"0\" did NOT take precedence over typed tcpKeepAlive=true on battery"
      exit 1
    fi

    echo "checking universal runs before per-source pmset calls" >&2
    awk '
      /pmset -[bcu]/ { seen_per_source = 1 }
      /pmset -a/ {
        if (seen_per_source) {
          print "pmset -a appeared after per-source pmset call at line " NR
          exit 1
        }
        seen_universal = 1
      }
      END {
        if (!seen_universal) {
          print "no pmset -a found despite per-source pmset call"
          exit (seen_per_source ? 1 : 0)
        }
      }
    ' ${config.out}/activate
  '';
}
