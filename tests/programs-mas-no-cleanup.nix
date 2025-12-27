{
  config,
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
    cleanup = false;
    packages = {
      Xcode = 497799835;
    };
  };

  homebrew.masApps = {
    "KeepFromHomebrew" = 424242;
  };

  test = ''
    echo "checking mas present in systemPackages" >&2
    test -x ${config.out}/sw/bin/mas

    echo "checking mas activation script still installs and updates apps" >&2
    grep 'desiredIds=(' ${config.out}/activate
    grep '497799835' ${config.out}/activate
    grep 'mas install \"$appId\"' ${config.out}/activate
    grep 'mas update' ${config.out}/activate

    echo "checking cleanup-only variables are omitted" >&2
    if grep 'declare -A installedApps' ${config.out}/activate; then
      echo "unexpected installedApps declaration when cleanup is disabled" >&2
      exit 1
    fi

    if grep 'keepIds=(' ${config.out}/activate; then
      echo "unexpected keepIds declaration when cleanup is disabled" >&2
      exit 1
    fi
  '';
}
