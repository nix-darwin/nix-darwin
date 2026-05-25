{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.sing-box;
  sing-box_dir = "/Library/Application Support/sing-box";
in
{
  services.sing-box.enable = true;
  # Mock the package to avoid a full build
  services.sing-box.package = pkgs.writeShellScriptBin "sing-box" "exit 0" // {
    meta.mainProgram = "sing-box";
  };
  services.sing-box.configFile = pkgs.emptyFile;

  test = ''
    echo >&2 "checking sing-box service in Library/LaunchDaemons"

    # Check that the plist file was generated and contains the expected Label
    grep "io.nekohasekai.sing-box" ${config.out}/Library/LaunchDaemons/io.nekohasekai.sing-box.plist

    # Check that the execution command includes the mocked package and config file
    grep "${lib.getExe cfg.package}" ${config.out}/Library/LaunchDaemons/io.nekohasekai.sing-box.plist
    grep -- "-c ${cfg.configFile}" ${config.out}/Library/LaunchDaemons/io.nekohasekai.sing-box.plist
    echo ${config.out}/
    grep -- "-D ${lib.escapeXML (lib.escapeShellArg sing-box_dir)}" ${config.out}/Library/LaunchDaemons/io.nekohasekai.sing-box.plist

    echo >&2 "checking sing-box state directory setup in activate script"

    # Verify the activation script has the postActivation hook to create the directory
    grep "Setting up Sing-box directory" ${config.out}/activate
    grep "install -dm700 ${lib.escapeShellArg sing-box_dir}" ${config.out}/activate
  '';
}
