{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.security.pki;

  cacertPackage = pkgs.cacert.override {
    blacklist = cfg.caCertificateBlacklist ++ [
      # Compromised eMudhra intermediates also have Sectigo cross-signs.
      # https://github.com/NixOS/nixpkgs/issues/576485
      "Comodo AAA Services root"
    ]
    # NSS 3.131.1 already removes these roots. Blacklisting absent certificates
    # causes buildcatrust to fail (NixOS/nixpkgs#249080).
    ++ optionals (versionOlder pkgs.cacert.version "3.131.1") [
      "emSign ECC Root CA - G3"
      # Retired roots removed alongside the compromise mitigation in NSS 3.131.1.
      # https://bugzilla.mozilla.org/show_bug.cgi?id=2083709
      "emSign Root CA - C1"
      "emSign ECC Root CA - C3"
    ];
  };

  caCertificates = pkgs.runCommand "ca-certificates.crt" {}
    ''
      cat ${escapeShellArgs (
        cfg.certificateFiles ++
        [ (builtins.toFile "extra.crt" (concatStringsSep "\n" cfg.certificates)) ]
      )} > $out
    '';
in

{
  options = {
    security.pki.installCACerts = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to enable certificate management with nix-darwin.
      '';
    };

    security.pki.certificateFiles = mkOption {
      type = types.listOf types.path;
      default = [];
      example = literalExpression "[ \"\${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt\" ]";
      description = ''
        A list of files containing trusted root certificates in PEM
        format. These are concatenated to form
        {file}`/etc/ssl/certs/ca-certificates.crt`, which is
        used by many programs that use OpenSSL, such as
        {command}`curl` and {command}`git`.
      '';
    };

    security.pki.certificates = mkOption {
      type = types.listOf types.str;
      default = [];
      example = literalExpression ''
        [ '''
            NixOS.org
            =========
            -----BEGIN CERTIFICATE-----
            MIIGUDCCBTigAwIBAgIDD8KWMA0GCSqGSIb3DQEBBQUAMIGMMQswCQYDVQQGEwJJ
            TDEWMBQGA1UEChMNU3RhcnRDb20gTHRkLjErMCkGA1UECxMiU2VjdXJlIERpZ2l0
            ...
            -----END CERTIFICATE-----
          '''
        ]
      '';
      description = ''
        A list of trusted root certificates in PEM format.
      '';
    };

    security.pki.caCertificateBlacklist = mkOption {
      type = types.listOf types.str;
      default = [];
      example = [
        "WoSign" "WoSign China"
        "CA WoSign ECC Root"
        "Certification Authority of WoSign G2"
      ];
      description = ''
        A list of blacklisted CA certificate names that won't be imported from
        the Mozilla Trust Store into
        {file}`/etc/ssl/certs/ca-certificates.crt`. Use the
        names from that file.
      '';
    };
  };

  config = mkIf cfg.installCACerts {

    security.pki.certificateFiles = [ "${cacertPackage}/etc/ssl/certs/ca-bundle.crt" ];

    environment.etc."ssl/certs/ca-certificates.crt".source = caCertificates;
    environment.variables.NIX_SSL_CERT_FILE = mkDefault "/etc/ssl/certs/ca-certificates.crt";

  };
}
