{ config, lib, pkgs, ... }:

with lib;

let
  # Similar to lib.escapeShellArg but escapes "s instead of 's, to allow for parameter expansion in shells
  escapeDoubleQuote = arg: ''"${replaceStrings ["\""] ["\"\\\"\""] (toString arg)}"'';

  cfg = config.system.checks;

  macOSVersion = ''
    IFS=. read -ra osVersion <<<"$(sw_vers -productVersion)"
    if (( osVersion[0] < 11 || (osVersion[0] == 11 && osVersion[1] < 3) )); then
      printf >&2 '\e[1;31merror: macOS version is less than 11.3, aborting activation\e[0m\n'
      printf >&2 'Nixpkgs 25.05 requires macOS Big Sur 11.3 or newer, and 25.11 will\n'
      printf >&2 'require macOS Sonoma 14.\n'
      printf >&2 '\n'
      printf >&2 'For more information on your options going forward, see the 25.05\n'
      printf >&2 'release notes:\n'
      printf >&2 '<https://nixos.org/manual/nixos/unstable/release-notes#sec-release-25.05>\n'
      printf >&2 '\n'
      printf >&2 'Nixpkgs 24.11 and nix-darwin 24.11 continue to support down to macOS\n'
      printf >&2 'Sierra 10.12, and will be supported through June 2025.\n'
      printf >&2 '\n'
      printf >&2 'You can override this check by setting:\n'
      printf >&2 '\n'
      printf >&2 '    system.checks.verifyMacOSVersion = false;\n'
      printf >&2 '\n'
      printf >&2 'However, we are unable to provide support if you do so.\n'
      exit 2
    fi
  '';

  primaryUser = ''
    # shellcheck disable=SC2209
    primaryUser=${escapeShellArg config.system.primaryUser}
    if ! id -- "$primaryUser" >/dev/null 2>&1; then
      printf >&2 '\e[1;31merror: primary user `%s` does not exist, aborting activation\e[0m\n' \
        "$primaryUser"
      printf >&2 'Please ensure that `system.primaryUser` is set to the name of an\n'
      printf >&2 'existing user. Usually this should be the user you have been using to\n'
      printf >&2 'run `darwin-rebuild`.\n'
      exit 2
    fi
  '';

  determinate = ''
    if [[ -e /usr/local/bin/determinate-nixd ]]; then
      printf >&2 '\e[1;31merror: Determinate detected, aborting activation\e[0m\n'
      printf >&2 'Determinate uses its own daemon to manage the Nix installation that\n'
      printf >&2 'conflicts with nix-darwin’s native Nix management.\n'
      printf >&2 '\n'
      printf >&2 'To turn off nix-darwin’s management of the Nix installation, set:\n'
      printf >&2 '\n'
      printf >&2 '    nix.enable = false;\n'
      printf >&2 '\n'
      printf >&2 'This will allow you to use nix-darwin with Determinate. Some nix-darwin\n'
      printf >&2 'functionality that relies on managing the Nix installation, like the\n'
      printf >&2 '`nix.*` options to adjust Nix settings or configure a Linux builder,\n'
      printf >&2 'will be unavailable.\n'
      exit 2
    fi
  '';

  preSequoiaBuildUsers = ''
    firstBuildUserID=$(dscl . -read /Users/_nixbld1 UniqueID | awk '{print $2}')
    if
      # Don’t complain when we’re about to migrate old‐style build users…
      [[ $firstBuildUserID != ${toString (config.ids.uids.nixbld + 1)} ]] \
      && ! dscl . -list /Users | grep -q '^nixbld'
    then
        printf >&2 '\e[1;31merror: Build users have unexpected UIDs, aborting activation\e[0m\n'
        printf >&2 'The default Nix build user ID range has been adjusted for\n'
        printf >&2 'compatibility with macOS Sequoia 15. Your _nixbld1 user currently has\n'
        printf >&2 'UID %d rather than the new default of 351.\n' "$firstBuildUserID"
        printf >&2 '\n'
        printf >&2 'You can automatically migrate the users with the following command:\n'
        printf >&2 '\n'
        if [[ -e /nix/receipt.json ]]; then
            if
                ${pkgs.jq}/bin/jq --exit-status \
                'try(.planner.settings | has("enable_flakes"))' \
                /nix/receipt.json \
                >/dev/null
            then
                installerUrl="https://install.lix.systems/lix"
            else
                installerUrl="https://install.determinate.systems/nix"
            fi
            printf >&2 "    curl --proto '=https' --tlsv1.2 -sSf -L %s | sh -s -- repair sequoia --move-existing-users\n" \
                "$installerUrl"
        else
            printf >&2 "    curl --proto '=https' --tlsv1.2 -sSf -L https://github.com/NixOS/nix/raw/master/scripts/sequoia-nixbld-user-migration.sh | bash -\n"
        fi
        printf >&2 '\n'
        printf >&2 'If you have no intention of upgrading to macOS Sequoia 15, or already\n'
        printf >&2 'have a custom UID range that you know is compatible with Sequoia, you\n'
        printf >&2 'can disable this check by setting:\n'
        printf >&2 '\n'
        printf >&2 '    ids.uids.nixbld = %d;\n' "$((firstBuildUserID - 1))"
        printf >&2 '\n'
        exit 2
    fi
  '';

  buildGroupID = ''
    buildGroupID=$(dscl . -read /Groups/nixbld PrimaryGroupID | awk '{print $2}')
    expectedBuildGroupID=${toString config.ids.gids.nixbld}
    if [[ $buildGroupID != "$expectedBuildGroupID" ]]; then
        printf >&2 '\e[1;31merror: Build user group has mismatching GID, aborting activation\e[0m\n'
        printf >&2 'The default Nix build user group ID was changed from 30000 to 350.\n'
        printf >&2 'You are currently managing Nix build users with nix-darwin, but your\n'
        printf >&2 'nixbld group has GID %d, whereas we expected %d.\n' \
          "$buildGroupID" "$expectedBuildGroupID"
        printf >&2 '\n'
        printf >&2 'Possible causes include setting up a new Nix installation with an\n'
        printf >&2 'existing nix-darwin configuration, setting up a new nix-darwin\n'
        printf >&2 'installation with an existing Nix installation, or manually increasing\n'
        printf >&2 'your `system.stateVersion` setting.\n'
        printf >&2 '\n'
        printf >&2 'You can set the configured group ID to match the actual value:\n'
        printf >&2 '\n'
        printf >&2 '    ids.gids.nixbld = %d;\n' "$buildGroupID"
        printf >&2 '\n'
        printf >&2 'We do not recommend trying to change the group ID with macOS user\n'
        printf >&2 'management tools without a complete uninstallation and reinstallation\n'
        printf >&2 'of Nix.\n'
        exit 2
    fi
  '';

  nixDaemon = ''
    if [[ "$(stat --format='%u' /nix)" != 0 ]]; then
      printf >&2 '[1;31merror: single‐user install detected, aborting activation[0m\n'
      printf >&2 'nix-darwin now only supports managing multi‐user daemon installations\n'
      printf >&2 'of Nix. You can uninstall nix-darwin and Nix and then reinstall both to\n'
      printf >&2 'fix this.\n'
      printf >&2 '\n'
      printf >&2 'If you don’t want to do that, you can disable management of the Nix\n'
      printf >&2 'installation with:\n'
      printf >&2 '\n'
      printf >&2 '    nix.enable = false;\n'
      printf >&2 '\n'
      printf >&2 'See the `nix.enable` option documentation for caveats.\n'
      exit 2
    fi
  '';

  nixInstaller = ''
    if grep -q 'etc/profile.d/nix-daemon.sh' /etc/profile; then
        echo "[1;31merror: Found nix-daemon.sh reference in /etc/profile, aborting activation[0m" >&2
        echo "This will override options like nix.nixPath because it runs later," >&2
        echo "remove this snippet from /etc/profile:" >&2
        echo >&2
        echo "    # Nix" >&2
        echo "    if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then" >&2
        echo "      . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'" >&2
        echo "    fi" >&2
        echo "    # End Nix" >&2
        echo >&2
        exit 2
    fi
  '';

  nixPath = ''
    findPathEntry() {
      NIX_PATH=${concatMapStringsSep ":" escapeDoubleQuote config.nix.nixPath} \
        nix-instantiate --find-file "$@" >/dev/null
    }

    if ! findPathEntry darwin-config; then
      printf >&2 '\e[1;31merror: can’t find `<darwin-config>`, aborting activation\e[0m\n'
      printf >&2 'Make sure that %s exists,\n' \
        ${escapeDoubleQuote (
          if config.environment.darwinConfig == null then
            "the \\`<darwin-config>\\` entry in \\`nix.nixPath\\`"
          else
            "\\`${config.environment.darwinConfig}\\`"
        )}
      printf >&2 'or else set `environment.darwinConfig` to the correct path to your\n'
      printf >&2 '`configuration.nix` file.\n'
      printf >&2 '\n'
      printf >&2 'The setting should not reference `$HOME`, as `root` now needs to be\n'
      printf >&2 'able to find your configuration. If you previously used `$HOME` in\n'
      printf >&2 'your `environment.darwinConfig` path, please replace it with the\n'
      printf >&2 'full path to your home directory.\n'
      exit 2
    fi

    checkChannel() {
      if findPathEntry "$1"; then
        return
      fi

      printf >&2 '\e[1;31merror: can’t find `<%s>`, aborting activation\e[0m\n' \
        "$1"
      printf >&2 'The most likely reason for this is that the channel is owned\n'
      printf >&2 'by your user. This no longer works now that nix-darwin has moved over\n'
      printf >&2 'to `root`‐based activation.\n'
      printf >&2 '\n'
      printf >&2 'You can check your current channels with:\n'
      printf >&2 '\n'
      printf >&2 '    $ sudo nix-channel --list\n'
      printf >&2 '    nixpkgs https://nixos.org/channels/NIXPKGS-BRANCH\n'
      printf >&2 '    darwin https://github.com/nix-darwin/nix-darwin/archive/NIX-DARWIN-BRANCH.tar.gz\n'
      printf >&2 '    …\n'
      printf >&2 '    $ nix-channel --list\n'
      printf >&2 '    …\n'
      printf >&2 '\n'
      printf >&2 'You should see `darwin` and `nixpkgs` in `sudo nix-channel --list`.\n'
      printf >&2 'If `darwin` or `nixpkgs` are present in `nix-channel --list` (without\n'
      printf >&2 '`sudo`), you should delete them with `nix-channel --remove NAME`.\n'
      printf >&2 '\n'
      printf >&2 'You can then fix your channels like this:\n'
      printf >&2 '\n'
      printf >&2 '    $ sudo nix-channel --add https://nixos.org/channels/NIXPKGS-BRANCH nixpkgs\n'
      printf >&2 '    $ sudo nix-channel --add https://github.com/nix-darwin/nix-darwin/archive/NIX-DARWIN-BRANCH.tar.gz darwin\n'
      printf >&2 '    $ sudo nix-channel --update\n'
      printf >&2 '\n'
      printf >&2 'After that, activating your system again should work correctly. If it\n'
      printf >&2 'doesn’t, please open an issue at\n'
      printf >&2 '<https://github.com/nix-darwin/nix-darwin/issues/new> and include as much\n'
      printf >&2 'information as possible.\n'
      exit 2
    }

    checkChannel nixpkgs

    checkChannel darwin
  '';

  # TODO: Remove this a couple years down the line when we can assume
  # that anyone who cares about security has upgraded.
  oldSshAuthorizedKeysDirectory = ''
    if [[ -d /etc/ssh/authorized_keys.d ]]; then
        printf >&2 '\e[1;31merror: /etc/ssh/authorized_keys.d exists, aborting activation\e[0m\n'
        printf >&2 'SECURITY NOTICE: The previous implementation of the\n'
        printf >&2 '`users.users.<name>.openssh.authorizedKeys.*` options would not delete\n'
        printf >&2 'authorized keys files when the setting for a given user was removed.\n'
        printf >&2 '\n'
        printf >&2 "This means that if you previously stopped managing a user's authorized\n"
        printf >&2 'SSH keys with nix-darwin, or intended to revoke their access by\n'
        printf >&2 'removing the option, the previous set of keys could still be used to\n'
        printf >&2 'log in as that user.\n'
        printf >&2 '\n'
        printf >&2 'You can check the /etc/ssh/authorized_keys.d directory to see which\n'
        printf >&2 'keys were permitted; afterwards, please remove the directory and\n'
        printf >&2 're-run activation. The options continue to be supported and will now\n'
        printf >&2 'correctly permit only the keys in your current system configuration.\n'
        exit 2
    fi
  '';

  homebrewInstalled = ''
    if [[ ! -f ${escapeShellArg config.homebrew.prefix}/bin/brew && -z "''${INSTALLING_HOMEBREW:-}" ]]; then
        echo "[1;31merror: Using the homebrew module requires homebrew installed, aborting activation[0m" >&2
        echo "Homebrew doesn't seem to be installed. Please install homebrew separately." >&2
        echo "You can install homebrew using the following command:" >&2
        echo >&2
        echo '    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' >&2
        echo >&2
        exit 2
    fi
  '';

  # Some Mac devices, notably laptops, do not support automatic restart after power failure.
  restartAfterPowerFailureIsSupported = ''
    if /usr/sbin/systemsetup -getrestartpowerfailure 2>&1 | grep -q "Not supported"; then
       printf >&2 "\e[1;31merror: restart after power failure not supported on this Mac, aborting activation\e[0m\n"
       printf >&2 "Please remove \`power.universal.autoRestart.afterPowerFailure\` and/or\n"
       printf >&2 "\`power.universal.autoRestart.afterPowerFailureDelay\` from your configuration.\n"
       exit 2
    fi
  '';

  # `power.universal.autoRestart.onPowerConnect` (pmset `autorestartatconnect`) is gated by Apple
  # to macOS Tahoe 26.5+ AND specific desktop Mac models (Mac mini 2024+, Mac Studio 2025+, or iMac
  # 2024+). We probe macOS version and battery presence as a conservative-but-imperfect signal; we
  # can't easily validate the exact Mac model from a check script, so an older Apple Silicon desktop
  # on Tahoe 26.5+ would pass this check and have the write silently no-op.
  # See https://support.apple.com/en-us/125517.
  restartOnPowerConnectIsSupported = ''
    macosVersion=$(/usr/bin/sw_vers -productVersion)
    IFS=. read -r macosMajor macosMinor _ <<< "$macosVersion"
    if (( macosMajor < 26 || (macosMajor == 26 && macosMinor < 5) )); then
       printf >&2 "\e[1;31merror: \`onPowerConnect\` requires macOS 26.5 or later, aborting activation\e[0m\n"
       printf >&2 '(have %s)\n' "$macosVersion"
       printf >&2 "See https://support.apple.com/en-us/125517 for the full hardware/OS matrix.\n"
       printf >&2 "Please remove \`power.universal.autoRestart.onPowerConnect\` from your\n"
       printf >&2 "configuration.\n"
       exit 2
    fi
    if /usr/sbin/ioreg -rn AppleSmartBattery | grep -q AppleSmartBattery; then
       printf >&2 "\e[1;31merror: \`onPowerConnect\` is desktop-only but a battery was detected, aborting activation\e[0m\n"
       printf >&2 "Supported only on Mac mini 2024+, Mac Studio 2025+, or iMac 2024+.\n"
       printf >&2 "Please remove \`power.universal.autoRestart.onPowerConnect\` from your\n"
       printf >&2 "configuration.\n"
       exit 2
    fi
  '';

  # High Power Mode is only available on certain MacBook Pro models with M1 Max and later high-end
  # chips, plus the Mac mini (2024) with M4 Pro. See https://support.apple.com/en-us/101613.
  highPowerModeIsSupported = ''
    if ! /usr/bin/pmset -g cap | grep -qw highpowermode; then
       printf >&2 "\e[1;31merror: High Power Mode not supported on this Mac, aborting activation\e[0m\n"
       printf >&2 "See Apple's supported models: https://support.apple.com/en-us/101613\n"
       printf >&2 "Please change or remove \`power.<source>.powerMode = \"high\"\` in your\n"
       printf >&2 "configuration.\n"
       exit 2
    fi
  '';

  # Low Power Mode is supported on most modern Apple Silicon Macs, but not all (notably absent on
  # some older Intel Macs). See https://support.apple.com/en-us/101613.
  lowPowerModeIsSupported = ''
    if ! /usr/bin/pmset -g cap | grep -qw lowpowermode; then
       printf >&2 "\e[1;31merror: Low Power Mode not supported on this Mac, aborting activation\e[0m\n"
       printf >&2 "See Apple's supported models: https://support.apple.com/en-us/101613\n"
       printf >&2 "Please change or remove \`power.<source>.powerMode = \"low\"\` in your\n"
       printf >&2 "configuration.\n"
       exit 2
    fi
  '';

  # `powerMode = "automatic"` means "macOS chooses dynamically among available power modes."
  # On hardware with neither Low Power Mode nor High Power Mode in `pmset -g cap`, there are no
  # modes for macOS to choose from, so `automatic` is degenerate. See
  # https://support.apple.com/en-us/101613.
  automaticPowerModeIsMeaningful = ''
    if ! /usr/bin/pmset -g cap | grep -qwE 'lowpowermode|highpowermode'; then
       printf >&2 "\e[1;31merror: no Power Mode features available on this Mac, aborting activation\e[0m\n"
       printf >&2 "Neither Low Power Mode nor High Power Mode is supported by this hardware,\n"
       printf >&2 "so \`powerMode\` is a no-op. See Apple's supported models:\n"
       printf >&2 "https://support.apple.com/en-us/101613\n"
       printf >&2 "Please remove \`power.<source>.powerMode\` from your configuration.\n"
       exit 2
    fi
  '';

  # `power.battery.*` writes go to the "Battery Power" dict, which macOS only reads when a battery
  # is present. On a desktop (or any Mac without a battery) those settings silently fail to apply.
  # We probe for the AppleSmartBattery IOKit class as the hardware-presence signal.
  batteryIsPresent = ''
    if ! /usr/sbin/ioreg -rn AppleSmartBattery | grep -q AppleSmartBattery; then
       printf >&2 "\e[1;31merror: \`power.battery.*\` options are set but no battery was detected, aborting activation\e[0m\n"
       printf >&2 "Run \`ioreg -rn AppleSmartBattery\` to verify hardware detection. These settings\n"
       printf >&2 "won't take effect on this Mac. Please remove these options from your\n"
       printf >&2 "configuration, or move them to \`power.universal\` / \`power.ac\`.\n"
       exit 2
    fi
  '';

  # `power.ups.*` writes go to the "UPS Power" dict, which macOS only reads when a UPS is connected
  # and recognized. Without one those settings silently fail to apply. We probe for the
  # IOUPSDevice IOKit class as the hardware-presence signal.
  upsIsPresent = ''
    if ! /usr/sbin/ioreg -rn IOUPSDevice | grep -q IOUPSDevice; then
       printf >&2 "\e[1;31merror: \`power.ups.*\` options are set but no UPS was detected, aborting activation\e[0m\n"
       printf >&2 "Run \`ioreg -rn IOUPSDevice\` to verify hardware detection. These settings won't\n"
       printf >&2 "take effect on this Mac. Please remove these options from your configuration,\n"
       printf >&2 "or move them to \`power.universal\` / \`power.ac\`.\n"
       exit 2
    fi
  '';

  powerSources = with config.power; [ universal ac battery ups ];
  anyPowerMode = mode: any (s: s.powerMode == mode) powerSources;

in

{
  imports = [
    (mkRemovedOptionModule [ "system" "checks" "verifyNixChannels" ] "This check has been removed.")
  ];

  options = {
    system.checks.verifyNixPath = mkOption {
      type = types.bool;
      default = config.nix.enable;
      description = "Whether to run the NIX_PATH validation checks.";
    };

    system.checks.verifyBuildUsers = mkOption {
      type = types.bool;
      default =
        config.nix.enable && !(config.nix.settings.auto-allocate-uids or false);
      description = "Whether to run the Nix build users validation checks.";
    };

    system.checks.verifyMacOSVersion = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to run the macOS version check.";
    };

    system.checks.text = mkOption {
      internal = true;
      type = types.lines;
      default = "";
    };
  };

  config = {

    system.checks.text = mkMerge [
      (mkIf cfg.verifyMacOSVersion macOSVersion)
      (mkIf (config.system.primaryUser != null) primaryUser)
      (mkIf config.nix.enable determinate)
      (mkIf cfg.verifyBuildUsers preSequoiaBuildUsers)
      (mkIf cfg.verifyBuildUsers buildGroupID)
      (mkIf config.nix.enable nixDaemon)
      nixInstaller
      (mkIf cfg.verifyNixPath nixPath)
      oldSshAuthorizedKeysDirectory
      (mkIf config.homebrew.enable homebrewInstalled)
      (mkIf (config.power.universal.autoRestart.afterPowerFailure != null
        || config.power.universal.autoRestart.afterPowerFailureDelay != null)
        restartAfterPowerFailureIsSupported)
      (mkIf (config.power.universal.autoRestart.onPowerConnect != null)
        restartOnPowerConnectIsSupported)
      (mkIf (anyPowerMode "high") highPowerModeIsSupported)
      (mkIf (anyPowerMode "low") lowPowerModeIsSupported)
      (mkIf (anyPowerMode "automatic") automaticPowerModeIsMeaningful)
      (mkIf (config.power.battery.pmsetEntries != { }) batteryIsPresent)
      (mkIf (config.power.ups.pmsetEntries != { }) upsIsPresent)
    ];

    system.activationScripts.checks.text = ''
      ${cfg.text}

      if [[ "''${checkActivation:-0}" -eq 1 ]]; then
        echo "ok" >&2
        exit 0
      fi
    '';

  };
}
