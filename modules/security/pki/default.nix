{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.security.pki;

  cacertPackage = pkgs.cacert.override {
    blacklist = cfg.caCertificateBlacklist;
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
