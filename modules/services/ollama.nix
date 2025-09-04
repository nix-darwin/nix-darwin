{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.services.ollama;

in {
  meta.maintainers = [ "velnbur" ];

  options = {
    services.ollama = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable the Ollama Daemon.";
      };

      package = mkOption {
        type = types.path;
        default = pkgs.ollama;
        description = "This option specifies the ollama package to use.";
      };

      host = mkOption {
        type = types.str;
        default = "127.0.0.1";
        example = "0.0.0.0";
        description = ''
          The host address which the ollama server HTTP interface listens to.
        '';
      };

      port = mkOption {
        type = types.port;
        default = 11434;
        example = 11111;
        description = ''
          Which port the ollama server listens to.
        '';
      };

      models = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "/path/to/ollama/models";
        description = ''
          The directory that the ollama service will read models from and download new models to.
        '';
      };

      environmentVariables = mkOption {
        type = types.attrsOf types.str;
        default = { };
        example = {
          OLLAMA_LLM_LIBRARY = "cpu";
          HIP_VISIBLE_DEVICES = "0,1";
        };
        description = ''
          Set arbitrary environment variables for the ollama service.

          Be aware that these are only seen by the ollama server (launchd daemon),
          not normal invocations like `ollama run`.
          Since `ollama run` is mostly a shell around the ollama server, this is usually sufficient.
        '';
      };
    };
  };

  config = mkIf cfg.enable {

    environment.systemPackages = [ cfg.package ];

    launchd.user.agents.ollama = {
      path = [ config.environment.systemPath ];

      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        ProgramArguments = [ "${cfg.package}/bin/ollama" "serve" ];

        EnvironmentVariables = cfg.environmentVariables // {
          OLLAMA_HOST = "${cfg.host}:${toString cfg.port}";
        } // (optionalAttrs (cfg.models != null) {
          OLLAMA_MODELS = cfg.models;
        });
      };
    };
  };
}
