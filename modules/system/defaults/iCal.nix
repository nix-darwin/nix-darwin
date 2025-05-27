{ lib, ... }:

{
  options = {
    system.defaults.iCal."first day of week" = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [
        "System Setting"
        "Sunday"
        "Monday"
        "Tuesday"
        "Wednesday"
        "Thursday"
        "Friday"
        "Saturday"
      ]);
      apply = key: if key == null then null else {
        "System Setting" = 0;
        "Sunday" = 1;
        "Monday" = 2;
        "Tuesday" = 3;
        "Wednesday" = 4;
        "Thursday" = 5;
        "Friday" = 6;
        "Saturday" = 7;
      }.${key};
      default = null;
      description = ''
        Set the day to start week on in the Calendar. The default is "System Setting".

        System Setting means inherit the value from Language & Region.
      '';
    };

    system.defaults.iCal.CalendarSidebarShown = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Show calendar list. The default is false.

        This requires restarting `Calendar.app` to show.
      '';
    };

    system.defaults.iCal."TimeZone support enabled" = lib.mkOption {
      type = lib.types.nullOr lib.types.bool;
      default = null;
      description = ''
        Turn on time zone support. The default is false.
      '';
    };
  };
}
