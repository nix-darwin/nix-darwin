# This module was derived from
# https://github.com/NixOS/nixpkgs/blob/000387627d26f245a6d9a0a7a60b7feddecaeec0/nixos/modules/misc/meta.nix
{ lib, ... }:

with lib;

let
  maintainer = mkOptionType {
    name = "maintainer";
    check = email: elem email (attrValues lib.maintainers);
    merge = loc: defs: listToAttrs (singleton (nameValuePair (last defs).file (last defs).value));
  };

  listOfMaintainers = types.listOf maintainer // {
    # Returns list of
    #   { "module-file" = [
    #        "maintainer1 <first@nixos.org>"
    #        "maintainer2 <second@nixos.org>" ];
    #   }
    merge =
      loc: defs:
      zipAttrs (
        flatten (
          imap1 (
            n: def:
            imap1 (
              m: def':
              maintainer.merge (loc ++ [ "[${toString n}-${toString m}]" ]) [
                {
                  inherit (def) file;
                  value = def';
                }
              ]
            ) def.value
          ) defs
        )
      );
  };

in

{
  options = {
    meta = {

      maintainers = mkOption {
        type = listOfMaintainers;
        internal = true;
        default = [ ];
        example = [ lib.maintainers.lnl7 ];
        description = ''
          List of maintainers of each module.  This option should be defined at
          most once per module.

          NOTE: `lib` comes from Nixpkgs, which can go out of
          sync with nix-darwin. For this reason, use definitions like
          `maintainers.alice or "alice"`.
        '';
      };

    };
  };

  meta.maintainers = [
    maintainers.roberth or "roberth"
  ];
}
