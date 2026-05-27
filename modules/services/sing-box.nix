{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  cfg = config.services.sing-box;
  settingsFormat = pkgs.formats.json { };
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
        freeformType = settingsFormat.type;
      };
      default = { };
      description = ''
        The sing-box configuration, see <https://sing-box.sagernet.org/configuration/> for documentation.

        Options containing secret data should be set to an attribute set
        containing the attribute `_secret` - a string pointing to a file
        containing the value the option should be set to.
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
        # ProgramArguments = [
        #   "/bin/sh"
        #   "-c"
        #   ("/bin/wait4path /nix/store" + " && exec ${lib.getExe cfg.package} -c ${cfg.configFile} run")
        # ];
      };
      script = ''
        ${utils.genJqSecretsReplacementSnippet cfg.settings "/run/sing-box/config.json"}

        if [ ! -d '/run/sing-box' ]; then mkdir '/run/sing-box'; fi

        chmod -R 0700 /run/sing-box

        ${lib.getExe cfg.package} -D ${lib.escapeShellArg config.launchd.daemons.sing-box.serviceConfig.WorkingDirectory} -C '/run/sing-box' run
      '';
    };
  };
}
