{ lib, ... }:

{
  options = {

    system.defaults.hitoolbox.AppleFnUsageType = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "Do Nothing"
          "Change Input Source"
          "Show Emoji & Symbols"
          "Start Dictation"
        ]
      );
      apply =
        key:
        if key == null then
          null
        else
          {
            "Do Nothing" = 0;
            "Change Input Source" = 1;
            "Show Emoji & Symbols" = 2;
            "Start Dictation" = 3;
          }
          .${key};
      default = null;
      description = ''
        Chooses what happens when you press the Fn key on the keyboard. A restart is required for
        this setting to take effect.

        The default is unset ("Show Emoji & Symbols").
      '';
    };

  };
}
