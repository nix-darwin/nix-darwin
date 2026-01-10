{ lib, ... }:

with lib;

{
  options = {

    system.defaults.screencapture.location = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
          The filesystem path to which screencaptures should be written.
        '';
    };

    system.defaults.screencapture.type = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
          The image format to use, such as "jpg".
        '';
    };

    system.defaults.screencapture.disable-shadow = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
          Disable drop shadow border around screencaptures. The default is false.
        '';
    };

    system.defaults.screencapture.include-date = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Include date and time in screenshot filenames. The default is true.
        Screenshot 2024-01-09 at 13.27.20.png would be an example for true.
        
        Screenshot.png
        Screenshot 1.png would be an example for false.
      '';
    };

    system.defaults.screencapture.save-selections = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Remember the selection window of the last screencapture. The default is true.
      '';
    };

    system.defaults.screencapture.show-thumbnail = mkOption {
      type = types.nullOr types.bool;
      default = null;
      description = ''
        Show thumbnail after screencapture before writing to file. The default is true.
      '';
    };

    system.defaults.screencapture.target = mkOption {
      type = types.nullOr (types.enum [ "file" "clipboard" "preview" "mail" "messages" ]);
      default = null;
      description = ''
        Target to which screencapture should save screenshot to. The default is "file".
        Valid values include:

        * `file`: Saves as a file in location specified by `system.defaults.screencapture.location`
        * `clipboard`: Saves screenshot to clipboard
        * `preview`: Opens screenshot in Preview app
        * `mail`
        * `messages`
      '';
    };
  };
}
