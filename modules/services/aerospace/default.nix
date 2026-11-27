{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.aerospace;

  # The new composable `if = "test …"` syntax — and the soft-deprecation of the
  # legacy `if.*` syntax — were introduced in AeroSpace 0.21.0
  # (https://github.com/nikitabobko/AeroSpace/releases/tag/v0.21.0-Beta). On
  # older versions the legacy syntax is the only supported form, so the
  # deprecation warning and the `null` default for `on-window-detected.*.if`
  # only apply from 0.21.0 on.
  aerospaceVersion = lib.getVersion cfg.package;
  newSyntaxSupported =
    aerospaceVersion != "" && lib.versionAtLeast aerospaceVersion "0.21.0";

  format = pkgs.formats.toml { };
  filterAttrsRecursive = pred: set:
    lib.listToAttrs (
      lib.concatMap (
        name: let
          v = set.${name};
        in
          if pred v
          then [
            (lib.nameValuePair name (
              if lib.isAttrs v
              then filterAttrsRecursive pred v
              else if lib.isList v
              then
                (map (i:
                  if lib.isAttrs i
                  then filterAttrsRecursive pred i
                  else i) (lib.filter pred v))
              else v
            ))
          ]
          else []
      ) (lib.attrNames set)
    );
  filterNulls = filterAttrsRecursive (v: v != null);
  configFile = format.generate "aerospace.toml" (filterNulls cfg.settings);
in

{
  options = {
    services.aerospace = with lib.types; {
      enable = lib.mkEnableOption "AeroSpace window manager";

      package = lib.mkPackageOption pkgs "aerospace" { };

      settings = lib.mkOption {
        type = submodule {
          freeformType = format.type;
          options = {
            start-at-login = lib.mkOption {
              type = bool;
              default = false;
              description = "Do not start AeroSpace at login. (Managed by launchd instead)";
            };
            after-login-command = lib.mkOption {
              type = listOf str;
              default = [ ];
              description = "Do not use AeroSpace to run commands after login. (Managed by launchd instead)";
            };
            after-startup-command = lib.mkOption {
              type = listOf str;
              default = [ ];
              description = "Add commands that run after AeroSpace startup";
              example = [ "layout tiles" ];
            };
            enable-normalization-flatten-containers = lib.mkOption {
              type = bool;
              default = true;
              description = "Containers that have only one child are \"flattened\".";
            };
            enable-normalization-opposite-orientation-for-nested-containers = lib.mkOption {
              type = bool;
              default = true;
              description = "Containers that nest into each other must have opposite orientations.";
            };
            accordion-padding = lib.mkOption {
              type = int;
              default = 30;
              description = "Padding between windows in an accordion container.";
            };
            default-root-container-layout = lib.mkOption {
              type = enum [
                "tiles"
                "accordion"
              ];
              default = "tiles";
              description = "Default layout for the root container.";
            };
            default-root-container-orientation = lib.mkOption {
              type = enum [
                "horizontal"
                "vertical"
                "auto"
              ];
              default = "auto";
              description = "Default orientation for the root container.";
            };
            on-window-detected = lib.mkOption {
              type = listOf (submodule {
                options = {
                  "if" = lib.mkOption {
                    type = nullOr (oneOf [
                      # The recommended form (version >= 0.21.0-Beta)
                      str
                      # The legacy attribute-set form (`if.*` keys)
                      (submodule {
                        options = {
                          app-id = lib.mkOption {
                            type = nullOr str;
                            default = null;
                            description = "The application ID to match (optional).";
                          };
                          workspace = lib.mkOption {
                            type = nullOr str;
                            default = null;
                            description = "The workspace name to match (optional).";
                          };
                          window-title-regex-substring = lib.mkOption {
                            type = nullOr str;
                            default = null;
                            description = "Substring to match in the window title (optional).";
                          };
                          app-name-regex-substring = lib.mkOption {
                            type = nullOr str;
                            default = null;
                            description = "Regex substring to match the app name (optional).";
                          };
                          during-aerospace-startup = lib.mkOption {
                            type = nullOr bool;
                            default = null;
                            description = "Whether to match during aerospace startup (optional).";
                          };
                        };
                      })
                    ]);
                    # On >= 0.21.0 an empty/missing `if` is rejected by AeroSpace,
                    # so default to `null` (filtered out → no `if` key) there.
                    # Older versions keep the historical `{}` default.
                    default = if newSyntaxSupported then null else { };
                    example = ''test %{app-bundle-id} = com.apple.systempreferences'';
                    description = ''
                      Condition that a detected window must match for the commands to run.

                      The recommended form is a command string, for example
                      `"test %{app-bundle-id} = com.apple.systempreferences"`. See
                      <link xlink:href="https://nikitabobko.github.io/AeroSpace/guide#on-window-detected-callback"/>
                      for details.

                      The legacy attribute-set form is still supported but
                      soft-deprecated by AeroSpace; using it emits a warning. See
                      <link xlink:href="https://nikitabobko.github.io/AeroSpace/guide#legacy-on-window-detected-syntax"/>.
                    '';
                  };
                  check-further-callbacks = lib.mkOption {
                    type = nullOr bool;
                    default = null;
                    description = "Whether to check further callbacks after this rule (optional).";
                  };
                  run = lib.mkOption {
                    type = oneOf [str (listOf str)];
                    example = ["move-node-to-workspace m" "resize-node"];
                    description = "Commands to execute when the conditions match (required).";
                  };
                };
              });
              default = [ ];
              example = [
                {
                  "if" = ''test %{app-bundle-id} = com.apple.systempreferences'';
                  check-further-callbacks = false;
                  run = ["move-node-to-workspace m" "resize-node"];
                }
              ];
              description = "Commands to run every time a new window is detected with optional conditions.";
            };
            workspace-to-monitor-force-assignment = lib.mkOption {
              type = attrsOf (oneOf [int str (listOf str)]);
              default = { };
              description = ''
                Map workspaces to specific monitors.
                Left-hand side is the workspace name, and right-hand side is the monitor pattern.
              '';
              example = {
                "1" = 1; # First monitor from left to right.
                "2" = "main"; # Main monitor.
                "3" = "secondary"; # Secondary monitor (non-main).
                "4" = "built-in"; # Built-in display.
                "5" = "^built-in retina display$"; # Regex for the built-in retina display.
                "6" = ["secondary" "dell"]; # Match first pattern in the list.
              };
            };
            on-focus-changed = lib.mkOption {
              type = listOf str;
              default = [ ];
              description = "Commands to run every time focused window or workspace changes.";
            };
            on-focused-monitor-changed = lib.mkOption {
              type = listOf str;
              default = [ "move-mouse monitor-lazy-center" ];
              description = "Commands to run every time focused monitor changes.";
            };
            exec-on-workspace-change = lib.mkOption {
              type = listOf str;
              default = [ ];
              example = [
                "/bin/bash"
                "-c"
                "sketchybar --trigger aerospace_workspace_change FOCUSED=$AEROSPACE_FOCUSED_WORKSPACE"
              ];
              description = "Commands to run every time workspace changes.";
            };
            key-mapping.preset = lib.mkOption {
              type = enum [
                "qwerty"
                "dvorak"
                "colemak"
              ];
              default = "qwerty";
              description = "Keymapping preset.";
            };
          };
        };
        default = { };
        example = lib.literalExpression ''
          {
            gaps = {
              outer.left = 8;
              outer.bottom = 8;
              outer.top = 8;
              outer.right = 8;
            };
            mode.main.binding = {
              alt-h = "focus left";
              alt-j = "focus down";
              alt-k = "focus up";
              alt-l = "focus right";
            };
          }
        '';
        description = ''
          AeroSpace configuration, see
          <link xlink:href="https://nikitabobko.github.io/AeroSpace/guide#configuring-aerospace"/>
          for supported values.
        '';
      };
    };
  };

  config = (
    lib.mkIf (cfg.enable) {
      warnings =
        let
          # The legacy attribute-set form is in use iff any rule's `if` is an
          # attrset (the string form is the modern one, and `null` is an omitted
          # condition). Gated by `newSyntaxSupported` (see the top-level `let`)
          # so that on AeroSpace < 0.21.0 — where the legacy syntax is the only
          # option — no warning is emitted.
          legacyIfUsed = lib.any (rule: builtins.isAttrs rule."if")
            cfg.settings.on-window-detected;
        in
        lib.optional (newSyntaxSupported && legacyIfUsed) ''
          The `if.*` condition syntax in `services.aerospace.settings.on-window-detected` (e.g. `if.app-id`, `if.workspace`, `if.window-title-regex-substring`, `if.app-name-regex-substring`, `if.during-aerospace-startup`) is soft-deprecated by AeroSpace (since 0.21.0). It still works, but prefer the string form, e.g. `if = "test %{app-bundle-id} = com.apple.systempreferences"`. See https://nikitabobko.github.io/AeroSpace/guide#legacy-on-window-detected-syntax'';
      assertions = [
        {
          assertion = !cfg.settings.start-at-login;
          message = "AeroSpace started at login is managed by home-manager and launchd instead of itself via this option.";
        }
        {
          assertion = cfg.settings.after-login-command == [ ];
          message = "AeroSpace will not run these commands as it does not start itself.";
        }
      ];
      environment.systemPackages = [ cfg.package ];

      launchd.user.agents.aerospace = {
        command =
          "${cfg.package}/Applications/AeroSpace.app/Contents/MacOS/AeroSpace"
          + (lib.optionalString (cfg.settings != { }) " --config-path ${configFile}");
        serviceConfig = {
          KeepAlive = true;
          RunAtLoad = true;
        };
        managedBy = "services.aerospace.enable";
      };
    }
  );
}
