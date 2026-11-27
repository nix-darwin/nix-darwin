{
  config,
  lib,
  pkgs,
  ...
}:

let
  harmonia = pkgs.runCommand "harmonia-0.0.0" { meta.mainProgram = "harmonia"; } "mkdir $out";
in
{
  services.harmonia.package = harmonia;
  services.harmonia.cache = {
    enable = true;
    signKeyPaths = [ "/var/lib/harmonia/secret-key" ];
    settings.bind = "127.0.0.1:5000";
  };

  test = ''
    plist=${config.out}/Library/LaunchDaemons/org.nixos.harmonia.plist

    echo >&2 "checking harmonia service in /Library/LaunchDaemons"
    grep -q "${harmonia}/bin/harmonia" -- "$plist"
    grep -A1 "<key>UserName</key>" -- "$plist" | grep -q "<string>_harmonia</string>"
    grep -A1 "<key>GroupName</key>" -- "$plist" | grep -q "<string>_harmonia</string>"

    echo >&2 "checking harmonia user and group in /activate"
    grep -q "sysadminctl -addUser ${
      lib.escapeShellArgs [
        "_harmonia"
        "-UID"
        536
        "-GID"
        536
      ]
    }" -- ${config.out}/activate
    grep -q "dscl . -create ${lib.escapeShellArg "/Groups/_harmonia"} PrimaryGroupID 536" -- ${config.out}/activate

    echo >&2 "checking harmonia configuration"
    config_file=$(grep -o '/nix/store/[^<]*-harmonia.toml' -- "$plist")
    grep -q 'bind = "127.0.0.1:5000"' -- "$config_file"
    grep -q 'workers = 4' -- "$config_file"
    grep -q 'sign_key_paths = \["/var/lib/harmonia/secret-key"\]' -- "$config_file"
  '';
}
