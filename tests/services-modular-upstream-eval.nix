# Pure-eval test: exercises `pkgs.ghostunnel.passthru.services.default`
# through our `serviceSubmodule` without building the full launchd/etc
# derivation chain.  The `assert` runs at Nix eval time, so a schema
# mismatch (e.g. "option does not exist") surfaces immediately.
{ lib, pkgs, ... }:
let
  servicesLib = import ../modules/services-modular/lib.nix {
    inherit lib pkgs;
    rootPath = "/etc/system-services";
  };

  ghostunnelEval = lib.evalModules {
    modules = [
      {
        options.services = lib.mkOption {
          type = lib.types.attrsOf servicesLib.serviceSubmodule;
        };
      }
      {
        services.ghostunnel = {
          imports = [ pkgs.ghostunnel.passthru.services.default ];
          ghostunnel.listen = "localhost:8443";
          ghostunnel.target = "localhost:8080";
          ghostunnel.disableAuthentication = true;
        };
      }
    ];
  };

  argv = ghostunnelEval.config.services.ghostunnel.process.argv;
  # Forced by string interpolation below; fails at eval time if the upstream
  # module is incompatible with our schema or produces an empty argv.
  evalCheck = assert lib.elem "server" argv; "passed";
in
{
  system.primaryUser = "test-modular-upstream-eval";

  test = ''
    echo "services-modular-upstream-eval: ${evalCheck}" >&2
  '';
}
