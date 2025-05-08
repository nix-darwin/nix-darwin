{ config, lib, pkgs, ... }:

with lib;

let

  text = import ../lib/write-text.nix {
    inherit lib;
    mkTextDerivation = name: text: pkgs.writeText "etc-${name}" text;
  };

  etc = filter (f: f.enable) (attrValues config.environment.etc);

in

{
  options = {

    environment.etc = mkOption {
      type = types.attrsOf (types.submodule text);
      default = { };
      description = ''
        Set of files that have to be linked in {file}`/etc`.
      '';
    };

  };

  config = {

    system.build.etc = pkgs.runCommand "etc"
      { preferLocalBuild = true; }
      ''
        mkdir -p $out/etc
        cd $out/etc
        ${concatMapStringsSep "\n" (attr: ''
          mkdir -p "$(dirname ${escapeShellArg attr.target})"
          ln -s ${escapeShellArgs [ attr.source attr.target ]}
        '') etc}
      '';

    system.activationScripts.checks.text = mkAfter ''
      declare -A etcSha256Hashes=(
        ${concatMapStringsSep "\n  "
          (attr:
            "[${escapeShellArg attr.target}]=" +
            escapeShellArg (concatStringsSep " " attr.knownSha256Hashes))
          etc}
      )

      declare -a etcProblems=()

      while IFS= read -r -d "" configFile; do
        subPath=''${configFile#"$systemConfig"/etc/}
        etcStaticFile=/etc/static/$subPath
        etcFile=/etc/$subPath

        # We need to check files that exist and aren't already links to
        # $etcStaticFile for known hashes.
        if [[
          -e $etcFile
          && $(readlink "$etcFile") != "$etcStaticFile"
        ]]; then
          # Only check hashes of paths that resolve to regular files;
          # everything else (e.g. directories) we complain about
          # unconditionally.
          if [[ -f $(readlink -f "$etcFile") ]]; then
            etcFileSha256Output=$(shasum -a 256 "$etcFile")
            etcFileSha256Hash=''${etcFileSha256Output%% *}
            for knownSha256Hash in ''${etcSha256Hashes[$subPath]}; do
              if [[ $etcFileSha256Hash == "$knownSha256Hash" ]]; then
                # Hash matches, OK to overwrite; go to the next file.
                continue 2
              fi
            done
          fi
          etcProblems+=("$etcFile")
        fi
      done < <(find -H "$systemConfig/etc" -type l -print0)

      if (( ''${#etcProblems[@]} )); then
        printf >&2 '\x1B[1;31merror: Unexpected files in /etc, aborting '
        printf >&2 'activation\x1B[0m\n'
        printf >&2 'The following files have unrecognized content and would be '
        printf >&2 'overwritten:\n\n'
        printf >&2 '  %s\n' "''${etcProblems[@]}"
        printf >&2 '\nPlease check there is nothing critical in these files, '
        printf >&2 'rename them by adding .before-nix-darwin to the end, and '
        printf >&2 'then try again.\n'
        exit 2
      fi
    '';

    system.activationScripts.etc.text = ''
      # Set up the statically computed bits of /etc.
      printf >&2 'setting up /etc...\n'

      ln -sfn "$(readlink -f "$systemConfig/etc")" /etc/static

      while IFS= read -r -d "" etcStaticFile; do
        etcFile=/etc/''${etcStaticFile#/etc/static/}
        etcDir=''${etcFile%/*}

        if [[ ! -d $etcDir ]]; then
          mkdir -p "$etcDir"
        fi

        if [[ -e $etcFile ]]; then
          if [[ $(readlink -- "$etcFile") == "$etcStaticFile" ]]; then
            continue
          else
            mv "$etcFile" "$etcFile.before-nix-darwin"
          fi
        fi

        ln -s "$etcStaticFile" "$etcFile"
      done < <(find -H /etc/static -type l -print0)

      while IFS= read -r -d "" etcFile; do
        etcStaticFile=/etc/static/''${etcFile#/etc/}

        # Delete stale links into /etc/static.
        if [[
          $(readlink -- "$etcFile") == "$etcStaticFile"
          && ! -e $etcStaticFile
        ]]; then
          rm "$etcFile"
        fi
      done < <(find -H /etc -type l -print0)
    '';

  };
}
