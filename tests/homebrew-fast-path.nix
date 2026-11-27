{ config, lib, pkgs, ... }:

let
  fastPathRejects = homebrew:
    let
      evaluated = import ../. {
        inherit pkgs;
        nixpkgs = config.nixpkgs.source;
        system = pkgs.stdenv.hostPlatform.system;
        configuration = {
          system.stateVersion = 6;
          system.primaryUser = "test-homebrew-user";
          homebrew = lib.recursiveUpdate
            {
              enable = true;
              onActivation.fastPath = true;
            }
            homebrew;
        };
      };
    in
      !(builtins.tryEval evaluated.config.system.build.toplevel.drvPath).success;
in

{
  homebrew = {
    enable = true;
    user = "test-homebrew-user";
    taps = [ "homebrew/cask" ];
    brews = [ "imagemagick" ];
    casks = [ "firefox" ];
    masApps.Xcode = 497799835;
    onActivation.fastPath = true;
  };

  test = assert fastPathRejects { onActivation.upgrade = true; };
    assert fastPathRejects { extraConfig = ''brew "unsupported"''; };
    assert fastPathRejects { vscode = [ "golang.go" ]; };
    assert fastPathRejects { brews = [{ name = "mysql"; link = true; }]; };
    ''
      activate=${config.out}/activate
      bash -n "$activate"

    echo "checking fast path inventory" >&2
    grep -F 'brew tap > "$inventoryDir/taps"' "$activate"
    grep -F 'brew list --formula -1 > "$inventoryDir/formulae"' "$activate"
    grep -F 'brew list --cask -1 > "$inventoryDir/casks"' "$activate"
    grep -F 'mas list > "$inventoryDir/mas"' "$activate"
    grep -F 'LC_ALL=C sort "$inventoryDir/formulae"' "$activate"

      echo "checking fast path cache" >&2
      grep -F "homebrewStateDir=/var/db/nix-darwin/homebrew" "$activate"
      grep -F 'homebrewState="$homebrewStateDir/activation-state"' "$activate"
      grep -F 'cmp -s "$homebrewState" "$homebrewStateNext"' "$activate"
      grep -F 'mv -f "$homebrewStateNext" "$homebrewState"' "$activate"

      echo "checking reconciliation remains unchanged" >&2
      grep -F "brew bundle --file='" "$activate" | grep -F -- "--no-upgrade"
    '';
}
