# Converts an attr list to the text file format used by Math Symbols Input.
# for example, the following command attribute set
#
#    {"alpha" = "α"; "beta" = "β";}
#
# would be converted to
#
#    \alpha α
#    \beta β
#
{ writeText, lib }:
commands:
writeText "custom-commands.txt" (builtins.concatStringsSep "\n"
  (lib.attrsets.mapAttrsToList (name: value: "\\${name} ${value}") commands))
