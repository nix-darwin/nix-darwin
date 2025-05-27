{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.system;

  text = import ../lib/write-text.nix {
    inherit lib;
    mkTextDerivation = pkgs.writeText;
  };

  launchdVariables = prefix: mapAttrsToList (name: value: ''
    ${prefix} launchctl setenv ${name} '${value}'
  '');

  launchdActivation = basedir: target: ''
    if ! diff '${cfg.build.launchd}/Library/${basedir}/${target}' '/Library/${basedir}/${target}' &> /dev/null; then
      if test -f '/Library/${basedir}/${target}'; then
        echo "reloading service $(basename ${target} .plist)" >&2
        launchctl unload '/Library/${basedir}/${target}' || true
      else
        echo "creating service $(basename ${target} .plist)" >&2
      fi
      if test -L '/Library/${basedir}/${target}'; then
        rm '/Library/${basedir}/${target}'
      fi
      cp -f '${cfg.build.launchd}/Library/${basedir}/${target}' '/Library/${basedir}/${target}'
      launchctl load -w '/Library/${basedir}/${target}'
    fi
  '';

  userLaunchdActivation = target: let
    user = lib.escapeShellArg config.system.primaryUser;
  in ''
    if ! diff ${cfg.build.launchd}/user/Library/LaunchAgents/${target} ~${user}/Library/LaunchAgents/${target} &> /dev/null; then
      if test -f ~${user}/Library/LaunchAgents/${target}; then
        echo "reloading user service $(basename ${target} .plist)" >&2
        launchctl asuser "$(id -u -- ${user})" sudo --user=${user} -- launchctl unload ~${user}/Library/LaunchAgents/${target} || true
      else
        echo "creating user service $(basename ${target} .plist)" >&2
      fi
      if test -L ~${user}/Library/LaunchAgents/${target}; then
        sudo --user=${user} -- rm ~${user}/Library/LaunchAgents/${target}
      fi
      sudo --user=${user} -- cp -f '${cfg.build.launchd}/user/Library/LaunchAgents/${target}' ~${user}/Library/LaunchAgents/${target}
      launchctl asuser "$(id -u -- ${user})" sudo --user=${user} -- launchctl load -w ~${user}/Library/LaunchAgents/${target}
    fi
  '';

  launchAgents = filter (f: f.enable) (attrValues config.environment.launchAgents);
  launchDaemons = filter (f: f.enable) (attrValues config.environment.launchDaemons);
  userLaunchAgents = filter (f: f.enable) (attrValues config.environment.userLaunchAgents);

in

{
  options = {

    environment.launchAgents = mkOption {
      type = types.attrsOf (types.submodule text);
      default = { };
      description = ''
        Set of files that have to be linked in {file}`/Library/LaunchAgents`.
      '';
    };

    environment.launchDaemons = mkOption {
      type = types.attrsOf (types.submodule text);
      default = { };
      description = ''
        Set of files that have to be linked in {file}`/Library/LaunchDaemons`.
      '';
    };

    environment.userLaunchAgents = mkOption {
      type = types.attrsOf (types.submodule text);
      default = { };
      description = ''
        Set of files that have to be linked in {file}`~/Library/LaunchAgents`.
      '';
    };

  };

  config = {

    system.build.launchd = pkgs.runCommand "launchd"
      { preferLocalBuild = true; }
      ''
        mkdir -p $out/Library/LaunchAgents $out/Library/LaunchDaemons $out/user/Library/LaunchAgents
        cd $out/Library/LaunchAgents
        ${concatMapStringsSep "\n" (attr: "ln -s '${attr.source}' '${attr.target}'") launchAgents}
        cd $out/Library/LaunchDaemons
        ${concatMapStringsSep "\n" (attr: "ln -s '${attr.source}' '${attr.target}'") launchDaemons}
        cd $out/user/Library/LaunchAgents
        ${concatMapStringsSep "\n" (attr: "ln -s '${attr.source}' '${attr.target}'") userLaunchAgents}
      '';

    system.activationScripts.launchd.text = ''
      # Set up launchd services in /Library/LaunchAgents and /Library/LaunchDaemons
      echo "setting up launchd services..." >&2

      ${concatStringsSep "\n" (launchdVariables "" config.launchd.envVariables)}

      ${concatMapStringsSep "\n" (attr: launchdActivation "LaunchAgents" attr.target) launchAgents}
      ${concatMapStringsSep "\n" (attr: launchdActivation "LaunchDaemons" attr.target) launchDaemons}

      for f in /run/current-system/Library/LaunchAgents/*; do
        [[ -e "$f" ]] || break  # handle when directory is empty
        f=''${f#/run/current-system/Library/LaunchAgents/}

        if [[ ! -e "${cfg.build.launchd}/Library/LaunchAgents/$f" ]]; then
          echo "removing service $(basename "$f" .plist)" >&2
          launchctl unload "/Library/LaunchAgents/$f" || true
          if [[ -e "/Library/LaunchAgents/$f" ]]; then
            rm -f "/Library/LaunchAgents/$f"
          fi
        fi
      done

      for f in /run/current-system/Library/LaunchDaemons/*; do
        [[ -e "$f" ]] || break  # handle when directory is empty
        f=''${f#/run/current-system/Library/LaunchDaemons/}

        if [[ ! -e "${cfg.build.launchd}/Library/LaunchDaemons/$f" ]]; then
          echo "removing service $(basename "$f" .plist)" >&2
          launchctl unload "/Library/LaunchDaemons/$f" || true
          if [[ -e "/Library/LaunchDaemons/$f" ]]; then
            rm -f "/Library/LaunchDaemons/$f"
          fi
        fi
      done
    '';

    system.activationScripts.userLaunchd.text = let
      user = lib.escapeShellArg config.system.primaryUser;
    in mkIf (config.launchd.user.envVariables != { } || userLaunchAgents != [ ]) ''
      # Set up user launchd services in ~/Library/LaunchAgents
      echo "setting up user launchd services..."

      ${concatStringsSep "\n" (launchdVariables "sudo --user=${user} --" config.launchd.user.envVariables)}

      ${optionalString (builtins.length userLaunchAgents > 0) ''
      sudo --user=${user} -- mkdir -p ~${user}/Library/LaunchAgents
      ''}
      ${concatMapStringsSep "\n" (attr: userLaunchdActivation attr.target) userLaunchAgents}

      for f in /run/current-system/user/Library/LaunchAgents/*; do
        [[ -e "$f" ]] || break  # handle when directory is empty
        f=''${f#/run/current-system/user/Library/LaunchAgents/}

        if [[ ! -e "${cfg.build.launchd}/user/Library/LaunchAgents/$f" ]]; then
          echo "removing user service $(basename "$f" .plist)" >&2
          sudo --user=${user} -- launchctl unload ~${user}/Library/LaunchAgents/"$f" || true
          if [[ -e ~${user}/Library/LaunchAgents/"$f" ]]; then
            sudo --user=${user} -- rm -f ~${user}/Library/LaunchAgents/"$f"
          fi
        fi
      done
    '';

  };
}
