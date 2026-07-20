{ config, lib, pkgs, ... }:
let
  cfg = config.system.wallpaper;

  types = lib.types;
in
{
  options = {
    system.wallpaper.enable = lib.mkEnableOption "wallpaper management";

    system.wallpaper.path = lib.mkOption {
      type = types.nullOr (types.path);
      default = null;
      example = ./foo/bar/image.png;
      description = ''
        Path to the desired image to be used.

        Can be a local file or can use pkgs.fetchUrl e.g.

        `
        wallpaper.path = pkgs.fetchurl {
          url = "https://misc-assets.raycast.com/wallpapers/loupe-mono-dark.heic";
          sha256 = "sha256-MwvRU7U4tO6F1duxBrHLOd7F5Gnzv/zyiZkm5EFqkY4=";
        };
        `

        Example is from https://github.com/birkhofflee
      '';
    };
  };

  # Original python method from https://github.com/TresChar/wallall/tree/main
  # Limitations: No filetype checking, shows incorrect data in system settings
  config = lib.mkIf cfg.enable {

    launchd.user.agents.wallpaper = {
      path = [ config.environment.systemPath ];
      serviceConfig.RunAtLoad = true;
      script = ''
set -e
plist_path="${config.system.primaryUserHome}/Library/Application Support/com.apple.wallpaper/Store/Index.plist"

plutil -replace "AllSpacesAndDisplays" -json '{}' "$plist_path"
plutil -replace "Displays" -json '{}' "$plist_path"
plutil -replace "Spaces" -json '{}' "$plist_path"

plutil -insert "AllSpacesAndDisplays.Desktop" -json '{"Content":{"Choices":[{"Configuration": "","Files":[],"Provider":"com.apple.wallpaper.choice.image"}],"EncodedOptionValues":"$null","Shuffle":"$null"},"LastSet":0,"LastUse":0}' "$plist_path"

date_string="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

plutil -replace "AllSpacesAndDisplays.Desktop.LastSet" -date "$date_string" "$plist_path"
plutil -replace "AllSpacesAndDisplays.Desktop.LastUse" -date "$date_string" "$plist_path"

plutil -replace "AllSpacesAndDisplays.Type" -string "desktop" "$plist_path"
plutil -replace "AllSpacesAndDisplays.Desktop.Content.Choices.0.Configuration" -data $(echo '{"type":"imageFile","url":{"relative":"file://${cfg.path}"}}' | plutil -convert binary1 - -o - | base64) "$plist_path"
killall WallpaperAgent || true
        '';
    };
    
  };
}
