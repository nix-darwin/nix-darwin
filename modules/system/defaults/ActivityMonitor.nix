{ config, lib, ... }:

with lib;

{
  options = {

    system.defaults.ActivityMonitor.ShowCategory = mkOption {
      type = types.nullOr (
        types.enum [
          100
          101
          102
          103
          104
          105
          106
          107
        ]
      );
      default = null;
      description = ''
        Change which processes to show.
        * 100: All Processes
        * 101: All Processes, Hierarchally
        * 102: My Processes
        * 103: System Processes
        * 104: Other User Processes
        * 105: Active Processes
        * 106: Inactive Processes
        * 107: Windowed Processes
        Default is 100.
      '';
    };

    system.defaults.ActivityMonitor.IconType = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = ''
        Change the icon in the dock when running.
        * 0: Application Icon
        * 2: Network Usage
        * 3: Disk Activity
        * 5: CPU Usage
        * 6: CPU History
        Default is null.
      '';
    };

    system.defaults.ActivityMonitor.SortColumn = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Which column to sort the main activity page (such as "CPUUsage"). Default is null.
      '';
    };

    system.defaults.ActivityMonitor.SortDirection = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = ''
        The sort direction of the sort column (0 is decending). Default is null.
      '';
    };

    system.defaults.ActivityMonitor.OpenMainWindow = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Open the main window when opening Activity Monitor. Default is true.
      '';
    };
  };
}
