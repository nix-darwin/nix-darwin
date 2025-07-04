{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.fonts;
in

{
  imports = [
    (lib.mkRemovedOptionModule [
      "fonts"
      "enableFontDir"
    ] "No nix-darwin equivalent to this NixOS option. This is not required to install fonts.")
    (lib.mkRemovedOptionModule [
      "fonts"
      "fontDir"
      "enable"
    ] "No nix-darwin equivalent to this NixOS option. This is not required to install fonts.")
    (lib.mkRemovedOptionModule [ "fonts" "fonts" ]
      ''
        This option has been renamed to `fonts.packages' for consistency with NixOS.

        Note that the implementation now keeps fonts in `/Library/Fonts/Nix Fonts' to allow them to coexist with fonts not managed by nix-darwin; existing fonts will be left directly in `/Library/Fonts' without getting updates and should be manually removed.''
    )
  ];

  options = {
    fonts.packages = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      example = lib.literalExpression "[ pkgs.dejavu_fonts ]";
      description = ''
        List of fonts to install into {file}`/Library/Fonts/Nix Fonts`.
      '';
    };
  };

  config = {

    system.build.fonts = pkgs.runCommand "fonts" { preferLocalBuild = true; } ''
      mkdir -p $out/Library/Fonts
      store_dir=${lib.escapeShellArg builtins.storeDir}
      while IFS= read -rd "" f; do
        dest="$out/Library/Fonts/Nix Fonts/''${f#"$store_dir/"}"
        mkdir -p "''${dest%/*}"
        ln -sf "$f" "$dest"
      done < <(
        find -L ${lib.escapeShellArgs cfg.packages} \
          -type f \
          -regex '.*\.\(ttf\|ttc\|otf\|dfont\)' \
          -print0
      )
    '';

    system.activationScripts.fonts.text = ''
      printf >&2 'setting up /Library/Fonts/Nix Fonts...\n'

      # rsync uses the mtime + size of files to determine whether they
      # need to be copied by default. This is inadequate for Nix store
      # paths, but we don't want to use `--checksum` as it makes
      # activation consistently slow when you have large fonts
      # installed. Instead, we ensure that fonts are linked according to
      # their full store paths in `system.build.fonts`, so that any
      # given font path should only ever have one possible content.
      ${pkgs.rsync}/bin/rsync \
        --archive \
        --copy-links \
        --delete-during \
        --delete-missing-args \
        "$systemConfig/Library/Fonts/Nix Fonts" \
        '/Library/Fonts/'
    '';

  };
}
