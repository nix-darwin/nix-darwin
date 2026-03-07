{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.system;
in

{
  options = {

    system.patches = mkOption {
      type = types.listOf types.path;
      default = [ ];
      example = literalExpression ''
        [
          (pkgs.writeText "bashrc.patch" ''''
            --- a/etc/bashrc
            +++ b/etc/bashrc
            @@ -8,3 +8,5 @@
             shopt -s checkwinsize

             [ -r "/etc/bashrc_$TERM_PROGRAM" ] && . "/etc/bashrc_$TERM_PROGRAM"
            +
            +if test -e /etc/static/bashrc; then . /etc/static/bashrc; fi
          '''')
        ]
      '';
      description = ''
        Set of patches to apply to {file}`/`.

        ::: {.warning}

        This can modify everything so use with caution.

        :::

        Useful for safely changing system files.  Unlike the etc module this
        won't remove or modify files with unexpected content.
      '';
    };

  };

  config = {

    system.build.patches = pkgs.runCommand "patches" { preferLocalBuild = true; } ''
      mkdir -p $out/patches
      cd $out/patches
      ${concatMapStringsSep "\n" (f: "ln -s '${f}' $(basename '${f}')") cfg.patches}
    '';

    system.activationScripts.patches.text = ''
      # Applying patches to /.
      echo "applying patches..." >&2

      for f in /run/current-system/patches/*; do
        [[ -e "$f" ]] || break  # handle when directory is empty
        f=''${f#/run/current-system/patches/}

        if [[ ! -e "${config.system.build.patches}/patches/$f" ]]; then
          patch --force --reverse --backup -d / -p1 < "/run/current-system/patches/$f" || true
        fi
      done

      ${concatMapStringsSep "\n" (f: ''
        f="$(basename ${f})"
        if ! patch --force --reverse --dry-run -d / -p1 < '${f}' &> /dev/null; then
            patch --forward --backup -d / -p1 < '${f}' || true
        fi
      '') cfg.patches}
    '';

  };
}
