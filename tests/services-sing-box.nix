{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.sing-box;
  working_dir = config.launchd.daemons.sing-box.serviceConfig.WorkingDirectory;
in
{
  services.sing-box.enable = true;
  services.sing-box.package = pkgs.writeShellScriptBin "sing-box" "exit 0" // {
    meta.mainProgram = "sing-box";
  };

  services.sing-box.settings = {
    log.level = "info";
  };

  test = ''
    echo >&2 "checking sing-box service in Library/LaunchDaemons"

    # Check that the plist file was generated and contains the expected Label
    grep 'io.nekohasekai.sing-box' ${config.out}/Library/LaunchDaemons/io.nekohasekai.sing-box.plist

    # Extract the launch script path
    script_path=$(grep -oE '/nix/store/[a-zA-Z0-9.-]+sing-box-start' ${config.out}/Library/LaunchDaemons/io.nekohasekai.sing-box.plist | head -n 1)

    echo >&2 "checking execution script: $script_path"

    # Check that the execution command includes the mocked package
    grep '${lib.getExe cfg.package}' $script_path

    # Check that it passes the correct working directory flag
    grep -- ${lib.escapeShellArg "-D ${lib.escapeShellArg working_dir}"} $script_path

    # Check that it passes the correct config directory flag
    grep -- ${lib.escapeShellArg "-C '${cfg.runtimeDir}'"} $script_path

    echo >&2 "checking sing-box state directory setup in activate script"

    # Verify the activation script has the postActivation hook to create the directory
    grep "Setting up Sing-box directory" ${config.out}/activate
    grep ${lib.escapeShellArg "install -dm700 ${lib.escapeShellArg working_dir}"} ${config.out}/activate
  '';
}
