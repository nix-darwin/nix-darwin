{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let

  cfg = config.time;

  timeZone = optionalString (cfg.timeZone != null) ''
    if ! systemsetup -listtimezones | grep -q "^ ${cfg.timeZone}$"; then
      echo "${cfg.timeZone} is not a valid timezone. The command 'listtimezones' will show a list of valid time zones." >&2
      false
    fi
    systemsetup -settimezone "${cfg.timeZone}" 2>/dev/null 1>&2
  '';

in

{
  options = {

    time.timeZone = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "America/New_York";
      description = ''
        The time zone used when displaying times and dates. See <https://en.wikipedia.org/wiki/List_of_tz_database_time_zones>
        or run {command}`sudo systemsetup -listtimezones`
        for a comprehensive list of possible values for this setting.
      '';
    };

  };

  config = {

    system.activationScripts.time.text = mkIf (cfg.timeZone != null) ''
      # Set defaults
      echo "configuring time..." >&2

      ${timeZone}
    '';

  };
}
