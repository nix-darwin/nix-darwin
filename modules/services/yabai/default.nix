{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;

  cfg = config.services.yabai;

  toYabaiConfig =
    opts:
    lib.concatStringsSep "\n" (lib.mapAttrsToList (p: v: "yabai -m config ${p} ${toString v}") opts);

  configFile =
    lib.mkIf (cfg.config != { } || cfg.extraConfig != "")
      "${pkgs.writeScript "yabairc" (
        (if (cfg.config != { }) then "${toYabaiConfig cfg.config}" else "")
        + lib.optionalString (cfg.extraConfig != "") ("\n" + cfg.extraConfig + "\n")
      )}";
in
{
  options.services.yabai = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable the yabai window manager.";
    };

    package = mkOption {
      type = types.path;
      default = pkgs.yabai;
      description = "The yabai package to use.";
    };

    enableScriptingAddition = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable yabai's scripting-addition.
        SIP must be disabled for this to work.
      '';
    };

    config = mkOption {
      type = types.attrs;
      default = { };
      example = lib.literalExpression ''
        {
          focus_follows_mouse = "autoraise";
          mouse_follows_focus = "off";
          window_placement    = "second_child";
          window_opacity      = "off";
          top_padding         = 36;
          bottom_padding      = 10;
          left_padding        = 10;
          right_padding       = 10;
          window_gap          = 10;
        }
      '';
      description = ''
        Key/Value pairs to pass to yabai's 'config' domain, via the configuration file.
      '';
    };

    extraConfig = mkOption {
      type = types.lines;
      default = "";
      example = lib.literalExpression ''
        yabai -m rule --add app='System Preferences' manage=off
      '';
      description = "Extra arbitrary configuration to append to the configuration file";
    };

    errorLogFile = mkOption {
      type = types.path;
      default = "/tmp/yabai.err.log";
      example = "/Users/khaneliman/Library/Logs/yabai.log";
      description = "Path to the yabai error log file";
    };

    outLogFile = mkOption {
      type = types.path;
      default = "/tmp/yabai.out.log";
      example = "/Users/khaneliman/Library/Logs/yabai.log";
      description = "Path to the yabai stdout log file";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.enable) {
      environment.systemPackages = [ cfg.package ];

      launchd.user.agents.yabai = {
        serviceConfig = {
          ProgramArguments =
            [ "${cfg.package}/bin/yabai" ]
            ++ lib.optionals (cfg.config != { } || cfg.extraConfig != "") [
              "-c"
              configFile
            ];
          KeepAlive = true;
          RunAtLoad = true;
          EnvironmentVariables = {
            PATH = "${cfg.package}/bin:${config.environment.systemPath}";
          };
          StandardOutPath = cfg.outLogFile;
          StandardErrorPath = cfg.errorLogFile;
        };
      };
    })

    # TODO: [@cmacrae] Handle removal of yabai scripting additions
    (lib.mkIf (cfg.enableScriptingAddition) {
      launchd.daemons.yabai-sa = {
        script = "${cfg.package}/bin/yabai --load-sa";
        serviceConfig = {
          RunAtLoad = true;
          KeepAlive.SuccessfulExit = false;
          StandardOutPath = "/var/log/yabai-sa.out.log";
          StandardErrorPath = "/var/log/yabai-sa.err.log";
        };
      };

      environment.etc."sudoers.d/yabai".source = pkgs.runCommand "sudoers-yabai" { } ''
        YABAI_BIN="${cfg.package}/bin/yabai"
        SHASUM=$(sha256sum "$YABAI_BIN" | cut -d' ' -f1)
        cat <<EOF >"$out"
        %admin ALL=(root) NOPASSWD: sha256:$SHASUM $YABAI_BIN --load-sa
        EOF
      '';
    })
  ];
}
