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

  desiredIds = map (app: escapeShellArg app.id) apps;
  homebrewIds = map (id: escapeShellArg id) (attrValues config.homebrew.masApps);

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
        listErrFile=$(mktemp)
        listOutput=$(
          runAsUser ${getExe cfg.package} list --json 2>"$listErrFile"
        ) || listStatus=$?
        listErrors=$(<"$listErrFile")
        rm -f "$listErrFile"

        if (( listStatus != 0 )); then
          echo >&2 "warning: mas list failed (exit ''${listStatus}):"
          echo >&2 "''${listErrors}"
          if echo "''${listErrors}" | grep -qi "not signed in"; then
            echo >&2 "login required; skipping App Store installs/updates/cleanup"
            exit 0
          fi
        fi

        installedAdamIds=()
        installedBundleIds=()
        ${optionalString cfg.cleanup ''
          installedNames=()
        ''}
        while IFS=$'\t' read -r adamId bundleId${optionalString cfg.cleanup " name"}; do
          [[ -z "$adamId" && -z "$bundleId" ]] && continue
          installedAdamIds+=( "$adamId" )
          installedBundleIds+=( "$bundleId" )
          ${optionalString cfg.cleanup ''
            installedNames+=( "$name" )
          ''}
        done < <(
          printf '%s' "$listOutput" | sed 's/}{/}\n{/g' |
            ${getExe pkgs.jq} --raw-output -R \
              'fromjson? | select(type == "object") | [(.adamID // "" | tostring), .bundleID // ""${if cfg.cleanup then ", .name // \"\"" else ""}] | @tsv'
        )

        if (( ''${#installedAdamIds[@]} == 0 )) && [[ -n "$listOutput" ]]; then
          while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            line="''${line#"''${line%%[![:space:]]*}"}"
            adamId="''${line%% *}"
            rest="''${line#"$adamId"}"
            rest="''${rest#"''${rest%%[![:space:]]*}"}"
            ${optionalString cfg.cleanup ''
              name="''${rest% (*}"
              name="''${name%"''${name##*[![:space:]]}"}"
            ''}
            [[ -n "$adamId" ]] || continue
            installedAdamIds+=( "$adamId" )
            installedBundleIds+=( "" )
            ${optionalString cfg.cleanup ''
              installedNames+=( "$name" )
            ''}
          done <<<"$listOutput"
        fi

        ${optionalString cfg.update ''
          runAsUser ${getExe cfg.package} update || true
        ''}

        desiredIds=(
          ${concatStringsSep "\n          " desiredIds}
        )

        is_installed() {
          local needle=$1
          local i
          for (( i=0; i<''${#installedAdamIds[@]}; i++ )); do
            if [[ "''${installedAdamIds[$i]}" == "$needle" ||
                  "''${installedBundleIds[$i]}" == "$needle" ]]; then
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
            installStatus=0
            installOutput=$(
              runAsUser ${getExe cfg.package} install "$appId" 2>&1
            ) || installStatus=$?
            if [[ "$installOutput" =~ Warning:\ Already\ (installed|got) ]]; then
              continue
            fi
            if [[ -n "$installOutput" ]]; then
              echo >&2 "$installOutput"
            elif (( installStatus != 0 )); then
              echo >&2 "warning: mas install $appId failed (exit ''${installStatus})"
            fi
          done
        ''}

        ${optionalString cfg.cleanup ''
          homebrewIds=(
            ${concatStringsSep "\n            " homebrewIds}
          )

          keepIds=( "''${desiredIds[@]}" "''${homebrewIds[@]}" )

          for (( i=0; i<''${#installedAdamIds[@]}; i++ )); do
            adamId="''${installedAdamIds[$i]}"
            bundleId="''${installedBundleIds[$i]}"
            keep=false
            for keepId in "''${keepIds[@]}"; do
              if [[ "$adamId" == "$keepId" || "$bundleId" == "$keepId" ]]; then
                keep=true
                break
              fi
            done

            if ! $keep; then
              installedId="$adamId"
              [[ -n "$installedId" ]] || installedId="$bundleId"
              appName="''${installedNames[$i]:-$installedId}"
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
      type = types.attrsOf (types.either types.ints.positive types.str);
      default = { };
      example = literalExpression ''
        {
          Xcode = 497799835;
          "1Password for Safari" = 1569813296;
          Keynote = "com.apple.iWork.Keynote";
        }
      '';
      description = ''
        Applications to install from the Mac App Store. Attribute names are only for readability;
        values must be the numeric or bundle identifiers used by {command}`mas`.
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
