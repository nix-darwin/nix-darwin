{ lib, writePython3Bin, cytoolz }:

writePython3Bin "generate_commands_plist" {
  libraries = [ cytoolz ];
  flakeIgnore = [ "E501" ];
} (builtins.readFile ./generate_commands_plist.py)
