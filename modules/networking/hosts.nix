{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.networking;

  # Entries mapped to no hostnames produce no line, so they do not count as
  # content either.
  nonEmptyHosts = filterAttrs (_: v: v != [ ]) cfg.hosts;

  localhostHosts = pkgs.writeText "localhost-hosts" ''
    127.0.0.1 localhost
    ::1 localhost
  '';

  stringHosts =
    let
      oneToString = set: ip: ip + " " + concatStringsSep " " set.${ip} + "\n";
      allToString = set: concatMapStrings (oneToString set) (attrNames set);
    in
    pkgs.writeText "string-hosts" (allToString nonEmptyHosts);

  extraHosts = pkgs.writeText "extra-hosts" cfg.extraHosts;

  generatedHosts = pkgs.concatText "hosts" (
    [
      localhostHosts
      stringHosts
      extraHosts
    ]
    ++ cfg.hostFiles
  );

  localhostMultiple = any (elem "localhost") (
    attrValues (removeAttrs cfg.hosts [ "127.0.0.1" "::1" ])
  );

in

{

  meta.maintainers = [
    (lib.maintainers.DavSanchez or "DavSanchez")
  ];

  options = {
    networking = {
      enableHosts = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to add Nix-managed entries to {file}`/etc/hosts`.

          The entries are written to {file}`/etc/hosts` as a regular file,
          wrapped between `# BEGIN Nix-managed` and `# END Nix-managed`
          markers. Any content outside the markers, such as entries added by
          macOS, VPN clients or by hand, is preserved. Nothing is written if
          none of {option}`networking.hosts`, {option}`networking.extraHosts`
          and {option}`networking.hostFiles` is set.

          The generated block always starts with the default `localhost`
          entries. These duplicate the ones macOS ships in
          {file}`/etc/hosts`, which is harmless.

          {file}`/etc/hosts` is only rewritten when its content changes, and
          the new file keeps the owner, mode, ACLs and extended attributes of
          the old one. A symlink, e.g. into the Nix store, is replaced by a
          regular file. A temporary {file}`/etc/hosts.nix.*` file is used for
          this, which is removed when activation fails or is interrupted, and
          at the next activation if it could not be.

          When disabled, activation is a no-op, except that it strips a
          Nix-managed block left over from a previous generation. A missing
          {file}`/etc/hosts` is not created, and
          {option}`networking.hosts`, {option}`networking.extraHosts` and
          {option}`networking.hostFiles` are ignored.
        '';
      };

      hosts = mkOption {
        type = types.attrsOf (types.listOf types.str);
        default = { };
        example = literalExpression ''
          {
            "127.0.0.1" = [ "foo.bar.baz" ];
            "192.168.0.2" = [ "fileserver.local" "nameserver.local" ];
          }
        '';
        description = ''
          Locally defined maps of hostnames to IP addresses.
          Every entry is added to {file}`/etc/hosts` in addition to
          the default localhost entries.
        '';
      };

      extraHosts = mkOption {
        type = types.lines;
        default = "";
        example = "192.168.0.1 lanlocalhost";
        description = ''
          Additional verbatim entries to be appended to {file}`/etc/hosts`.
          For adding hosts from derivation results, use
          {option}`networking.hostFiles` instead.
        '';
      };

      hostFiles = mkOption {
        type = types.listOf types.path;
        default = [ ];
        example = literalExpression ''[ "''${pkgs.my-blocklist-package}/share/my-blocklist/hosts" ]'';
        description = ''
          List of files that should be concatenated into
          {file}`/etc/hosts` after the generated entries.
        '';
      };
    };
  };

  config = {
    assertions = [
      {
        assertion = !localhostMultiple;
        message = ''
          `networking.hosts` maps "localhost" to something other than
          "127.0.0.1" or "::1". This will break some applications. Please use
          `networking.extraHosts` if you really want to add such a mapping.
        '';
      }
      {
        assertion = !(cfg.enableHosts && config.environment.etc ? "hosts");
        message = ''
          `networking.enableHosts` writes {file}`/etc/hosts` as a regular file,
          which conflicts with `environment.etc."hosts"` (a symlink into the
          Nix store). Use one or the other.
        '';
      }
    ];
  };
}
