{ lib, config, ... }:
let
  inherit (import ./keycodes.nix) modMasks keycodes;

  mkShortcut =
    {
      id,
      name,
      enabled ? true,
      mods ? [ ],
      key ? null,
    }:
    lib.mkOption {
      description = "${name} (Apple shortcut ID: ${toString id}).";
      default = { };
      type = lib.types.submodule {
        options = {
          id = lib.mkOption {
            type = lib.types.int;
            default = id;
            readOnly = true;
            description = "Apple shortcut ID.";
          };
          name = lib.mkOption {
            type = lib.types.str;
            default = name;
            readOnly = true;
            description = "Shortcut description.";
          };
          enabled = lib.mkOption {
            type = lib.types.bool;
            default = if cfg.disableAll then false else enabled;
            description = "Whether to enable '${name}'.";
          };
          key = lib.mkOption {
            type = lib.types.nullOr (lib.types.enum (builtins.attrNames keycodes));
            default = key;
            description = "Key for '${name}'.";
          };
          mods = lib.mkOption {
            type = lib.types.listOf (lib.types.enum (builtins.attrNames modMasks));
            default = mods;
            description = "Modifiers for '${name}'.";
          };
        };
      };
    };
  encodeShortcut =
    sc:
    let
      kc = if sc.key != null then keycodes.${sc.key} else null;
      modSum = builtins.foldl' (acc: mod: acc + modMasks.${mod}) 0 sc.mods;
      modsStr = if sc.mods == [ ] then "" else lib.concatStringsSep "+" sc.mods;
      enabledTag = if sc.key != null && sc.enabled then "<true/>" else "<false/>";
      enabledStr = if sc.key != null && sc.enabled then "enabled" else "disabled";
    in
    ''
      # ${sc.name} (${enabledStr}, ${modsStr}+${toString sc.key})
      defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add ${toString sc.id} "
        <dict>
          <key>enabled</key>
          ${enabledTag}
          ${
            if sc.key != null then
              ''
                <key>value</key>
                <dict>
                  <key>parameters</key>
                  <array>
                    <integer>${toString kc.ascii}</integer>
                    <integer>${toString kc.decimal}</integer>
                    <integer>${toString modSum}</integer>
                  </array>
                  <key>type</key>
                  <string>standard</string>
                </dict>
              ''
            else
              ""
          }
        </dict>"
    '';

  cfg = config.system.keyboard.shortcuts;
in
{
  options.system.keyboard.shortcuts = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable keyboard shortcut management.";
    };
    disableAll = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to disable all keyboard shortcuts, ignoring individual enabled settings.";
    };
    binds = (import ./defaults.nix) mkShortcut;
  };

  config = lib.mkIf cfg.enable {
    system.activationScripts.shortcuts.text =
      let
        allShortcuts = lib.concatLists (
          lib.mapAttrsToList (_: section: lib.mapAttrsToList (_: sc: encodeShortcut sc) section) cfg.binds
        );
      in
      lib.concatStringsSep "\n" allShortcuts
      + ''
        # Force a refresh
        # see https://zameermanji.com/blog/2021/6/8/applying-com-apple-symbolichotkeys-changes-instantaneously/
        /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
      '';

    system.activationScripts.postActivation.text = lib.mkAfter ''
      ${config.system.activationScripts.shortcuts.text}
    '';
  };
}
