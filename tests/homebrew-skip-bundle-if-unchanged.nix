{ config, lib, pkgs, ... }:

let
  skipBundleIfUnchangedRejects = homebrew:
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
              onActivation.skipBundleIfUnchanged = true;
            }
            homebrew;
        };
      };
    in
      !(builtins.tryEval evaluated.config.system.build.toplevel.drvPath).success;
  reconcile = pkgs.writeShellScript "homebrew-skip-bundle-if-unchanged" (
    config.homebrew.onActivation.skipBundleIfUnchangedCmd {
      stateDir = "homebrew-state";
      inventoryCmd = ''
        if test -e inventory-fail; then
          exit 1
        fi
        cat inventory
      '';
      bundleCmd = ''
        printf 'run\n' >> bundle-calls
        if test -e bundle-fail; then
          exit 1
        fi
      '';
    }
  );
in

{
  homebrew = {
    enable = true;
    user = "test-homebrew-user";
    taps = [ "homebrew/cask" ];
    brews = [ "imagemagick" ];
    casks = [ "firefox" ];
    masApps.Xcode = 497799835;
    onActivation.skipBundleIfUnchanged = true;
  };

  test = assert skipBundleIfUnchangedRejects { onActivation.upgrade = true; };
    assert skipBundleIfUnchangedRejects { extraConfig = ''brew "unsupported"''; };
    assert skipBundleIfUnchangedRejects { vscode = [ "golang.go" ]; };
    assert skipBundleIfUnchangedRejects { brews = [{ name = "mysql"; link = true; }]; };
    ''
      activate=${config.out}/activate
      bash -n "$activate"

    echo "checking reconciliation inventory" >&2
    grep -F 'brew tap > "$inventoryDir/taps"' "$activate"
    grep -F 'brew list --formula -1 > "$inventoryDir/formulae"' "$activate"
    grep -F 'brew list --cask -1 > "$inventoryDir/casks"' "$activate"
    grep -F 'mas list > "$inventoryDir/mas-with-versions"' "$activate"
    grep -F '{ print $1 }' "$activate"
    grep -F 'LC_ALL=C sort "$inventoryDir/formulae"' "$activate"

      echo "checking reconciliation state" >&2
      grep -F "homebrewStateDir=/var/db/nix-darwin/homebrew" "$activate"
      grep -F 'homebrewState="$homebrewStateDir/activation-state"' "$activate"
      grep -F 'cmp -s "$homebrewState" "$homebrewStateNext"' "$activate"
      grep -F 'mv -f "$homebrewStateNext" "$homebrewState"' "$activate"

      echo "checking reconciliation remains unchanged" >&2
      grep -F "brew bundle --file='" "$activate" | grep -F -- "--no-upgrade"

      echo "checking reconciliation behavior" >&2
      printf 'first\n' > inventory
      ${reconcile}
      test "$(wc -l < bundle-calls)" -eq 1

      ${reconcile}
      test "$(wc -l < bundle-calls)" -eq 1

      printf 'second\n' > inventory
      ${reconcile}
      test "$(wc -l < bundle-calls)" -eq 2
      grep -Fx 'second' homebrew-state/activation-state

      cp homebrew-state/activation-state expected-state
      touch inventory-fail
      if ${reconcile}; then
        echo "expected inventory failure" >&2
        exit 1
      fi
      rm inventory-fail
      test "$(wc -l < bundle-calls)" -eq 2
      cmp expected-state homebrew-state/activation-state
      test -z "$(find homebrew-state -name '.activation-state.*' -print)"

      printf 'third\n' > inventory
      touch bundle-fail
      if ${reconcile}; then
        echo "expected bundle failure" >&2
        exit 1
      fi
      rm bundle-fail
      test "$(wc -l < bundle-calls)" -eq 3
      cmp expected-state homebrew-state/activation-state
      test -z "$(find homebrew-state -name '.activation-state.*' -print)"

      ${reconcile}
      test "$(wc -l < bundle-calls)" -eq 4
      grep -Fx 'third' homebrew-state/activation-state
    '';
}
