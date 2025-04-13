{ config, lib, pkgs, ... }:

let
  cfg = config.programs.jdks;
in

{
  meta.maintainers = [
    lib.maintainers.samasaur or "samasaur"
  ];

  options.programs.jdks = {
    installed = lib.mkOption {
      type = with lib.types; listOf package;
      default = [];
      example = lib.literalExpression
        ''
          [ pkgs.zulu8 pkgs.zulu11 pkgs.zulu17 ];
        '';
      description = ''
        JDKs to install systemwide.

        These JDKs will be symlinked into /Library/Java/JavaVirtualMachines
      '';
    };

    selected = lib.mkOption {
      type = with lib.types; nullOr package;
      default = null;
      example = lib.literalExpression
        ''
          pkgs.zulu11
        '';
      description = ''
        The JDK to set as active.

        Tools such as `java`, `javac`, etc. will use this JDK.

        It will not be added to the list of installed JDKs.
      '';
    };
  };

  config = {
    system.build.jdks = pkgs.runCommand "jdks"
      { preferLocalBuild = true; }
      ''
        mkdir -p $out/Library/Java/JavaVirtualMachines
        cd $out/Library/Java/JavaVirtualMachines
        ${lib.concatMapStringsSep "\n" (jdk: ''
          for jdk in ${jdk}/*.jdk; do
            ln -s "''${jdk}" "./''${jdk//\//_}"
          done
        '') cfg.installed}
      '';

    system.activationScripts.jdks.text = ''
      echo "linking JDKs..." >&2

      # link new JDKs
      ${lib.optionalString (cfg.installed != []) ''
        for _jdk in ${config.system.build.jdks}/Library/Java/JavaVirtualMachines/*.jdk; do
          # $_jdk is the full nix store path (because it reads symlinks?), so shorten it (to e.g. `zulu-8.jdk`)
          export jdk=$(basename "$_jdk")
          if ! diff "${config.system.build.jdks}/Library/Java/JavaVirtualMachines/''${jdk}" "/Library/Java/JavaVirtualMachines/''${jdk}" &> /dev/null; then
            # $jdk from the new system is different from the one with the same name in /Library/Java/JavaVirtualMachines
            if ! test -e "/Library/Java/JavaVirtualMachines/''${jdk}"; then
              # one with the same name as $jdk doesn't exist in /Library/Java/JavaVirtualMachines
              # do nothing
              true
            elif test -f "/Library/Java/JavaVirtualMachines/''${jdk}"; then
              echo "Preexisting JDK /Library/Java/JavaVirtualMachines/$jdk was manually installed; not overwriting..." >&2
              continue
            elif test -L "/Library/Java/JavaVirtualMachines/''${jdk}"; then
              echo "Preexisting JDK /Library/Java/JavaVirtualMachines/$jdk was manually linked into place; overwriting..." >&2
            fi
            # link $jdk into place, overwriting if necessary
            ln -sf "${config.system.build.jdks}/Library/Java/JavaVirtualMachines/''${jdk}" "/Library/Java/JavaVirtualMachines/''${jdk}"
          fi
        done
      ''}

      # remove installed JDKs that were from the previous system but aren't in the new system
      for _jdk in $(ls /run/current-system/Library/Java/JavaVirtualMachines 2> /dev/null); do
        # this is not actually necessary, but I'm doing it for consistency
        export jdk=$(basename "$_jdk")
        if test ! -e "${config.system.build.jdks}/Library/Java/JavaVirtualMachines/''${jdk}"; then
          # $jdk was in the old system config, but not the new system config
          if test -e "/Library/Java/JavaVirtualMachines/''${jdk}"; then
            # $jdk was linked into place; remove it
            echo "Removing old JDK ''${jdk}..." >&2
            rm -f "/Library/Java/JavaVirtualMachines/''${jdk}"
          fi
        fi
      done
    '';

    launchd.agents.java_home = lib.mkIf (cfg.selected != null) {
      script = ''
        export LC_ALL=C
        for jdk in ${cfg.selected}/*.jdk; do
          export JAVA_HOME="''${jdk}/Contents/Home"
          # ensure that this JDK is actually a macOS JDK bundle before using it
          if test -e "$JAVA_HOME"; then
            launchctl setenv JAVA_HOME "$JAVA_HOME"
            # break out of the loop so that we only set JAVA_HOME once, even if there are multiple JDKs in this derivation
            break
          fi
        done
      '';

      serviceConfig = {
        RunAtLoad = true;
      };
    };
  };
}
