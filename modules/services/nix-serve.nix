{ config, pkgs, lib, ... }:
let cfg = config.services.nix-serve; in
{
  options = {
    services.nix-serve.enable = lib.mkEnableOption "nix-serve, the standalone Nix binary cache server";

    services.nix-serve.port = lib.mkOption {
      type = lib.types.port;
      default = 5000;
      description = ''
        Port number where nix-serve will listen on.
      '';
    };

    services.nix-serve.bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = ''
        IP address where nix-serve will bind its listening socket.
      '';
    };

    services.nix-serve.secretKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        The path to the file used for signing derivation data.
        Generate with:

        ```
        nix-store --generate-binary-cache-key key-name secret-key-file public-key-file
        ```

        Make sure user `nix-serve` has read access to the private key file.

        For more details see <citerefentry><refentrytitle>nix-store</refentrytitle><manvolnum>1</manvolnum></citerefentry>.
      '';
    };

    services.nix-serve.extraParams = lib.mkOption {
      type = lib.types.separatedString " ";
      example = "--workers 50";
      default = "";
      description = ''
        Extra command line parameters for nix-serve.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    launchd.daemons.nix-serve = {
      script = ''
        ${pkgs.nix-serve}/bin/nix-serve --listen ${cfg.bindAddress}:${toString cfg.port} cfg.extraParams;
      '';
      path = [ config.nix.package.out pkgs.bzip2.bin ];

      environment.NIX_REMOTE = "daemon";
      environment.NIX_SECRET_KEY_FILE = cfg.secretKeyFile;

      serviceConfig = {
        ThrottleInterval = 5;
        RunAtLoad = true;
        KeepAlive.NetworkState = true;
      };
    };
  };
}
