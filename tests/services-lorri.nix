{
  config,
  pkgs,
  lib,
  ...
}:

let
  plistPath = "${config.out}/user/Library/LaunchAgents/org.nixos.lorri.plist";
  expectedPath = "${lib.makeBinPath [
    config.nix.package
    pkgs.git
    pkgs.gnutar
    pkgs.gzip
  ]}";
  expectedNixPath = "nixpkgs=${toString pkgs.path}";
in
{
  system.primaryUser = "test-lorri-user";

  services.lorri.enable = true;
  test = ''
    ${pkgs.python3}/bin/python - ${plistPath} <<'PY'
    import plistlib
    import sys

    with open(sys.argv[1], "rb") as source:
        service = plistlib.load(source)

    assert service["EnvironmentVariables"]["PATH"] == ${builtins.toJSON expectedPath}
    assert service["EnvironmentVariables"]["NIX_PATH"] == ${builtins.toJSON expectedNixPath}
    assert service["KeepAlive"] is True
    assert service["Label"] == "org.nixos.lorri"
    assert service["ProcessType"] == "Background"
    assert service["RunAtLoad"] is True
    PY
  '';
}
