{ stdenv, callPackage, python3Packages, writers }:
commands:

let

  custom-commmands-file = callPackage ./custom-commands.nix { };

  generate-commands-plist =
    python3Packages.callPackage ./generate-commands-plist {
      inherit (writers) writePython3Bin;
    };
  math-symbols-input = callPackage ./package { };

in stdenv.mkDerivation {
  name = "commands-plist";

  phases = [ "installPhase" ];

  installPhase = ''
    mkdir -p $out

    # Call the generate_commands_plist python cli to convert the default
    # list of replacements and a custom list of replacements to a plist file.
    ${generate-commands-plist}/bin/generate_commands_plist \
    ${math-symbols-input}/Math\ Symbols\ Input.app/Contents/Resources/commands.txt \
    ${custom-commmands-file commands} \
    $out/com.mathsymbolsinput.inputmethod.MathSymbolsInput.plist
  '';
}
