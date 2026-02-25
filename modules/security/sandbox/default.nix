{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.security.sandbox;

  profile =
    { config, name, ... }:
    {
      options = {
        profile = mkOption {
          type = types.lines;
          internal = true;
          apply =
            text:
            pkgs.runCommand "sandbox.sb" { } ''
              for f in $(< ${config.closure}/store-paths); do
                  storePaths+="(subpath \"$f\")"
              done

              cat <<-EOF > $out
              ${text}
              EOF
            '';
        };

        closure = mkOption {
          type = types.listOf types.package;
          default = [ ];
          apply = paths: pkgs.closureInfo { rootPaths = paths; };
          description = "List of store paths to make accessible.";
        };

        readablePaths = mkOption {
          type = types.listOf types.path;
          default = [ ];
          description = "List of paths that should be read-only inside the sandbox.";
        };

        writablePaths = mkOption {
          type = types.listOf types.path;
          default = [ ];
          description = "List of paths that should be read/write inside the sandbox.";
        };

        allowSystemPaths = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to allow read access to FHS paths like /etc and /var.";
        };

        allowLocalNetworking = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to allow localhost network access inside the sandbox.";
        };

        allowNetworking = mkOption {
          type = types.bool;
          default = false;
          description = "Whether to allow network access inside the sandbox.";
        };
      };

      config = {

        allowSystemPaths = mkDefault (config.allowLocalNetworking || config.allowNetworking);

        profile = mkOrder 0 ''
          (version 1)
          (deny default)

          (allow file-read*
                 (subpath "/usr/lib")
                 (subpath "/System/Library/Frameworks")
                 (subpath "/System/Library/PrivateFrameworks"))

          (allow file-read-metadata
                 (literal "/dev"))
          (allow file*
                 (literal "/dev/null")
                 (literal "/dev/random")
                 (literal "/dev/stdin")
                 (literal "/dev/stdout")
                 (literal "/dev/tty")
                 (literal "/dev/urandom")
                 (literal "/dev/zero")
                 (subpath "/dev/fd"))

          (allow process-fork)
          (allow signal (target same-sandbox))
          (allow file-read* process-exec
                 $storePaths)

          ${optionalString (config.readablePaths != [ ]) ''
            (allow file-read*
                   ${concatMapStrings (x: ''(subpath "${x}")'') config.readablePaths})
          ''}
          ${optionalString (config.writablePaths != [ ]) ''
            (allow file*
                   ${concatMapStrings (x: ''(subpath "${x}")'') config.writablePaths})
          ''}
          ${optionalString config.allowSystemPaths ''
            (allow file-read-metadata
                   (literal "/")
                   (literal "/etc")
                   (literal "/run")
                   (literal "/tmp")
                   (literal "/var"))
            (allow file-read*
                   (literal "/private/etc/group")
                   (literal "/private/etc/hosts")
                   (literal "/private/etc/passwd")
                   (literal "/private/var/run/resolv.conf"))
          ''}
          ${optionalString config.allowLocalNetworking ''
            (allow network* (local ip) (local tcp) (local udp))
          ''}
          ${optionalString config.allowNetworking ''
            (allow network*
                   (local ip)
                   (remote ip))
            (allow network-outbound
                   (remote unix-socket (path-literal "/private/var/run/mDNSResponder")))
          ''}
        '';

      };
    };
in

{
  options = {
    security.sandbox.profiles = mkOption {
      type = types.attrsOf (types.submodule profile);
      default = { };
      description = "Definition of sandbox profiles.";
    };
  };

  config = { };
}
