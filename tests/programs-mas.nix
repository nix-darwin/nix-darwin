{
  config,
  lib,
  pkgs,
  ...
}:

let
  mas =
    pkgs.runCommand "mas-0.0.0" { } ''
          mkdir -p $out/bin
          cat > $out/bin/mas <<'EOF'
      #!/usr/bin/env bash
      exit 0
      EOF
          chmod +x $out/bin/mas
    ''
    // {
      meta.mainProgram = "mas";
    };
in
{
  system.primaryUser = "primary-mas-user";

  programs.mas = {
    enable = true;
    user = "test-mas-user";
    package = mas;
    update = true;
    cleanup = true;
    packages = {
      "1Password for Safari" = 1569813296;
      Xcode = 497799835;
    };
  };

  homebrew.masApps = {
    "KeepFromHomebrew" = 424242;
  };

  test = ''
    echo "checking mas present in systemPackages" >&2
    test -x ${config.out}/sw/bin/mas

    echo "checking mas activation script uses requested user" >&2
    grep -- '--user=test-mas-user' ${config.out}/activate

    echo "checking mas desired ids are present" >&2
    grep 'desiredIds=(' ${config.out}/activate
    grep '1569813296' ${config.out}/activate
    grep '497799835' ${config.out}/activate

    echo "checking mas install loop exists" >&2
    grep 'mas install \"$appId\"' ${config.out}/activate

    echo "checking mas update is triggered" >&2
    grep 'mas update' ${config.out}/activate

    echo "checking mas parses installedApps from mas list" >&2
    grep 'declare -A installedApps' ${config.out}/activate
    grep 'installedApps\[' ${config.out}/activate

    echo "checking mas cleanup log and uninstall" >&2
    grep 'removing .* from App Store' ${config.out}/activate
    grep 'runAsUser .*/mas uninstall' ${config.out}/activate

    echo "checking homebrew.masApps ids are kept during cleanup" >&2
    grep 'homebrewIds=(' ${config.out}/activate
    grep '424242' ${config.out}/activate
  '';
}
