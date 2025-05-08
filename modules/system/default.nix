{ config, lib, pkgs, ... }:

with lib;

let

  inherit (pkgs) stdenvNoCC;

  cfg = config.system;

  failedAssertions = map (x: x.message) (filter (x: !x.assertion) config.assertions);

  throwAssertions = res: if (failedAssertions != []) then throw "\nFailed assertions:\n${concatStringsSep "\n" (map (x: "- ${x}") failedAssertions)}" else res;
  showWarnings = res: fold (w: x: builtins.trace "[1;31mwarning: ${w}[0m" x) res config.warnings;

in

{
  options = {

    system.build = mkOption {
      internal = true;
      type = types.attrsOf types.unspecified;
      default = {};
      description = ''
        Attribute set of derivation used to setup the system.
      '';
    };

    system.path = mkOption {
      internal = true;
      type = types.package;
      description = ''
        The packages you want in the system environment.
      '';
    };

    system.profile = mkOption {
      type = types.path;
      default = "/nix/var/nix/profiles/system";
      description = ''
        Profile to use for the system.
      '';
    };

    system.systemBuilderCommands = mkOption {
      internal = true;
      type = types.lines;
      default = "";
      description = ''
        This code will be added to the builder creating the system store path.
      '';
    };

    system.systemBuilderArgs = mkOption {
      internal = true;
      type = types.attrsOf types.unspecified;
      default = {};
      description = ''
        `lib.mkDerivation` attributes that will be passed to the top level system builder.
      '';
    };

    assertions = mkOption {
      type = types.listOf types.unspecified;
      internal = true;
      default = [];
      example = [ { assertion = false; message = "you can't enable this for that reason"; } ];
      description = ''
        This option allows modules to express conditions that must
        hold for the evaluation of the system configuration to
        succeed, along with associated error messages for the user.
      '';
    };

    warnings = mkOption {
      internal = true;
      default = [];
      type = types.listOf types.str;
      example = [ "The `foo' service is deprecated and will go away soon!" ];
      description = ''
        This option allows modules to show warnings to users during
        the evaluation of the system configuration.
      '';
    };

  };

  config = {

    system.build.toplevel = throwAssertions (showWarnings (stdenvNoCC.mkDerivation ({
      name = "darwin-system-${cfg.darwinLabel}";
      preferLocalBuild = true;

      nativeBuildInputs = [ pkgs.shellcheck ];

      activationScript = cfg.activationScripts.script.text;
      activationUserScript = cfg.activationScripts.userScript.text;
      inherit (cfg) darwinLabel;

      darwinVersionJson = (pkgs.formats.json {}).generate "darwin-version.json" (
        filterAttrs (k: v: v != null) {
          inherit (config.system) darwinRevision nixpkgsRevision configurationRevision darwinLabel;
        }
      );

      buildCommand = ''
        mkdir $out

        systemConfig=$out

        mkdir -p $out/darwin
        cp -f ${../../CHANGELOG} $out/darwin-changes

        ln -s ${cfg.build.patches}/patches $out/patches
        ln -s ${cfg.build.etc}/etc $out/etc
        ln -s ${cfg.build.files} $out/links.json
        ln -s ${cfg.path} $out/sw

        mkdir -p $out/Library
        ln -s ${cfg.build.applications}/Applications $out/Applications
        ln -s ${cfg.build.fonts}/Library/Fonts $out/Library/Fonts
        ln -s ${cfg.build.launchd}/Library/LaunchAgents $out/Library/LaunchAgents
        ln -s ${cfg.build.launchd}/Library/LaunchDaemons $out/Library/LaunchDaemons

        mkdir -p $out/user/Library
        ln -s ${cfg.build.launchd}/user/Library/LaunchAgents $out/user/Library/LaunchAgents

        echo "$activationScript" > $out/activate
        substituteInPlace $out/activate --subst-var out
        chmod u+x $out/activate
        unset activationScript

        echo "$activationUserScript" > $out/activate-user
        substituteInPlace $out/activate-user --subst-var out
        chmod u+x $out/activate-user
        unset activationUserScript

        # We exclude the warnings for `…` in single‐quote strings and
        # non‐ASCII quotation marks as they are noisy and lead to a lot
        # of false positives in our user‐facing output:
        shellcheck --exclude=SC2016,SC1112 $out/activate $out/activate-user

        echo -n "$systemConfig" > $out/systemConfig

        echo -n "$darwinLabel" > $out/darwin-version
        ln -s $darwinVersionJson $out/darwin-version.json
        echo -n "$system" > $out/system

        ${cfg.systemBuilderCommands}
      '';
    } // cfg.systemBuilderArgs)));

  };
}
