{ config, lib, pkgs, ... }:
with builtins;
with lib;
let
  cfg = config.services.gitlab-runner;
  hasDocker = config.virtualisation.docker.enable;
  # config.toml is generated directly with tomlq (a real TOML serializer), a pure
  # function of these options and the one value not known at build time: each
  # runner's token, taken from its registrationConfigFile at runtime and so kept
  # out of the store. gitlab-runner run reads and runs whatever [[runners]] the
  # file defines (https://docs.gitlab.com/runner/commands/), so a modern
  # authentication token (glrt-) needs no registration step: it authenticates on
  # its own and the runner fills in its id and system_id from the server on
  # startup. A deprecated registration token, which register still accepts, is
  # exchanged for a runner token by a one-time register in the configure script
  # below; a runner's server-side attributes (tags, run_untagged, access_level,
  # maximum_timeout) are stored there, the only place they take for either token
  # type (https://docs.gitlab.com/runner/register/).

  # An attribute set as a config.toml fragment: drop null-valued attributes (TOML
  # has no null, so an unset optional must not appear) and render the rest as a
  # JSON object literal, which is also a jq expression. tomlq (-n, null input)
  # serializes that to TOML, nested [runners.docker] table and arrays included, so
  # nothing is hand-assembled.
  tomlObject = attrs: toJSON (filterAttrs (_: v: v != null) attrs);

  globalObject = tomlObject {
    concurrent = cfg.concurrent;
    check_interval = cfg.checkInterval;
    sentry_dsn = cfg.sentryDSN;
    listen_address = cfg.prometheusListenAddress;
    session_server = filterAttrs (_: v: v != null) {
      session_timeout = cfg.sessionServer.sessionTimeout;
      listen_address = cfg.sessionServer.listenAddress;
      advertise_address = cfg.sessionServer.advertiseAddress;
    };
  };

  # A runner's [[runners]] entry as a jq object, minus the name, url, and token
  # the configure script splices in at runtime (the name because it is hashed for
  # a legacy runner and plain for an authentication-token one).
  runnerObject = service: tomlObject {
    executor = service.executor;
    limit = service.limit;
    request_concurrency = service.requestConcurrency;
    debug_trace_disabled = service.debugTraceDisabled;
    environment = mapAttrsToList (n: v: "${n}=${v}") service.environmentVariables;
    builds_dir = service.buildsDir;
    clone_url = service.cloneUrl;
    pre_clone_script = service.preCloneScript;
    pre_build_script = service.preBuildScript;
    post_build_script = service.postBuildScript;
    docker =
      if hasPrefix "docker" service.executor
      then (
        assert assertMsg (service.dockerImage != null)
          "services.gitlab-runner.services.${service.executor} needs dockerImage for the docker executor";
        {
          image = service.dockerImage;
          disable_cache = service.dockerDisableCache;
          privileged = service.dockerPrivileged;
          volumes = service.dockerVolumes;
          extra_hosts = service.dockerExtraHosts;
          allowed_images = service.dockerAllowedImages;
          allowed_services = service.dockerAllowedServices;
        }
      )
      else null;
  };

  # A legacy runner's identity on GitLab is exactly what register stores
  # server-side; a change to any of it is a different runner that must be
  # re-registered, and nothing else (an environment, a limit, a volume) is. The
  # runner is named over just these fields so that a server-side change moves the
  # name (forcing a re-register and sweeping the old one) while a local change
  # leaves it, and so reloads config.toml without re-registering.
  runnerIdentity = service: {
    inherit (service)
      registrationConfigFile registrationFlags
      tagList runUntagged protected maximumTimeout;
  };
  legacyName = name: service:
    "${name}_${config.networking.hostName}_${
      substring 0 12
      (hashString "md5" (unsafeDiscardStringContext
        (toJSON (runnerIdentity service))))}";

  # The attributes register stores server-side when it exchanges a deprecated
  # registration token. An authentication token has these set at creation, so
  # register ignores them there; they are never config.toml fields.
  registrationServerFlags = service:
    optional (service.tagList != [ ]) "--tag-list ${escapeShellArg (concatStringsSep "," service.tagList)}"
    ++ optional service.runUntagged "--run-untagged"
    ++ optional service.protected "--access-level ref_protected"
    ++ optional (service.maximumTimeout > 0) "--maximum-timeout ${toString service.maximumTimeout}"
    ++ service.registrationFlags;
  # Whether any runner uses the deprecated registration flow. Gates the register
  # tooling and the unregister sweep so an authentication-only instance carries
  # neither.
  hasLegacyRunner = any (service: service.registrationType == "registration") (attrValues cfg.services);
  # The runner names this configuration registers on GitLab (the deprecated
  # registration flow only). The unregister sweep keeps GitLab to exactly these.
  legacyNames = mapAttrsToList (name: service: legacyName name service)
    (filterAttrs (_: service: service.registrationType == "registration") cfg.services);
  configPath = "$HOME/.gitlab-runner/config.toml";
  configureScript = pkgs.writeShellScriptBin "gitlab-runner-configure" (
    if (cfg.configFile != null) then ''
      mkdir -p $(dirname ${configPath})
      cp ${cfg.configFile} ${configPath}
      # make config file readable by service
      chown -R --reference=$HOME $(dirname ${configPath})
    '' else ''
      set -e
      mkdir -p "$(dirname ${configPath})"
      ${optionalString hasLegacyRunner ''
      # Unregister dropped legacy runners, the base module's OLD_SERVICES: a
      # runner in config.toml named by our "<name>_<host>_<hash>" convention that
      # this rebuild no longer registers (a removed service, or a server-side
      # change that moved the hash). Registered names are read with tomlq rather
      # than parsed out of `gitlab-runner list`, and scoped to our naming so an
      # operator-owned authentication runner (plain name) is never touched.
      tomlq -r '.runners[]?.name' "${configPath}" 2>/dev/null | while read -r registered_name; do
        case "$registered_name" in
          *_${config.networking.hostName}_????????????)
            printf '%s\n' ${escapeShellArg (concatStringsSep "\n" legacyNames)} | grep -qxF -- "$registered_name" \
              || gitlab-runner unregister --config "${configPath}" --name "$registered_name" || true ;;
        esac
      done
      ''}
      # Generate config.toml with tomlq. url and token are the only runtime
      # values, sourced from each runner's registrationConfigFile. Whether a
      # runner uses an authentication token or a deprecated registration token is
      # declared per runner (registrationType), so this branch is resolved at
      # build time and runners of either kind share one config.toml.
      {
        tomlq -n -t ${escapeShellArg globalObject}
      ${concatStringsSep "\n" (mapAttrsToList (name: service: ''
        (
          . ${service.registrationConfigFile}
        ${if service.registrationType == "registration" then ''
          # Deprecated registration token: register exchanges it for a runner
          # token (reused from config.toml on later rebuilds, so only a
          # server-side change, which moves the hashed name, re-registers) and
          # stores the server-side attributes. https://docs.gitlab.com/runner/register/
          runner_name=${escapeShellArg (legacyName name service)}
          runner_token="$(tomlq -r ${escapeShellArg "[.runners[]? | select(.name == ${toJSON (legacyName name service)}) | .token][0] // empty"} "${configPath}" 2>/dev/null || true)"
          if [ -z "$runner_token" ]; then
            scratch="$(mktemp -d)"
            gitlab-runner register --config "$scratch/config.toml" --non-interactive \
              --url "$CI_SERVER_URL" --registration-token "$REGISTRATION_TOKEN" \
              --name "$runner_name" --executor ${escapeShellArg service.executor} \
              ${concatStringsSep " " (registrationServerFlags service)}
            runner_token="$(tomlq -r '.runners[0].token' "$scratch/config.toml")"
            rm -rf "$scratch"
          fi
        '' else ''
          # Authentication token: written to config.toml as-is, no register; the
          # runner self-binds on run.
          runner_name=${escapeShellArg name}
          runner_token="$REGISTRATION_TOKEN"
        ''}
          tomlq -n -t --arg name "$runner_name" --arg url "$CI_SERVER_URL" --arg token "$runner_token" \
            ${escapeShellArg "{runners: [${runnerObject service} + {name: $name, url: $url, token: $token}]}"}
        )'') cfg.services)}
      } > "${configPath}.new"
      mv "${configPath}.new" "${configPath}"

      # make config file readable by service
      chown -R --reference="$HOME" "$(dirname ${configPath})"
    '');
  # seamlessRestart makes a runner able to deploy the host it runs on. Its plist
  # is made immutable (below, it embeds the /run/current-system profile, not
  # store paths), so activation never reloads it (the plist never differs across
  # closures) and the switch it runs never tears it down mid-job; it picks up
  # each new deployment on its own graceful restart, running the current-system
  # gitlab-runner rather than a pinned /nix/store path so that restart lands the
  # deployed version.
  selfDeploy = cfg.seamlessRestart;
  runnerExec =
    if selfDeploy
    then "/run/current-system/sw/bin/gitlab-runner"
    else "${cfg.package}/bin/gitlab-runner";
  startScript = pkgs.writeShellScriptBin "gitlab-runner-start" (
    if cfg.gracefulTermination then ''
      export CONFIG_FILE=${configPath}
      # launchd only ever sends SIGTERM (a forceful abort to gitlab-runner)
      # and cannot be told to send another signal, so catch it and forward
      # SIGQUIT to drain the jobs first. wait returns the moment the trapped
      # signal fires, so the wait that matters is the one in the handler,
      # after the forward. The launchd analogue of the systemd unit's
      # KillSignal = SIGQUIT.
      ${runnerExec} run --working-directory "$HOME" &
      runner=$!
      trap 'kill -QUIT "$runner" 2>/dev/null; wait "$runner"; exit' TERM QUIT INT
      wait "$runner"
    '' else ''
      export CONFIG_FILE=${configPath}
      exec ${runnerExec} run --working-directory "$HOME"
    ''
  );
  # The service definition shared by both launchd placements; HOME (and
  # with it config.toml) comes from the daemon's dedicated user or from
  # the logged-in session user respectively.
  serviceEnvironment = { #config.networking.proxy.envVars // {
    NIX_REMOTE = "daemon";
    NIX_SSL_CERT_FILE =
      if selfDeploy
      then "/run/current-system/sw/etc/ssl/certs/ca-bundle.crt"
      else "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  };
  servicePath = with pkgs; [
    bash
    gawk
    jq
    moreutils
    yq
    # util-linux
    cfg.package
    coreutils
    gnugrep
    gnused
  ] ++ cfg.extraPackages;
  # exec into the runner so gitlab-runner is the launchd job's main process,
  # not a child of the shell: launchctl kill / signals then reach it directly
  # (a configure failure still short-circuits and lets KeepAlive retry).
  serviceScript = ''
    ${configureScript}/bin/gitlab-runner-configure && exec ${startScript}/bin/gitlab-runner-start
  '';
  # In selfDeploy mode the plist must embed no /nix/store paths, so activation
  # never rewrites it and it needs no reload. Everything it names resolves
  # through the current-system profile instead: this service script is installed
  # into the system profile and run by its profile path, PATH is the profile bin
  # dir, and the CA bundle is the profile's. A fork or nixpkgs change then moves
  # only the symlink targets and the plist bytes stay identical, so one bootstrap
  # ever installs it and every later change lands on the next SIGQUIT cycle.
  serviceRunnerService = pkgs.writeShellScriptBin "gitlab-runner-service" serviceScript;
  serviceConfigCommon = {
    ProcessType = "Interactive";
    ThrottleInterval = 30;

    # StandardOutPath = "/var/lib/gitlab-runner/out.log";
    # StandardErrorPath = "/var/lib/gitlab-runner/err.log";
    # The combination of KeepAlive.NetworkState and WatchPaths
    # will ensure that buildkite-agent is started on boot, but
    # after networking is available (so the hostname is
    # correct).
    RunAtLoad = true;
    # KeepAlive.NetworkState = true;
    WatchPaths = [
      "/etc/resolv.conf"
      "/Library/Preferences/SystemConfiguration/NetworkInterfaces.plist"
    ];
  } // optionalAttrs cfg.gracefulTermination {
    # Complete the graceful stop begun by the SIGQUIT-forwarding start script:
    # AbandonProcessGroup keeps launchd from tearing down the in-flight job
    # when the runner exits (the KillMode = process analogue), and ExitTimeOut
    # = 0 lets the drain run instead of the default 20s cap (TimeoutStopSec;
    # a shutdown is still bounded by macOS).
    AbandonProcessGroup = true;
    ExitTimeOut = 0;
  };
in
{
  options.services.gitlab-runner = {
    enable = mkEnableOption "Gitlab Runner";
    launchdType = mkOption {
      type = types.enum [ "daemon" "agent" ];
      default = "daemon";
      example = "agent";
      description = ''
        The launchd service class the runner is placed in.

        `"daemon"` runs the runner as a system LaunchDaemon under the
        dedicated `gitlab-runner` user, with no access to any GUI
        session. This fits session-independent workloads, for example
        nix or Android builds.

        `"agent"` runs the runner as a LaunchAgent in the logged-in
        session of {option}`system.primaryUser`, which GitLab documents
        as the only supported mode on macOS
        (<https://docs.gitlab.com/runner/install/osx/>).
        Session-dependent workloads require it: code signing against
        the login keychain and the iOS Simulator. Jobs only run while
        that user's session exists, so pair it with automatic login on
        a dedicated CI host.
      '';
    };
    seamlessRestart = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether the runner can deploy the nix-darwin configuration of the
        host it runs on, for example a CI job that runs `darwin-rebuild
        switch` on this machine.

        When `true` the runner's launchd plist embeds no `/nix/store` paths:
        it runs the `gitlab-runner` on the `/run/current-system` profile and
        resolves its config and CA bundle through that profile. The plist is
        therefore immutable across closures, so activation never reloads the
        runner (the switch it runs cannot tear it down mid-job) and the runner
        picks up each new deployment on its own graceful restart, which the
        deploy triggers with `launchctl kill SIGQUIT`. Pair it with
        {option}`services.gitlab-runner.gracefulTermination` so that restart
        drains the running job rather than aborting it.
      '';
    };
    configFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Configuration file for gitlab-runner.

        {option}`configFile` takes precedence over {option}`services`.
        {option}`checkInterval` and {option}`concurrent` will be ignored too.

        This option is deprecated, please use {option}`services` instead.
        You can use {option}`registrationConfigFile` and
        {option}`registrationFlags`
        for settings not covered by this module.
      '';
    };
    checkInterval = mkOption {
      type = types.int;
      default = 0;
      example = literalExpression "with lib; (length (attrNames config.services.gitlab-runner.services)) * 3";
      description = ''
        Defines the interval length, in seconds, between new jobs check.
        The default value is 3;
        if set to 0 or lower, the default value will be used.
        See [runner documentation](https://docs.gitlab.com/runner/configuration/advanced-configuration.html#how-check_interval-works) for more information.
      '';
    };
    concurrent = mkOption {
      type = types.int;
      default = 1;
      example = literalExpression "config.nix.maxJobs";
      description = ''
        Limits how many jobs globally can be run concurrently.
        The most upper limit of jobs using all defined runners.
        0 does not mean unlimited.
      '';
    };
    sentryDSN = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "https://public:private@host:port/1";
      description = ''
        Data Source Name for tracking of all system level errors to Sentry.
      '';
    };
    prometheusListenAddress = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "localhost:8080";
      description = ''
        Address (&lt;host&gt;:&lt;port&gt;) on which the Prometheus metrics HTTP server
        should be listening.
      '';
    };
    sessionServer = mkOption {
      type = types.submodule {
        options = {
          listenAddress = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "0.0.0.0:8093";
            description = ''
              An internal URL to be used for the session server.
            '';
          };
          advertiseAddress = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "runner-host-name.tld:8093";
            description = ''
              The URL that the Runner will expose to GitLab to be used
              to access the session server.
              Fallbacks to {option}`listenAddress` if not defined.
            '';
          };
          sessionTimeout = mkOption {
            type = types.int;
            default = 1800;
            description = ''
              How long in seconds the session can stay active after
              the job completes (which will block the job from finishing).
            '';
          };
        };
      };
      default = { };
      example = literalExpression ''
        {
          listenAddress = "0.0.0.0:8093";
        }
      '';
      description = ''
        The session server allows the user to interact with jobs
        that the Runner is responsible for. A good example of this is the
        [interactive web terminal](https://docs.gitlab.com/ee/ci/interactive_web_terminal/index.html).
      '';
    };
    gracefulTermination = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Finish all remaining jobs before stopping.
        If not set gitlab-runner will stop immediatly without waiting
        for jobs to finish, which will lead to failed builds.

        On darwin, where launchd always sends SIGTERM (a forceful abort to
        gitlab-runner) and offers no way to change that signal, this runs the
        runner under a SIGQUIT-forwarding start script plus
        {var}`AbandonProcessGroup` and an unbounded {var}`ExitTimeOut`, so a
        launchd-initiated stop drains its jobs first. The launchd analogue of
        the systemd unit's KillSignal = SIGQUIT, KillMode = process and
        TimeoutStopSec.
      '';
    };
    gracefulTimeout = mkOption {
      type = types.str;
      default = "infinity";
      example = "5min 20s";
      description = ''
        Time to wait until a graceful shutdown is turned into a forceful one.
      '';
    };
    package = mkOption {
      type = types.package;
      default = pkgs.gitlab-runner;
      defaultText = "pkgs.gitlab-runner";
      example = literalExpression "pkgs.gitlab-runner_1_11";
      description = "Gitlab Runner package to use.";
    };
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = ''
        Extra packages to add to PATH for the gitlab-runner process.
      '';
    };
    services = mkOption {
      description = "GitLab Runner services.";
      default = { };
      example = literalExpression ''
        {
          # runner for building in docker via host's nix-daemon
          # nix store will be readable in runner, might be insecure
          nix = {
            # File should contain at least these two variables:
            # `CI_SERVER_URL`
            # `REGISTRATION_TOKEN`
            registrationConfigFile = "/run/secrets/gitlab-runner-registration";
            dockerImage = "alpine";
            dockerVolumes = [
              "/nix/store:/nix/store:ro"
              "/nix/var/nix/db:/nix/var/nix/db:ro"
              "/nix/var/nix/daemon-socket:/nix/var/nix/daemon-socket:ro"
            ];
            dockerDisableCache = true;
            preBuildScript = pkgs.writeScript "setup-container" '''
              mkdir -p -m 0755 /nix/var/log/nix/drvs
              mkdir -p -m 0755 /nix/var/nix/gcroots
              mkdir -p -m 0755 /nix/var/nix/profiles
              mkdir -p -m 0755 /nix/var/nix/temproots
              mkdir -p -m 0755 /nix/var/nix/userpool
              mkdir -p -m 1777 /nix/var/nix/gcroots/per-user
              mkdir -p -m 1777 /nix/var/nix/profiles/per-user
              mkdir -p -m 0755 /nix/var/nix/profiles/per-user/root
              mkdir -p -m 0700 "$HOME/.nix-defexpr"

              . ''${pkgs.nix}/etc/profile.d/nix.sh

              ''${pkgs.nix}/bin/nix-env -i ''${concatStringsSep " " (with pkgs; [ nix cacert git openssh ])}

              ''${pkgs.nix}/bin/nix-channel --add https://nixos.org/channels/nixpkgs-unstable
              ''${pkgs.nix}/bin/nix-channel --update nixpkgs
            ''';
            environmentVariables = {
              ENV = "/etc/profile";
              USER = "root";
              NIX_REMOTE = "daemon";
              PATH = "/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin:/bin:/sbin:/usr/bin:/usr/sbin";
              NIX_SSL_CERT_FILE = "/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt";
            };
            tagList = [ "nix" ];
          };
          # runner for building docker images
          docker-images = {
            # File should contain at least these two variables:
            # `CI_SERVER_URL`
            # `REGISTRATION_TOKEN`
            registrationConfigFile = "/run/secrets/gitlab-runner-registration";
            dockerImage = "docker:stable";
            dockerVolumes = [
              "/var/run/docker.sock:/var/run/docker.sock"
            ];
            tagList = [ "docker-images" ];
          };
          # runner for executing stuff on host system (very insecure!)
          # make sure to add required packages (including git!)
          # to `environment.systemPackages`
          shell = {
            # File should contain at least these two variables:
            # `CI_SERVER_URL`
            # `REGISTRATION_TOKEN`
            registrationConfigFile = "/run/secrets/gitlab-runner-registration";
            executor = "shell";
            tagList = [ "shell" ];
          };
          # runner for everything else
          default = {
            # File should contain at least these two variables:
            # `CI_SERVER_URL`
            # `REGISTRATION_TOKEN`
            registrationConfigFile = "/run/secrets/gitlab-runner-registration";
            dockerImage = "debian:stable";
          };
        }
      '';
      type = types.attrsOf (types.submodule {
        options = {
          registrationConfigFile = mkOption {
            type = types.path;
            description = ''
              Absolute path to a file with environment variables
              used for gitlab-runner registration.
              A list of all supported environment variables can be found in
              `gitlab-runner register --help`.

              Ones that you probably want to set is

              `CI_SERVER_URL=<CI server URL>`

              `REGISTRATION_TOKEN=<registration secret>`
            '';
          };
          registrationType = mkOption {
            type = types.enum [ "authentication" "registration" ];
            default = "authentication";
            description = ''
              The kind of token {option}`registrationConfigFile` provides.

              `"authentication"` (the default) treats it as a runner
              authentication token (the `glrt-` prefix), created for the runner
              in the GitLab UI or API. config.toml is written with the token
              directly and the runner authenticates on its own; no
              `gitlab-runner register` runs. From GitLab 18.0 this is the only
              supported token type.

              `"registration"` treats it as a deprecated registration token,
              which `gitlab-runner register` exchanges for a runner token,
              setting the runner's server-side attributes ({option}`tagList`,
              {option}`runUntagged`, {option}`protected`,
              {option}`maximumTimeout`) at creation.

              Runners of either type can share one instance.
            '';
          };
          registrationFlags = mkOption {
            type = types.listOf types.str;
            default = [ ];
            example = [ "--docker-helper-image my/gitlab-runner-helper" ];
            description = ''
              Extra command-line flags passed to
              `gitlab-runner register`.
              Execute `gitlab-runner register --help`
              for a list of supported flags.
            '';
          };
          environmentVariables = mkOption {
            type = types.attrsOf types.str;
            default = { };
            example = { NAME = "value"; };
            description = ''
              Custom environment variables injected to build environment.
              For secrets you can use {option}`registrationConfigFile`
              with `RUNNER_ENV` variable set.
            '';
          };
          executor = mkOption {
            type = types.str;
            default = "docker";
            description = ''
              Select executor, eg. shell, docker, etc.
              See [runner documentation](https://docs.gitlab.com/runner/executors/README.html) for more information.
            '';
          };
          buildsDir = mkOption {
            type = types.nullOr types.path;
            default = null;
            example = "/var/lib/gitlab-runner/builds";
            description = ''
              Absolute path to a directory where builds will be stored
              in context of selected executor (Locally, Docker, SSH).
            '';
          };
          cloneUrl = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "http://gitlab.example.local";
            description = ''
              Overwrite the URL for the GitLab instance. Used if the Runner can’t connect to GitLab on the URL GitLab exposes itself.
            '';
          };
          dockerImage = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Docker image to be used.
            '';
          };
          dockerVolumes = mkOption {
            type = types.listOf types.str;
            default = [ ];
            example = [ "/var/run/docker.sock:/var/run/docker.sock" ];
            description = ''
              Bind-mount a volume and create it
              if it doesn't exist prior to mounting.
            '';
          };
          dockerDisableCache = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Disable all container caching.
            '';
          };
          dockerPrivileged = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Give extended privileges to container.
            '';
          };
          dockerExtraHosts = mkOption {
            type = types.listOf types.str;
            default = [ ];
            example = [ "other-host:127.0.0.1" ];
            description = ''
              Add a custom host-to-IP mapping.
            '';
          };
          dockerAllowedImages = mkOption {
            type = types.listOf types.str;
            default = [ ];
            example = [ "ruby:*" "python:*" "php:*" "my.registry.tld:5000/*:*" ];
            description = ''
              Whitelist allowed images.
            '';
          };
          dockerAllowedServices = mkOption {
            type = types.listOf types.str;
            default = [ ];
            example = [ "postgres:9" "redis:*" "mysql:*" ];
            description = ''
              Whitelist allowed services.
            '';
          };
          preCloneScript = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = ''
              Runner-specific command script executed before code is pulled.
            '';
          };
          preBuildScript = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = ''
              Runner-specific command script executed after code is pulled,
              just before build executes.
            '';
          };
          postBuildScript = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = ''
              Runner-specific command script executed after code is pulled
              and just after build executes.
            '';
          };
          tagList = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = ''
              Tag list.
            '';
          };
          runUntagged = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Register to run untagged builds; defaults to
              `true` when {option}`tagList` is empty.
            '';
          };
          limit = mkOption {
            type = types.int;
            default = 0;
            description = ''
              Limit how many jobs can be handled concurrently by this service.
              0 (default) simply means don't limit.
            '';
          };
          requestConcurrency = mkOption {
            type = types.int;
            default = 0;
            description = ''
              Limit number of concurrent requests for new jobs from GitLab.
            '';
          };
          maximumTimeout = mkOption {
            type = types.int;
            default = 0;
            description = ''
              What is the maximum timeout (in seconds) that will be set for
              job when using this Runner. 0 (default) simply means don't limit.
            '';
          };
          protected = mkOption {
            type = types.bool;
            default = false;
            description = ''
              When set to true Runner will only run on pipelines
              triggered on protected branches.
            '';
          };
          debugTraceDisabled = mkOption {
            type = types.bool;
            default = false;
            description = ''
              When set to true Runner will disable the possibility of
              using the `CI_DEBUG_TRACE` feature.
            '';
          };
        };
      });
    };
  };
  config = mkIf cfg.enable (mkMerge [ {

    warnings = optional (cfg.configFile != null) "services.gitlab-runner.`configFile` is deprecated, please use services.gitlab-runner.`services`.";
    environment.systemPackages = [ cfg.package ]
      ++ optionals selfDeploy (servicePath ++ [ serviceRunnerService pkgs.cacert ]);
  }

  (mkIf (cfg.launchdType == "daemon") {
    users.users.gitlab-runner =
      { name = "gitlab-runner";
        uid = mkDefault 532;
        # gid = mkDefault config.users.groups.gitlab-runner.gid;
        home = mkDefault "/var/lib/gitlab-runner";
        shell = "/bin/bash";
        description = "Gitlab agent user";
      };
    users.groups.gitlab-runner =
      { name = "gitlab-runner";
        gid = mkDefault 532;
        description = "Gitlab agent user group";
      };


    # system.activationScripts.preActivation.text = let user = config.users.users.gitlab-runner; in ''
    #  mkdir -p '${user.home}'
    #  chown ${toString user.uid}:${toString user.gid} '${user.home}'
    #'';

    launchd.daemons.gitlab-runner = {
      environment = serviceEnvironment // {
        HOME = "${config.users.users.gitlab-runner.home}";
      } // optionalAttrs selfDeploy { PATH = "/run/current-system/sw/bin"; };
      path = if selfDeploy then [ ] else servicePath;
      command = if selfDeploy then "/run/current-system/sw/bin/gitlab-runner-service" else "";
      script = if selfDeploy then "" else serviceScript;
      serviceConfig = serviceConfigCommon // optionalAttrs selfDeploy {
        KeepAlive = true;
      } // {
        GroupName = "gitlab-runner";
        UserName  = "gitlab-runner";
        WorkingDirectory = config.users.users.gitlab-runner.home;
      };
    };
  })

  (mkIf (cfg.launchdType == "agent") {
    launchd.user.agents.gitlab-runner = {
      environment = serviceEnvironment // optionalAttrs selfDeploy { PATH = "/run/current-system/sw/bin"; };
      path = if selfDeploy then [ ] else servicePath;
      command = if selfDeploy then "/run/current-system/sw/bin/gitlab-runner-service" else "";
      script = if selfDeploy then "" else serviceScript;
      managedBy = "services.gitlab-runner.launchdType";
      serviceConfig = serviceConfigCommon // {
        # GitLab's documented LaunchAgent sets SessionCreate so code signing can
        # reach the login keychain. It normally restarts the runner only on an
        # unsuccessful exit; a selfDeploy runner exits cleanly on its graceful
        # drain and must relaunch, so it keeps KeepAlive on.
        # https://docs.gitlab.com/runner/install/osx/
        SessionCreate = true;
        KeepAlive = if selfDeploy then true else { SuccessfulExit = false; };
      };
    };
  })
    # systemd.services.gitlab-runner = {
    #   description = "Gitlab Runner";
    #   documentation = [ "https://docs.gitlab.com/runner/" ];
    #   after = [ "network.target" ]
    #     ++ optional hasDocker "docker.service";
    #   requires = optional hasDocker "docker.service";
    #   wantedBy = [ "multi-user.target" ];
    #   environment = config.networking.proxy.envVars // {
    #     HOME = "/var/lib/gitlab-runner";
    #   };
    #   path = with pkgs; [
    #     bash
    #     gawk
    #     jq
    #     moreutils
    #     remarshal
    #     util-linux
    #     cfg.package
    #   ] ++ cfg.extraPackages;
    #   reloadIfChanged = true;
    #   serviceConfig = {
    #     # Set `DynamicUser` under `systemd.services.gitlab-runner.serviceConfig`
    #     # to `lib.mkForce false` in your configuration to run this service as root.
    #     # You can also set `User` and `Group` options to run this service as desired user.
    #     # Make sure to restart service or changes won't apply.
    #     DynamicUser = true;
    #     StateDirectory = "gitlab-runner";
    #     SupplementaryGroups = optional hasDocker "docker";
    #     ExecStartPre = "!${configureScript}/bin/gitlab-runner-configure";
    #     ExecStart = "${startScript}/bin/gitlab-runner-start";
    #     ExecReload = "!${configureScript}/bin/gitlab-runner-configure";
    #   } // optionalAttrs (cfg.gracefulTermination) {
    #     TimeoutStopSec = "${cfg.gracefulTimeout}";
    #     KillSignal = "SIGQUIT";
    #     KillMode = "process";
    #   };
    # };
    # # Enable docker if `docker` executor is used in any service
    # virtualisation.docker.enable = mkIf (
    #   any (s: s.executor == "docker") (attrValues cfg.services)
    # ) (mkDefault true);
  ]);
  imports = [
    (mkRenamedOptionModule [ "services" "gitlab-runner" "packages" ] [ "services" "gitlab-runner" "extraPackages" ] )
    (mkRemovedOptionModule [ "services" "gitlab-runner" "configOptions" ] "Use services.gitlab-runner.services option instead" )
    (mkRemovedOptionModule [ "services" "gitlab-runner" "workDir" ] "You should move contents of workDir (if any) to /var/lib/gitlab-runner" )
  ];
}
