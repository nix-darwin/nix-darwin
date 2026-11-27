{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Apple's /usr/bin shims exec `$DEVELOPER_DIR/usr/bin/xcrun <tool> <args>`.
  # Direct xcrun calls start with options such as `--show-sdk-path`.
  xcrunBlocker = pkgs.writeShellScript "apple-developer-tools-xcrun-blocker" ''
    tool=xcrun
    case "''${1-}" in
      "" | -* | */*) ;;
      *) if [ -x "/usr/bin/$1" ]; then tool=$1; fi ;;
    esac
    {
      printf '%s\n' "$tool: blocked by environment.appleDeveloperTools.block."
      printf '%s\n' "If a Nix package provides this command, add it to environment.systemPackages or your development shell."
      printf '%s\n' "To invoke the Apple tool directly, run: env -u DEVELOPER_DIR /usr/bin/$tool"
    } >&2
    exit 127
  '';

  blockedDeveloperDir = pkgs.linkFarm "apple-developer-tools-disabled" [
    {
      name = "usr/bin/xcrun";
      path = xcrunBlocker;
    }
  ];
in
{
  meta.maintainers = [
    lib.maintainers.gordon01 or "gordon01"
  ];

  options.environment.appleDeveloperTools.block = lib.mkOption {
    type = lib.types.bool;
    default = false;
    example = true;
    description = ''
      Whether to block Apple's developer-tool shims to avoid the macOS
      Command Line Tools install or update prompt.
      The stub points users to Nix-provided tools.
      This option does not change {env}`PATH` or uninstall Xcode.
      Nix-managed tools that do not rely on Apple's developer tools remain
      available.

      New shells need to be started for changes to take effect.
    '';
  };

  config = lib.mkIf config.environment.appleDeveloperTools.block {
    system.requiresPrimaryUser = [ "environment.appleDeveloperTools.block" ];
    environment.variables.DEVELOPER_DIR = "${blockedDeveloperDir}";
    launchd.user.envVariables.DEVELOPER_DIR = "${blockedDeveloperDir}";
  };
}
