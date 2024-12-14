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

  # Examples taken from https://github.com/Homebrew/homebrew-bundle
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
      restart_service = "changed";
    }
    {
      name = "mysql@5.6";
      restart_service = true;
      link = true;
      conflicts_with = [ "mysql" ];
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
  ];

  homebrew.masApps = {
    "1Password for Safari" = 1569813296;
    Xcode = 497799835;
  };

  homebrew.whalebrews = [
    "whalebrew/wget"
  ];

  homebrew.vscode = [
    "golang.go"
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
    ${mkTest "denji/nginx/nginx-full" ''brew "denji/nginx/nginx-full", args: ["with-rmtp"], restart_service: :changed''}
    ${mkTest "mysql@5.6" ''brew "mysql@5.6", conflicts_with: ["mysql"], link: true, restart_service: true''}

    echo "checking cask entries in Brewfile" >&2
    ${mkTest "google-chrome" ''cask "google-chrome"''}
    ${mkTest "firefox" ''cask "firefox", args: { appdir: "~/my-apps/Applications" }''}
    ${mkTest "opera" ''cask "opera", greedy: true''}

    echo "checking mas entries in Brewfile" >&2
    ${mkTest "1Password for Safari" ''mas "1Password for Safari", id: 1569813296''}
    ${mkTest "Xcode" ''mas "Xcode", id: 497799835''}

    echo "checking whalebrew entries in Brewfile" >&2
    ${mkTest "whalebrew/wget" ''whalebrew "whalebrew/wget"''}

    echo "checking vscode entries in Brewfile" >&2
    ${mkTest "golang.go" ''vscode "golang.go"''}
  '';
}
