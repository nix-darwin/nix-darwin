{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.yabai;

  toYabaiConfig = opts:
    concatStringsSep "\n" (mapAttrsToList
      (p: v: "yabai -m config ${p} ${toString v}")
      opts);

  configFile = mkIf (cfg.config != { } || cfg.extraConfig != "")
    "${pkgs.writeScript "yabairc" (
      (if (cfg.config != {})
       then "${toYabaiConfig cfg.config}"
       else "")
      + optionalString (cfg.extraConfig != "") ("\n" + cfg.extraConfig + "\n"))}";
in

{
  options = with types; {
    services.yabai.enable = mkOption {
      type = bool;
      default = false;
      description = "Whether to enable the yabai window manager.";
    };

    services.yabai.package = mkOption {
      type = path;
      default = pkgs.yabai;
      description = "The yabai package to use.";
    };

    services.yabai.enableScriptingAddition = mkOption {
      type = bool;
      default = false;
      description = ''
        Whether to enable yabai's scripting-addition.
        SIP must be disabled for this to work.
      '';
    };

    services.yabai.config = mkOption {
      type = attrs;
      default = { };
      example = literalExpression ''
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

    services.yabai.extraConfig = mkOption {
      type = lines;
      default = "";
      example = literalExpression ''
        yabai -m rule --add app='System Preferences' manage=off
      '';
      description = "Extra arbitrary configuration to append to the configuration file";
    };
  };

  config = mkMerge [
    (mkIf (cfg.enable) {
      environment.systemPackages = [ cfg.package ];

      launchd.user.agents.yabai = {
        serviceConfig.ProgramArguments = [ "${cfg.package}/bin/yabai" ]
          ++ optionals (cfg.config != { } || cfg.extraConfig != "") [ "-c" configFile ];

        serviceConfig.KeepAlive = true;
        serviceConfig.RunAtLoad = true;
        serviceConfig.EnvironmentVariables = {
          PATH = "${cfg.package}/bin:${config.environment.systemPath}";
        };

        managedBy = "services.yabai.enable";
      };
    })

    # TODO: [@cmacrae] Handle removal of yabai scripting additions
    (mkIf (cfg.enableScriptingAddition) {
      launchd.daemons.yabai-sa = {
        script = "${cfg.package}/bin/yabai --load-sa";
        serviceConfig.RunAtLoad = true;
        serviceConfig.KeepAlive.SuccessfulExit = false;
      };

      environment.etc."sudoers.d/yabai".source = pkgs.runCommand "sudoers-yabai" {} ''
        YABAI_BIN="${cfg.package}/bin/yabai"
        SHASUM=$(sha256sum "$YABAI_BIN" | cut -d' ' -f1)
        cat <<EOF >"$out"
        %admin ALL=(root) NOPASSWD: sha256:$SHASUM $YABAI_BIN --load-sa
        EOF
      '';
    })
  ];
}
