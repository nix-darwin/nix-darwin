{ config, lib, pkgs, ... }:

with lib;

let

  inherit (pkgs) stdenvNoCC;

  cfg = config.system;

  failedAssertions = map (x: x.message) (filter (x: !x.assertion) config.assertions);

  throwAssertions = res: if (failedAssertions != []) then throw "\nFailed assertions:\n${concatStringsSep "\n" (map (x: "- ${x}") failedAssertions)}" else res;
  showWarnings = res: foldr (w: x: builtins.trace "[1;31mwarning: ${w}[0m" x) res config.warnings;

in

{
  options = {

    system.build = mkOption {
      internal = true;
      type = types.lazyAttrsOf types.unspecified;
      default = {};
      description = ''
        Attribute set of derivation used to setup the system.
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

      # This is for compatibility with older `darwin-rebuild`s and
      # third‐party deployment tools.
      #
      # TODO: Remove this in 25.11.
      activationUserScript = ''
        #! ${pkgs.stdenv.shell}
        # nix-darwin: deprecated

        # Hack to handle upgrades.
        if
          [[ -e /run/current-system/activate-user ]] \
          && ! grep -q '^# nix-darwin: deprecated$' \
            /run/current-system/activate-user
        then
          exit
        fi

        printf >&2 '\e[1;31mwarning: `activate-user` is deprecated and will be removed in 25.11\e[0m\n'
        printf >&2 'This is usually due to the use of a non‐standard activation/deployment\n'
        printf >&2 'tool. If you maintain one of these tools, our advice is:\n'
        printf >&2 '\n'
        printf >&2 '  You can identify a post‐user‐activation configuration by the absence\n'
        printf >&2 '  of `activate-user` or the second line of the script being\n'
        printf >&2 '  `# nix-darwin: deprecated`.\n'
        printf >&2 '\n'
        printf >&2 '  We recommend running `$systemConfig/sw/bin/darwin-rebuild activate`\n'
        printf >&2 '  to activate built configurations; for a pre‐user‐activation\n'
        printf >&2 '  configuration this should be run as a normal user, and for a\n'
        printf >&2 '  post‐user‐activation configuration it should be run as `root`.\n'
        printf >&2 '\n'
        printf >&2 '  If you can’t or don’t want to use `darwin-rebuild activate`, then you\n'
        printf >&2 '  should skip running `activate-user` for post‐user‐activation\n'
        printf >&2 '  configurations and continue running `activate` as `root`.\n'
        printf >&2 '\n'
        printf >&2 '  In 25.11, `darwin-rebuild` will stop running `activate-user` and this\n'
        printf >&2 '  transition script will be deleted; you should be able to safely\n'
        printf >&2 '  remove all related logic by then.\n'
        printf >&2 '\n'
        printf >&2 'Otherwise, you should report this to the deployment tool developers. If\n'
        printf >&2 'you don’t use a third‐party deployment tool, please open a bug report\n'
        printf >&2 'at <https://github.com/nix-darwin/nix-darwin/issues/new> and include as much\n'
        printf >&2 'detail about your setup as possible.\n'
      '';

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
