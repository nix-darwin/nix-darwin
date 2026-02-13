{
  config,
  lib,
  options,
  pkgs,
  ...
}:

let
  inherit (lib)
    attrValues
    concatStringsSep
    escapeShellArg
    getExe
    literalExpression
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    mkOptionDefault
    mkPackageOption
    optionalString
    types
    ;

  cfg = config.programs.mas;

  apps = mapAttrsToList (name: id: { inherit name id; }) cfg.packages;

  desiredIds = map (app: toString app.id) apps;
  homebrewIds = map toString (attrValues config.homebrew.masApps);

  hasWork = cfg.update || cfg.packages != { } || cfg.cleanup || homebrewIds != [ ];

  activationScript =
    if hasWork then
      ''
        echo >&2 "setting up App Store apps (mas)..."

        runAsUser() {
          sudo \
            --preserve-env=PATH \
            --set-home \
            --user=${escapeShellArg cfg.user} \
            "$@"
        }

        listStatus=0
        listOutput=$(
          runAsUser ${getExe cfg.package} list 2>&1
        ) || listStatus=$?

        if (( listStatus != 0 )); then
          echo >&2 "warning: mas list failed (exit ''${listStatus}):"
          echo >&2 "''${listOutput}"
          if echo "''${listOutput}" | grep -qi "not signed in"; then
            echo >&2 "login required; skipping App Store installs/updates/cleanup"
            exit 0
          fi
        fi

        # Parse mas list output: "ID  AppName  (version)"
        declare -A installedApps
        installedIds=()
        while IFS= read -r line; do
          [[ -z "$line" ]] && continue
          line="''${line#"''${line%%[![:space:]]*}"}"
          id="''${line%% *}"
          rest="''${line#"$id"}"
          rest="''${rest#"''${rest%%[![:space:]]*}"}"
          name="''${rest% (*}"
          name="''${name%"''${name##*[![:space:]]}"}"
          [[ -n "$id" ]] && {
            installedIds+=( "$id" )
            installedApps["$id"]="$name"
          }
        done <<<"$listOutput"

        ${optionalString cfg.update ''
          runAsUser ${getExe cfg.package} update || true
        ''}

        desiredIds=(
          ${concatStringsSep "\n          " desiredIds}
        )

        homebrewIds=(
          ${concatStringsSep "\n          " homebrewIds}
        )

        keepIds=( "''${desiredIds[@]}" "''${homebrewIds[@]}" )

        is_installed() {
          local needle=$1
          for id in "''${installedIds[@]}"; do
            if [[ "$id" == "$needle" ]]; then
              return 0
            fi
          done
          return 1
        }

        ${optionalString (cfg.packages != { }) ''
          for appId in "''${desiredIds[@]}"; do
            if is_installed "$appId"; then
              continue
            fi
            runAsUser ${getExe cfg.package} install "$appId" || true
          done
        ''}

        ${optionalString cfg.cleanup ''
          for installedId in "''${installedIds[@]}"; do
            keep=false
            for keepId in "''${keepIds[@]}"; do
              if [[ "$installedId" == "$keepId" ]]; then
                keep=true
                break
              fi
            done

            if ! $keep; then
              appName="''${installedApps[$installedId]:-$installedId}"
              echo >&2 "removing $appName from App Store"
              runAsUser ${getExe cfg.package} uninstall "$installedId" || true
            fi
          done
        ''}
      ''
    else
      "";
in
{
  options.programs.mas = {
    enable = mkEnableOption "managing Mac App Store apps with mas";

    user = mkOption {
      type = types.str;
      default = config.system.primaryUser;
      defaultText = literalExpression "config.system.primaryUser";
      description = ''
        The user account that runs {command}`mas`. This user must be signed into the Mac App Store
        for installs or updates to succeed.
      '';
    };

    package = mkPackageOption pkgs "mas" { };

    packages = mkOption {
      type = types.attrsOf types.ints.positive;
      default = { };
      example = literalExpression ''
        {
          Xcode = 497799835;
          "1Password for Safari" = 1569813296;
        }
      '';
      description = ''
        Applications to install from the Mac App Store. Attribute names are only for readability;
        values must be the numeric identifiers used by {command}`mas`.
      '';
    };

    update = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to run {command}`mas update` during system activation in addition to installing the
        configured apps.
      '';
    };

    cleanup = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to uninstall Mac App Store apps that are currently installed but not listed in
        {option}`programs.mas.packages`. Apps listed in {option}`homebrew.masApps` are also preserved.
        This runs before install/update; any app id not in either set will be removed.
      '';
    };
  };

  config = {
    system.requiresPrimaryUser =
      mkIf (cfg.enable && options.programs.mas.user.highestPrio == (mkOptionDefault { }).priority)
        [
          "programs.mas.enable"
        ];

    environment.systemPackages = mkIf cfg.enable [ cfg.package ];

    system.activationScripts.mas.text = mkIf cfg.enable activationScript;
  };
}
