{ config, lib, ... }:

with lib;

let
  cfg = config.power;

  # Format helpers ---------------------------------------------------------------------------------

  formatBool = b: if b then "1" else "0";
  formatOnOff = b: if b then "on" else "off";

  # Sleep timers: "never" → pmset's 0-disable convention.
  formatSleepTime = v: if v == "never" then "0" else toString v;

  # UPS halt settings: "never" → pmset's -1-disable convention (different from sleep timers).
  formatHaltSetting = v: if v == "never" then "-1" else toString v;

  # powerMode: pmset stores a single integer (0=automatic, 1=low, 2=high) under the key `powermode`
  # (visible in `pmset -g`), even though `pmset -g cap` shows `lowpowermode` and `highpowermode`.
  # The enum on the option uses `attrNames powerModeMap` so the option type and the formatter stay
  # in sync.
  powerModeMap = {
    automatic = "0";
    low = "1";
    high = "2";
  };
  formatPowerMode = v: powerModeMap.${v};

  # Custom types -----------------------------------------------------------------------------------

  # Positive minutes, or "never" (rendered to pmset's 0 or -1 depending on context).
  minutesType = with types; nullOr (either ints.positive (enum [ "never" ]));

  # UPS halt percent: 1..100, or "never" (= pmset's -1).
  percentType = with types; nullOr (either (ints.between 1 100) (enum [ "never" ]));

  # Option helpers ---------------------------------------------------------------------------------

  mkInternalOption =
    args:
    mkOption (
      args
      // {
        visible = false;
        internal = true;
        readOnly = true;
      }
    );

  mkNullOrBoolOption =
    args:
    mkOption (
      args
      // {
        type = types.nullOr types.bool;
        default = null;
      }
    );

  mkMinutesOption =
    args:
    mkOption (
      args
      // {
        type = minutesType;
        default = null;
      }
    );

  mkPercentOption =
    args:
    mkOption (
      args
      // {
        type = percentType;
        default = null;
      }
    );

  # Walk a `{ optName = { key, format }; ... }` mapping over a config attrset and produce
  # `{ <key> = format <value>; ... }` for every option that is set (non-null). Mapping entries
  # whose `optName` is absent from the config are silently skipped, so a single mapping can be
  # shared across option-set variants that conditionally include some options.
  mkPmsetEntries =
    mappings: cfg':
    foldlAttrs (
      acc: optName:
      { key, format }:
      let
        v = cfg'.${optName} or null;
      in
      if v == null then acc else acc // { ${key} = format v; }
    ) { } mappings;

  # Render a per-power-source pmset invocation. Returns "" if there are no entries.
  mkPmsetCommand =
    flag: entries:
    if entries == { } then
      ""
    else
      "pmset -${flag} "
      + concatStringsSep " " (mapAttrsToList (k: v: "${escapeShellArg k} ${escapeShellArg v}") entries);

  # Walk a `{ optName = { flag, format }; ... }` mapping over a config attrset and return a list
  # of `systemsetup <flag> <value>` shell commands for every option that is set (non-null).
  mkSystemsetupCommands =
    mappings: config:
    foldlAttrs (
      acc: optName:
      { flag, format }:
      if config.${optName} == null then
        acc
      else
        acc ++ [ "systemsetup ${flag} ${escapeShellArg (format config.${optName})} > /dev/null" ]
    ) [ ] mappings;

  # Nested option groups ---------------------------------------------------------------------------

  sleepOptions =
    { config, ... }:
    {
      options = {
        systemAfter = mkMinutesOption {
          description = ''
            Time of inactivity (in minutes) before the system sleeps. Use `"never"` to disable
            system sleep entirely.

            {command}`pmset` setting: `sleep` (`"never"` = `0`).
          '';
        };
        displayAfter = mkMinutesOption {
          description = ''
            Time of inactivity (in minutes) before connected displays sleep. Use `"never"` to
            disable display sleep.

            {command}`pmset` setting: `displaysleep` (`"never"` = `0`).
          '';
        };
        diskAfter = mkMinutesOption {
          description = ''
            Time of inactivity (in minutes) before macOS spins down spinning disks. Use `"never"`
            to disable.

            Has no effect on Macs with only SSD storage (no moving parts to spin down), but
            externally connected mechanical drives still adhere to it.

            {command}`pmset` setting: `disksleep` (`"never"` = `0`).
          '';
        };

        pmsetEntries = mkInternalOption { type = types.attrsOf types.str; };
      };

      config.pmsetEntries = mkPmsetEntries {
        systemAfter = {
          key = "sleep";
          format = formatSleepTime;
        };
        displayAfter = {
          key = "displaysleep";
          format = formatSleepTime;
        };
        diskAfter = {
          key = "disksleep";
          format = formatSleepTime;
        };
      } config;
    };

  haltOptions =
    { config, ... }:
    {
      options = {
        batteryLevel = mkPercentOption {
          description = ''
            UPS battery percent at which to trigger emergency shutdown. Use `"never"` to disable
            this halt condition.

            {command}`pmset` setting: `haltlevel` (`"never"` = `-1`).
          '';
        };
        elapsedMinutes = mkMinutesOption {
          description = ''
            Minutes after switching to UPS power before triggering emergency shutdown. Use `"never"`
            to disable this halt condition.

            {command}`pmset` setting: `haltafter` (`"never"` = `-1`).
          '';
        };
        remainingMinutes = mkMinutesOption {
          description = ''
            Minutes of estimated UPS runtime remaining at which to trigger emergency shutdown. Use
            `"never"` to disable this halt condition.

            {command}`pmset` setting: `haltremain` (`"never"` = `-1`).
          '';
        };

        pmsetEntries = mkInternalOption { type = types.attrsOf types.str; };
      };

      config.pmsetEntries = mkPmsetEntries {
        batteryLevel = {
          key = "haltlevel";
          format = formatHaltSetting;
        };
        elapsedMinutes = {
          key = "haltafter";
          format = formatHaltSetting;
        };
        remainingMinutes = {
          key = "haltremain";
          format = formatHaltSetting;
        };
      } config;
    };

  autoRestartOptions =
    { config, ... }:
    {
      options = {
        afterPowerFailure = mkNullOrBoolOption {
          description = ''
            Whether the computer automatically restarts after a power failure (the system loses
            external power, then power is restored). **Desktop-only.**

            {command}`systemsetup` flag: `-setrestartpowerfailure`.
          '';
        };
        afterPowerFailureDelay = mkOption {
          type = types.nullOr (
            types.addCheck (types.ints.unsigned // {
              description = "non-negative integer that is a multiple of 30 seconds";
            }) (n: mod n 30 == 0)
          );
          default = null;
          example = 60;
          description = ''
            Number of seconds to wait after external power is restored before automatically
            restarting. Must be a multiple of 30.

            The value is stored unconditionally and applies when
            [](#opt-power.universal.autoRestart.afterPowerFailure) is enabled.

            {command}`systemsetup` flag: `-setwaitforstartupafterpowerfailure`.
          '';
        };
        afterSystemFreeze = mkNullOrBoolOption {
          description = ''
            Whether the computer automatically restarts after a system freeze.

            {command}`systemsetup` flag: `-setrestartfreeze`.
          '';
        };
        onPowerConnect = mkNullOrBoolOption {
          description = ''
            Whether the computer automatically turns on when external power is connected (e.g.,
            plugging in the AC adapter while the machine is off). Distinct from
            [](#opt-power.universal.autoRestart.afterPowerFailure), which only covers the case of an
            already-running machine losing then regaining power. **Desktop-only.**

            ::: {.note}
            Per Apple's [support article](https://support.apple.com/en-us/125517), this feature
            requires macOS Tahoe 26.5 or later AND one of: Mac mini 2024+, Mac Studio 2025+, or iMac
            2024+. In Apple's System Settings UI, this option and
            [](#opt-power.universal.autoRestart.afterPowerFailure) combine into a single
            three-state dropdown ("Never" / "After power failure" / "Always"): "Always" implies both
            this option and `afterPowerFailure` are `true`.
            :::

            {command}`pmset` setting: `autorestartatconnect`.
          '';
        };

        pmsetEntries = mkInternalOption { type = types.attrsOf types.str; };
        systemsetupCommands = mkInternalOption { type = types.listOf types.str; };
      };

      config = {
        pmsetEntries = mkPmsetEntries {
          onPowerConnect = {
            key = "autorestartatconnect";
            format = formatBool;
          };
        } config;

        systemsetupCommands = mkSystemsetupCommands {
          afterPowerFailure = {
            flag = "-setrestartpowerfailure";
            format = formatOnOff;
          };
          afterSystemFreeze = {
            flag = "-setrestartfreeze";
            format = formatOnOff;
          };
          afterPowerFailureDelay = {
            flag = "-setwaitforstartupafterpowerfailure";
            format = toString;
          };
        } config;
      };
    };

  # Power source options ---------------------------------------------------------------------------

  # Mapping for all pmset settings that any power source might write. `mkPmsetEntries` silently
  # skips entries whose `optName` isn't present in the config, so options that only exist on a
  # specific source (e.g., `reduceBrightness` only on battery) can still live here without affecting
  # other sources.
  pmsetSettingsMapping = {
    reduceBrightness = {
      key = "lessbright";
      format = formatBool;
    };
    powerMode = {
      key = "powermode";
      format = formatPowerMode;
    };
    powerNap = {
      key = "powernap";
      format = formatBool;
    };
    standby = {
      key = "standby";
      format = formatBool;
    };
    tcpKeepAlive = {
      key = "tcpkeepalive";
      format = formatBool;
    };
    ttysKeepAwake = {
      key = "ttyskeepawake";
      format = formatBool;
    };
    wakeOnNetworkAccess = {
      key = "womp";
      format = formatBool;
    };
  };

  # Per-power-source factory. `pmsetPowerSourceFlag` is the pmset CLI flag (a/b/c/u).
  # `sourceSpecificOptions` lets universal/battery/ups attach options that don't exist on other
  # sources (declared here, with the entry rendering still going through the shared
  # `pmsetSettingsMapping` or one of the sub-option-set's own `pmsetEntries`).
  mkPowerSourceOptions =
    {
      pmsetPowerSourceFlag,
      sourceSpecificOptions ? { },
    }:
    { config, ... }:
    {
      options = {
        powerMode = mkOption {
          type = types.nullOr (types.enum (attrNames powerModeMap));
          default = null;
          description = ''
            Energy mode for this power source. Reflects macOS Low Power Mode and (where
            supported) High Power Mode. See Apple's
            [About Power Modes on your Mac](https://support.apple.com/en-us/101613) for the
            authoritative list of supported models for each.

            `"automatic"` (macOS default)
            :   macOS chooses energy/performance dynamically.

            `"low"`
            :   Enable Low Power Mode. On portables, reduces clocks, dims display, and throttles
                background activity to extend battery life. On supported Apple Silicon desktops
                reduces fan noise and lowers power consumption for Macs left running.

            `"high"`
            :   Enable High Power Mode: allows sustained higher performance with more aggressive
                thermal management, at the cost of fan noise.

            {command}`pmset` setting: `powermode` (`"automatic"`/`"low"`/`"high"` = `0`/`1`/`2`).
          '';
        };
        powerNap = mkNullOrBoolOption {
          description = ''
            Whether to enable Power Nap, which permits limited background activity while the system
            is asleep.

            {command}`pmset` setting: `powernap`.

            ::: {.note}
            Apple's GUI exposure of Power Nap varies by Mac model and macOS version (see Apple's
            [Power Nap support article](https://support.apple.com/guide/mac-help/turn-power-nap-on-or-off-mh40774/mac);
            the desktop instructions explicitly call out Intel-only support, while the laptop
            instructions don't). The capability still appears in {command}`pmset -g cap` on tested
            Apple Silicon hardware and the value is settable; real-world effect on Apple Silicon is
            undocumented.
            :::
          '';
        };
        sleep = mkOption {
          type = types.submodule sleepOptions;
          default = { };
          description = "Sleep timer settings for this power source.";
        };
        standby = mkNullOrBoolOption {
          description = ''
            Whether macOS automatically transitions from sleep to standby (a deeper sleep state
            where memory contents are written to disk and memory is powered down).

            {command}`pmset` setting: `standby`.
          '';
        };
        tcpKeepAlive = mkNullOrBoolOption {
          description = ''
            Whether the system wakes briefly during sleep to maintain TCP connections. macOS enables
            this by default; with it on, the system supports network-dependent features like push
            notifications, iMessage continuity, and remote sessions, but at the cost of periodic
            dark-wake events that draw small amounts of power.

            {command}`pmset` setting: `tcpkeepalive`.

            ::: {.note}
            Not documented in {manpage}`pmset(1)` manpage, but observed in {command}`pmset -g cap`
            on current macOS Apple Silicon hardware.
            :::
          '';
        };
        ttysKeepAwake = mkNullOrBoolOption {
          description = ''
            Whether to prevent idle system sleep when any tty (e.g., a remote login session) is
            active.

            {command}`pmset` setting: `ttyskeepawake`.
          '';
        };
        wakeOnNetworkAccess = mkNullOrBoolOption {
          description = ''
            Whether the Mac wakes on receipt of an Ethernet magic packet (or, on Macs that support
            wake-over-Wi-Fi via a compatible Bonjour Sleep Proxy on the network, a Wi-Fi wake
            event). Apple calls this "Wake for network access" in System Settings; it's commonly
            known as Wake-on-LAN (WoL).

            ::: {.note}
            For laptops, Apple's System Settings exposes this as a single three-state dropdown ("Never"
            / "Only on Power Adapter" / "Always"), not as independent AC/battery toggles.
            "Always" corresponds to setting both [](#opt-power.ac.wakeOnNetworkAccess) and
            [](#opt-power.battery.wakeOnNetworkAccess) to `true`; "Only on Power Adapter" is
            AC=`true`, battery=`false`. Setting only the battery source is non-standard and
            users report it doesn't reliably take effect.

            Network wake on Apple Silicon Macs has been widely reported as unreliable regardless
            of power source (see e.g., [this M1 Mac mini Apple Stack Exchange
            thread](https://apple.stackexchange.com/questions/435148/wake-up-a-sleeping-or-powered-off-m1-mac-mini-with-a-wake-on-lan-packet),
            open since 2022, 11k+ views, multiple users reporting unresolved issues across macOS
            versions).
            :::

            {command}`pmset` setting: `womp`.
          '';
        };

        extraPmsetSettings = mkOption {
          type = types.attrsOf types.str;
          default = { };
          example = {
            lidwake = "1";
            gpuswitch = "0";
          };
          description = ''
            Raw {command}`pmset` key/value pairs to apply to this power source. Both keys and values
            are passed through to {command}`pmset -${pmsetPowerSourceFlag}` as-is, with shell-safe
            quoting applied automatically. Refer to the {manpage}`pmset(1)` manpage for descriptions
            of available settings, and run {command}`pmset -g cap` on each power source to see
            which settings actually apply to your system on that source. Note that some settings
            appearing in {command}`pmset -g cap` are not documented in the manpage.

            Use this for settings not exposed through module options, typically Intel-era settings
            such as `lidwake`, `acwake`, `halfdim`, `sms`, `proximitywake`, `gpuswitch`, the standby
            delay family (`standbydelayhigh`, `standbydelaylow`, `highstandbythreshold`),
            `autopoweroff`/`autopoweroffdelay`, and hibernation relation settings. See
            [](#opt-power) for the general rules on how {command}`pmset` handles settings the
            hardware doesn't honor.

            ::: {.caution}
            If a key set here is also written by an option in this module on the same power source,
            the value here takes precedence. Prefer the module's options where available;
            `extraPmsetSettings` exists as an escape hatch for settings the module doesn't otherwise
            expose.
            :::
          '';
        };

        pmsetEntries = mkInternalOption { type = types.attrsOf types.str; };
        pmsetCommand = mkInternalOption { type = types.str; };
      }
      // sourceSpecificOptions;

      config = {
        pmsetEntries =
          mkPmsetEntries pmsetSettingsMapping config
          // config.sleep.pmsetEntries
          # `halt` only exists on the UPS source (per `sourceSpecificOptions`).
          // (config.halt.pmsetEntries or { })
          # `autoRestart` only exists on the universal source (per `sourceSpecificOptions`).
          // (config.autoRestart.pmsetEntries or { })
          // config.extraPmsetSettings;

        pmsetCommand = mkPmsetCommand pmsetPowerSourceFlag config.pmsetEntries;
      };
    };

  # Power source instantiations --------------------------------------------------------------------

  universalOptions = mkPowerSourceOptions {
    pmsetPowerSourceFlag = "a";
    sourceSpecificOptions = {
      allowSleepByPowerButton = mkNullOrBoolOption {
        description = ''
          Whether pressing the power button puts the computer to sleep.

          {command}`systemsetup` flag: `-setallowpowerbuttontosleepcomputer`.
        '';
      };
      autoRestart = mkOption {
        type = types.submodule autoRestartOptions;
        default = { };
        description = ''
          Settings that control when the Mac automatically restarts or turns on (after power
          failure, on power connect, after a system freeze, and the post-power-failure restart
          delay).
        '';
      };
    };
  };

  batteryOptions = mkPowerSourceOptions {
    pmsetPowerSourceFlag = "b";
    sourceSpecificOptions = {
      reduceBrightness = mkNullOrBoolOption {
        description = ''
          Whether to slightly turn down display brightness when switching to battery power.

          {command}`pmset` setting: `lessbright`.
        '';
      };
    };
  };

  acOptions = mkPowerSourceOptions { pmsetPowerSourceFlag = "c"; };

  upsOptions = mkPowerSourceOptions {
    pmsetPowerSourceFlag = "u";
    sourceSpecificOptions = {
      halt = mkOption {
        type = types.submodule haltOptions;
        default = { };
        description = ''
          UPS emergency-shutdown thresholds. None of these settings are observed on systems with an
          internal battery.
        '';
      };
    };
  };

in

{
  # Interface --------------------------------------------------------------------------------------

  # Legacy option paths from the previous power module, retained via `mkRenamedOptionModule` for
  # backward compatibility. The cross-module `networking.wakeOnLan.enable` rename has to live at the
  # top level; the intra-`power` renames live inside the `power` submodule (their FROM paths are
  # valid within it).
  imports = [
    (mkRenamedOptionModule [ "networking" "wakeOnLan" "enable" ] [ "power" "universal" "wakeOnNetworkAccess" ])
  ];

  options.power = mkOption {
    type = types.submodule {
      imports = [
        (mkRenamedOptionModule [ "sleep" "computer" ] [ "universal" "sleep" "systemAfter" ])
        (mkRenamedOptionModule [ "sleep" "display" ] [ "universal" "sleep" "displayAfter" ])
        (mkRenamedOptionModule [ "sleep" "harddisk" ] [ "universal" "sleep" "diskAfter" ])
        (mkRenamedOptionModule
          [ "restartAfterPowerFailure" ]
          [ "universal" "autoRestart" "afterPowerFailure" ]
        )
        (mkRenamedOptionModule
          [ "restartAfterFreeze" ]
          [ "universal" "autoRestart" "afterSystemFreeze" ]
        )
        (mkRenamedOptionModule
          [ "sleep" "allowSleepByPowerButton" ]
          [ "universal" "allowSleepByPowerButton" ]
        )
      ];
      options = {
        universal = mkOption {
          type = types.submodule universalOptions;
          default = { };
          description = ''
            Power management settings that apply across all power sources, plus
            power-source-agnostic settings such as the [](#opt-power.universal.autoRestart)
            family and [](#opt-power.universal.allowSleepByPowerButton).

            Where the same option also exists under [](#opt-power.ac), [](#opt-power.battery), or
            [](#opt-power.ups), the per-source value takes precedence when running on that source.
          '';
        };
        ac = mkOption {
          type = types.submodule acOptions;
          default = { };
          description = ''
            Power management settings applied only when running on AC power. Values here take
            precedence over the corresponding entries in [](#opt-power.universal) on this power
            source.
          '';
        };
        battery = mkOption {
          type = types.submodule batteryOptions;
          default = { };
          description = ''
            Power management settings applied only when running on battery power. Values here take
            precedence over the corresponding entries in [](#opt-power.universal) on this power
            source.

            Also exposes [](#opt-power.battery.reduceBrightness), which is meaningful only on
            battery.
          '';
        };
        ups = mkOption {
          type = types.submodule upsOptions;
          default = { };
          description = ''
            Power management settings applied only when running on UPS power. Values here take
            precedence over the corresponding entries in [](#opt-power.universal) on this power
            source.

            Also exposes UPS-specific halt thresholds at [](#opt-power.ups.halt).
          '';
        };
      };
    };
    default = { };
    description = ''
      Configures macOS power management.

      The module is organized by power source. Settings under [](#opt-power.universal) apply across
      all power sources; settings under [](#opt-power.ac), [](#opt-power.battery), and
      [](#opt-power.ups) apply only when the Mac is running on that specific power source, and take
      precedence over the corresponding [](#opt-power.universal) value. Most power sources also
      expose options unique to them; consult the per-source descriptions linked above for details.

      ::: {.note}
      **Verifying hardware support.** Many settings the module exposes won't apply on every Mac.
      Both {command}`pmset` and {command}`systemsetup` silently accept writes for settings the
      hardware doesn't honor, so a misconfigured option won't produce an error; it just won't take
      effect. The module includes activation-time checks for the most common silent-failure cases
      (high/low power mode, restart-after-power-failure, on-power-connect, and per-source options on
      Macs without that power source). For settings outside those checks, run
      {command}`pmset -g cap` on each power source you care about to see what your hardware
      advertises support for.
      :::

      ::: {.caution}
      **Unsetting an option doesn't revert it.** This module writes settings during activation but
      doesn't track or undo previous writes. Removing an option from your configuration (or setting
      it back to `null`) just stops the module from writing that value next activation; the last
      value you set persists in macOS's power-management state. To revert a setting to its macOS
      default, set it explicitly to that default in your configuration. You can also run
      {command}`sudo pmset restoredefaults`, to reset all settings set via {command}`pmset` to their
      default values.
      :::
    '';
  };

  # Implementation ---------------------------------------------------------------------------------

  config = {
    system.activationScripts.power.text =
      let
        body = concatLines (
          filter (s: s != "") (
            [
              cfg.universal.pmsetCommand
              cfg.ac.pmsetCommand
              cfg.battery.pmsetCommand
              cfg.ups.pmsetCommand
            ]
            ++ mkSystemsetupCommands {
              allowSleepByPowerButton = {
                flag = "-setallowpowerbuttontosleepcomputer";
                format = formatOnOff;
              };
            } cfg.universal
            ++ cfg.universal.autoRestart.systemsetupCommands
          )
        );
      in
      # Inherits `set -e` and `set -o pipefail` from the umbrella activation script
      # (see modules/system/activation-scripts.nix).
      mkIf (body != "") ''
        echo "configuring power..." >&2
        ${body}
      '';
  };

  meta.maintainers = [
    lib.maintainers.malo or "malo"
  ];
}
