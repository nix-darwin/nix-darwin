{ config, extendModules, lib, pkgs, ... }:

let
  probe = pkgs.runCommandCC "launchd-environment-probe" { } ''
    $CC ${./fixtures/launchd-environment.c} -o "$out"
  '';
  arguments = [ "space argument" "" "literal $value & 'quotes'" ];
  probeJob.serviceConfig.ProgramArguments = [ "${probe}" ] ++ arguments;

  withoutCertificates = (extendModules {
    modules = [ {
      security.pki.installCACerts = false;
      security.pki.caCertificateBlacklist = [ "DigiCert Global Root G2" ];
    } ];
  }).config;

  fallbackBundle = withoutCertificates.security.pki.environment.NIX_SSL_CERT_FILE;
  customBundle = "/certs/company's $bundle.pem";

  withCustomBundle = (extendModules {
    modules = [ { environment.variables.NIX_SSL_CERT_FILE = customBundle; } ];
  }).config;

  withoutCertificatesWithCustomBundle = (extendModules {
    modules = [ {
      security.pki.installCACerts = false;
      environment.variables.NIX_SSL_CERT_FILE = customBundle;
    } ];
  }).config;

  # Pair generated plists with expected arguments and environment overrides.
  # expectedEnvironment records expectations; it does not configure the job.
  casesFor = configuration: defaultBundle:
    let
      makeCase = jobs: name: expectedArgv: {
        inherit name defaultBundle expectedArgv;
        expectedEnvironment = { };
        plist = jobs."org.nixos.${name}.plist".text;
      };
      daemonCase = makeCase configuration.environment.launchDaemons;
    in [
      # Command forms, argument preservation, and executable lookup.
      (daemonCase "pki-arguments" ([ "${probe}" ] ++ arguments))
      (daemonCase "pki-program" [ "${probe}" ])
      (daemonCase "pki-argv0" ([ "custom argv0" ] ++ arguments))
      (daemonCase "pki-command" ([ "${probe}" ] ++ arguments))
      (daemonCase "pki-script" ([ "${probe}" ] ++ arguments))
      ((daemonCase "pki-search" ([ "${probe}" ] ++ arguments)) // {
        expectedEnvironment.PATH = "/no-such-programs";
      })

      # Explicit certificate overrides, including empty values.
      ((daemonCase "pki-nix" ([ "${probe}" ] ++ arguments)) // {
        expectedEnvironment.NIX_SSL_CERT_FILE = "/job/nix.pem";
      })
      ((daemonCase "pki-ssl" ([ "${probe}" ] ++ arguments)) // {
        expectedEnvironment.SSL_CERT_FILE = "/job/ssl.pem";
      })
      ((daemonCase "pki-empty" ([ "${probe}" ] ++ arguments)) // {
        expectedEnvironment.SSL_CERT_FILE = "";
      })
      ((daemonCase "pki-empty-nix" ([ "${probe}" ] ++ arguments)) // {
        expectedEnvironment.NIX_SSL_CERT_FILE = "";
      })

      # System-wide and per-user agents.
      (makeCase configuration.environment.launchAgents "pki-agent" ([ "${probe}" ] ++ arguments))
      (makeCase configuration.environment.userLaunchAgents "pki-user-agent" ([ "${probe}" ] ++ arguments))
    ];

  cases = pkgs.writeText "launchd-certificate-cases.json" (builtins.toJSON (
    casesFor config "/etc/ssl/certs/ca-certificates.crt"
    ++ casesFor withoutCertificates fallbackBundle
    ++ casesFor withCustomBundle customBundle
    ++ casesFor withoutCertificatesWithCustomBundle customBundle
  ));

  runtimeTest = pkgs.runCommand "launchd-certificate-environment" {
    # Exercise the native store wait and launchd's standard executable search.
    sandboxProfile = ''
      (allow file-read* process-exec
        (literal "/bin/wait4path")
        (literal "/usr/bin/getconf")
        (literal "/usr/bin/env"))
    '';
  } ''
    ${pkgs.python3}/bin/python ${./launchd-certificate-environment.py} ${cases}
    touch "$out"
  '';
in

{
  system.primaryUser = "test-pki-user";

  # Define the actual services whose generated plists are exercised by casesFor.
  launchd.daemons = {
    # Command forms, argument preservation, and executable lookup.
    pki-arguments = probeJob;
    pki-program.serviceConfig.Program = "${probe}";
    pki-argv0.serviceConfig = {
      Program = "${probe}";
      ProgramArguments = [ "custom argv0" ] ++ arguments;
    };
    pki-command.command = lib.escapeShellArgs ([ "${probe}" ] ++ arguments);
    pki-script.script = "exec ${lib.escapeShellArgs ([ "${probe}" ] ++ arguments)}";
    pki-search = {
      serviceConfig.ProgramArguments = [ "env" "${probe}" ] ++ arguments;
      environment.PATH = "/no-such-programs";
    };

    # Explicit certificate overrides, including empty values.
    pki-nix = lib.recursiveUpdate probeJob {
      environment.NIX_SSL_CERT_FILE = "/job/nix.pem";
    };
    pki-ssl = lib.recursiveUpdate probeJob {
      serviceConfig.EnvironmentVariables.SSL_CERT_FILE = "/job/ssl.pem";
    };
    pki-empty = lib.recursiveUpdate probeJob {
      environment.SSL_CERT_FILE = "";
    };
    pki-empty-nix = lib.recursiveUpdate probeJob {
      environment.NIX_SSL_CERT_FILE = "";
    };
  };

  # System-wide and per-user agents.
  launchd.agents.pki-agent = probeJob;
  launchd.user.agents.pki-user-agent = probeJob;

  test = ''
    test -e ${runtimeTest}

    echo "checking that the fallback bundle rejects a blacklisted root" >&2
    ${pkgs.openssl}/bin/openssl x509 \
      -in ${pkgs.cacert.unbundled}/etc/ssl/certs/DigiCert_Global_Root_G2:*.crt -out root.pem

    NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt \
      ${pkgs.openssl}/bin/openssl verify -no_check_time -purpose sslserver root.pem
    (! NIX_SSL_CERT_FILE=${fallbackBundle} \
      ${pkgs.openssl}/bin/openssl verify -no_check_time -purpose sslserver root.pem)
  '';
}
