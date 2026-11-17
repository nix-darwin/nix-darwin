{ stdenv, fetchurl, xar, zip, cpio }:

stdenv.mkDerivation rec {
  pname = "MathSymbolsInput";
  version = "v1.3";

  src = fetchurl {
    url =
      "https://github.com/knrafto/${pname}/releases/download/${version}/${pname}.pkg";
    sha256 = "sha256-+s+TFoAv2rWl3gOHp8LLUZm+OTMDxgZtK0vmHQDJzFU=";
  };

  phases = [ "unpackPhase" "buildPhase" "installPhase" ];
  unpackPhase = "xar -xf $src";

  buildInputs = [ xar zip cpio ];

  buildPhase = ''
    cat MathSymbolsInput.pkg/Payload  | gunzip -dc | cpio -i
  '';

  installPhase = ''
    mkdir -p $out
    cp -r "Math Symbols Input.app" $out
  '';
}
