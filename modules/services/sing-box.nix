{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  cfg = config.services.sing-box;
in
{
  imports = [
    (lib.mkRemovedOptionModule [ "services" "sing-box" "configFile" ] ''
      The `configFile` option has been removed to support secret substitution.
      Please migrate your configuration to `services.sing-box.settings`.
      For example: `{ _secret = config.sops.secrets."sb_config.json".path; quote = false; }`
    '')
  ];

  meta.maintainers = [ lib.maintainers.proteus or "Proteus Qian" ];
  options.services.sing-box = {
    enable = lib.mkEnableOption "sing-box universal proxy platform";
    package = lib.mkPackageOption pkgs "sing-box" { };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = (pkgs.formats.json { }).type;
      };
      default = { };
      description = ''
        The sing-box configuration, see <https://sing-box.sagernet.org/configuration/> for documentation.

        Options containing secret data should be set to an attribute set
        containing the attribute `_secret` - a string pointing to a file
        containing the value the option should be set to.
      '';
    };
    runtimeDir = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
      default = "/var/run/sing-box";
      description = ''
        Unlike systemd, launchd don't have shell veriables like $RUNTIME_DIRECTORY and $STATE_DIRECTORY, so make a
        read-only global option to reduce the duplication.
      '';
    };
  };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    system.activationScripts.postActivation.text = ''
      # Ensure the sing-box state directory is initialized
      if [ ! -d ${lib.escapeShellArg config.launchd.daemons.sing-box.serviceConfig.WorkingDirectory} ]; then
        echo "Setting up Sing-box directory..."
        install -dm700 ${lib.escapeShellArg config.launchd.daemons.sing-box.serviceConfig.WorkingDirectory}
      fi
    '';

    launchd.daemons.sing-box = {
      serviceConfig = {
        Label = "io.nekohasekai.sing-box";
        RunAtLoad = true;
        KeepAlive = {
          Crashed = true;
          SuccessfulExit = false;
        };
        WorkingDirectory = "/Library/Application Support/sing-box";
        StandardErrorPath = "/Library/Logs/io.nekohasekai.sing-box.stderr.log";
        StandardOutPath = "/Library/Logs/io.nekohasekai.sing-box.stdout.log";
      };
      script = lib.mkMerge [
        ''
          if [ ! -d '${cfg.runtimeDir}' ]; then mkdir '${cfg.runtimeDir}'; fi
          chmod -R 0700 ${cfg.runtimeDir}

          ${utils.genJqSecretsReplacementSnippet cfg.settings "${cfg.runtimeDir}/config.json"}
        ''
        ''
          ${lib.getExe cfg.package} -D '${config.launchd.daemons.sing-box.serviceConfig.WorkingDirectory}' -C '${cfg.runtimeDir}' run
        ''
      ];
    };
  };
}
