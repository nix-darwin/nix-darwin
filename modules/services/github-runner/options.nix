{ lib
, pkgs
, ...
}:

let
  inherit (lib) literalExpression mkOption mkPackageOption types;
in
{
  options.services.github-runners = mkOption {
    description = ''
      Multiple GitHub Runners.

      If `user` and `group` are set to `null`, the module will configure nix-darwin to
      manage the `_github-runner` user and group. Note that multiple runner
      configurations share the same user/group, which means they can access
      resources from other runners. Make each runner use its own user and group if
      this is not what you want. In this case, you will have to do the user and
      group creation yourself. If only `user` is set, while `group` is set to
      `null`, the service will infer the primary group of the `user`.

      For each GitHub runner, the system activation script creates the following
      directories:

      * `/var/lib/github-runners/<name>`:
        State directory to store the runner registration credentials
      * `/var/lib/github-runners/_work/<name>`:
        Working directory for workflow files. The runner only uses this
        directory if `workDir` is `null` (see the `workDir` option for details).
      * `/var/log/github-runners/<name>`:
        The launchd service writes the stdout and stderr streams to this
        directory.
    '';
    example = {
      runner1 = {
        enable = true;
        url = "https://github.com/owner/repo";
        name = "runner1";
        tokenFile = "/secrets/token1";
      };

      runner2 = {
        enable = true;
        url = "https://github.com/owner/repo";
        name = "runner2";
        tokenFile = "/secrets/token2";
      };
    };
    default = { };
    type = types.attrsOf (types.submodule ({ name, ... }: {
      options = {
        enable = mkOption {
          default = false;
          example = true;
          description = ''
            Whether to enable GitHub Actions runner.

            Note: GitHub recommends using self-hosted runners with private repositories only. Learn more here:
            [About self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners/about-self-hosted-runners).
          '';
          type = types.bool;
        };

        url = mkOption {
          type = types.str;
          description = ''
            Repository to add the runner to.

            Changing this option triggers a new runner registration.

            IMPORTANT: If your token is org-wide (not per repository), you need to
            provide a github org link, not a single repository, so do it like this
            `https://github.com/nixos`, not like this
            `https://github.com/nixos/nixpkgs`.
            Otherwise, you are going to get a `404 NotFound`
            from `POST https://api.github.com/actions/runner-registration`
            in the configure script.
          '';
          example = "https://github.com/nixos/nixpkgs";
        };

        tokenFile = mkOption {
          type = types.path;
          description = ''
            The full path to a file which contains either

            * a fine-grained personal access token (PAT),
            * a classic PAT
            * or a runner registration token

            Changing this option or the `tokenFile`’s content triggers a new runner registration.

            You can also manually trigger a new runner registration by deleting
            {file}`/var/lib/github-runners/<name>/.runner` and restarting the service.

            We suggest using the fine-grained PATs. A runner registration token is valid
            only for 1 hour after creation, so the next time the runner configuration changes
            this will give you hard-to-debug HTTP 404 errors in the configure step.

            The file should contain exactly one line with the token without any newline.
            (Use `echo -n '…token…' > …token file…` to make sure no newlines sneak in.)

            If the file contains a PAT, the service creates a new registration token
            on startup as needed.
            If a registration token is given, it can be used to re-register a runner of the same
            name but is time-limited as noted above.

            For fine-grained PATs:

            Give it "Read and Write access to organization/repository self hosted runners",
            depending on whether it is organization wide or per-repository. You might have to
            experiment a little, fine-grained PATs are a `beta` Github feature and still subject
            to change; nonetheless they are the best option at the moment.

            For classic PATs:

            Make sure the PAT has a scope of `admin:org` for organization-wide registrations
            or a scope of `repo` for a single repository.

            For runner registration tokens:

            Nothing special needs to be done, but updating will break after one hour,
            so these are not recommended.
          '';
          example = "/run/secrets/github-runner/nixos.token";
        };

        name = mkOption {
          type = types.nullOr types.str;
          description = ''
            Name of the runner to configure. If null, defaults to the hostname.

            Changing this option triggers a new runner registration.
          '';
          example = "nixos";
          default = name;
        };

        runnerGroup = mkOption {
          type = types.nullOr types.str;
          description = ''
            Name of the runner group to add this runner to (defaults to the default runner group).

            Changing this option triggers a new runner registration.
          '';
          default = null;
        };

        extraLabels = mkOption {
          type = types.listOf types.str;
          description = ''
            Extra labels in addition to the default (unless disabled through the `noDefaultLabels` option).

            Changing this option triggers a new runner registration.
          '';
          example = literalExpression ''[ "nixos" ]'';
          default = [ ];
        };

        noDefaultLabels = mkOption {
          type = types.bool;
          description = ''
            Disables adding the default labels. Also see the `extraLabels` option.

            Changing this option triggers a new runner registration.
          '';
          default = false;
        };

        replace = mkOption {
          type = types.bool;
          description = ''
            Replace any existing runner with the same name.

            Without this flag, registering a new runner with the same name fails.
          '';
          default = false;
        };

        extraPackages = mkOption {
          type = types.listOf types.package;
          description = ''
            Extra packages to add to `PATH` of the service to make them available to workflows.
          '';
          default = [ ];
        };

        extraEnvironment = mkOption {
          type = types.attrs;
          description = ''
            Extra environment variables to set for the runner, as an attrset.
          '';
          example = {
            GIT_CONFIG = "/path/to/git/config";
          };
          default = { };
        };

        serviceOverrides = mkOption {
          type = types.attrs;
          description = ''
            Modify the service. Can be used to, e.g., adjust the sandboxing options.
          '';
          default = { };
        };

        package = mkPackageOption pkgs "github-runner" { };

        ephemeral = mkOption {
          type = types.bool;
          description = ''
            If enabled, causes the following behavior:

            - Passes the `--ephemeral` flag to the runner configuration script
            - De-registers and stops the runner with GitHub after it has processed one job
            - Restarts the service after its successful exit
            - On start, wipes the state directory and configures a new runner

            You should only enable this option if `tokenFile` points to a file which contains a
            personal access token (PAT). If you're using the option with a registration token, restarting the
            service will fail as soon as the registration token expired.

            Changing this option triggers a new runner registration.
          '';
          default = false;
        };

        user = mkOption {
          type = types.nullOr types.str;
          description = ''
            User under which to run the service.

            If this option and the `group` option is set to `null`, nix-darwin creates
            the `github-runner` user and group.
          '';
          defaultText = literalExpression "username";
          default = null;
        };

        group = mkOption {
          type = types.nullOr types.str;
          description = ''
            Group under which to run the service.

            If this option and the `user` option is set to `null`, nix-darwin creates
            the `github-runner` user and group.
          '';
          defaultText = literalExpression "groupname";
          default = null;
        };

        workDir = mkOption {
          type = with types; nullOr str;
          description = ''
            Working directory, available as `$GITHUB_WORKSPACE` during workflow runs
            and used as a default for [repository checkouts](https://github.com/actions/checkout).
            The service cleans this directory on every service start.

            Changing this option triggers a new runner registration.
          '';
          default = null;
        };

        nodeRuntimes = mkOption {
          type = with types; nonEmptyListOf (enum [ "node20" "node24" ]);
          default = [ "node20" "node24" ];
          description = ''
            List of Node.js runtimes the runner should support.
          '';
        };
      };
    }));
  };
}
