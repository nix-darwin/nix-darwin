{ config, lib, ... }:

let
  mkTest = filter: result: ''
    if ! echo "$bf" | grep -F '${filter}' | grep -F '${result}' > /dev/null; then
      echo Expected:
      echo '${result}'
      echo Actual:
      echo "$bf" | grep -F '${filter}'
      exit 1
    fi
  '';
in

{
  homebrew.enable = true;

  homebrew.user = "test-homebrew-user";

  # Examples adapted from https://docs.brew.sh/Brew-Bundle-and-Brewfile
  homebrew.taps = [
    "homebrew/cask"
    {
      name = "user/tap-repo1";
      clone_target = "https://user@bitbucket.org/user/homebrew-tap-repo1.git";
    }
    {
      name = "user/tap-repo2";
      clone_target = "https://user@bitbucket.org/user/homebrew-tap-repo2.git";
      force_auto_update = true;
    }
  ];

  homebrew.caskArgs = {
    appdir = "~/Applications";
    require_sha = true;
  };

  homebrew.brews = [
    "imagemagick"
    {
      name = "denji/nginx/nginx-full";
      args = [ "with-rmtp" ];
      link = "overwrite";
      restart_service = "always";
    }
    {
      name = "mysql@5.6";
      restart_service = true;
      link = true;
      conflicts_with = [ "mysql" ];
    }
    {
      name = "postgresql@16";
      postinstall = "\${HOMEBREW_PREFIX}/opt/postgresql@16/bin/postgres -D \${HOMEBREW_PREFIX}/var/postgresql@16";
    }
  ];

  homebrew.casks = [
    "google-chrome"
    {
      name = "firefox";
      args = { appdir = "~/my-apps/Applications"; };
    }
    {
      name = "opera";
      greedy = true;
    }
    {
      name = "google-cloud-sdk";
      postinstall = "\${HOMEBREW_PREFIX}/bin/gcloud components update";
    }
  ];

  homebrew.masApps = {
    "1Password for Safari" = 1569813296;
    Xcode = 497799835;
  };

  homebrew.vscode = [
    "golang.go"
  ];

  homebrew.goPackages = [
    "github.com/charmbracelet/crush"
  ];

  homebrew.cargoPackages = [
    "ripgrep"
  ];


  test = ''
    bf=${lib.escapeShellArg config.homebrew.brewfile}

    echo "checking tap entries in Brewfile" >&2
    ${mkTest "homebrew/cask" ''tap "homebrew/cask"''}
    ${mkTest "user/tap-repo1" ''tap "user/tap-repo1", "https://user@bitbucket.org/user/homebrew-tap-repo1.git"''}
    ${mkTest "user/tap-repo2" ''tap "user/tap-repo2", "https://user@bitbucket.org/user/homebrew-tap-repo2.git", force_auto_update: true''}

    echo "checking cask_args entry in Brewfile" >&2
    ${mkTest "cask_args" ''cask_args appdir: "~/Applications", require_sha: true''}

    echo "checking brew entries in Brewfile" >&2
    ${mkTest "imagemagick" ''brew "imagemagick"''}
    ${mkTest "denji/nginx/nginx-full" ''brew "denji/nginx/nginx-full", args: ["with-rmtp"], link: :overwrite, restart_service: :always''}
    ${mkTest "mysql@5.6" ''brew "mysql@5.6", conflicts_with: ["mysql"], link: true, restart_service: true''}
    ${mkTest "postgresql@16" ''brew "postgresql@16", postinstall: "''${HOMEBREW_PREFIX}/opt/postgresql@16/bin/postgres -D ''${HOMEBREW_PREFIX}/var/postgresql@16"''}

    echo "checking cask entries in Brewfile" >&2
    ${mkTest "google-chrome" ''cask "google-chrome"''}
    ${mkTest "firefox" ''cask "firefox", args: { appdir: "~/my-apps/Applications" }''}
    ${mkTest "opera" ''cask "opera", greedy: true''}
    ${mkTest "google-cloud-sdk" ''cask "google-cloud-sdk", postinstall: "''${HOMEBREW_PREFIX}/bin/gcloud components update"''}

    echo "checking mas entries in Brewfile" >&2
    ${mkTest "1Password for Safari" ''mas "1Password for Safari", id: 1569813296''}
    ${mkTest "Xcode" ''mas "Xcode", id: 497799835''}

    echo "checking vscode entries in Brewfile" >&2
    ${mkTest "golang.go" ''vscode "golang.go"''}

    echo "checking go entries in Brewfile" >&2
    ${mkTest "github.com/charmbracelet/crush" ''go "github.com/charmbracelet/crush"''}

    echo "checking cargo entries in Brewfile" >&2
    ${mkTest "ripgrep" ''cargo "ripgrep"''}

    echo "checking that shell integration is absent by default" >&2
    (! grep 'brew shellenv' ${config.out}/etc/zshrc)

    echo "checking that cleanup check is absent by default" >&2
    (! grep 'brew bundle cleanup --file=' ${config.out}/activate)
  '';
}
