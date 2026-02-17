# Based off: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/misc/nix-daemon.nix
# When making changes please try to keep it in sync and keep the diff NixOS module clean.
{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.nix;

  nixPackage = cfg.package.out;

  isNixAtLeast = versionAtLeast (getVersion nixPackage);

  configureBuildUsers = !(config.nix.settings.auto-allocate-uids or false);

  makeNixBuildUser = nr: {
    name = "_nixbld${toString nr}";
    value = {
      description = "Nix build user ${toString nr}";

      /*
        For consistency with the setgid(2), setuid(2), and setgroups(2)
        calls in `libstore/build.cc', don't add any supplementary group
        here except "nixbld".
      */
      uid = builtins.add config.ids.uids.nixbld nr;
      gid = config.ids.gids.nixbld;
    };
  };

  nixbldUsers = listToAttrs (map makeNixBuildUser (range 1 cfg.nrBuildUsers));

  nixConf =
    assert isNixAtLeast "2.2";
    let

      mkValueString = v:
        if v == null then ""
        else if isInt v then toString v
        else if isBool v then boolToString v
        else if isFloat v then strings.floatToString v
        else if isList v then toString v
        else if isDerivation v then toString v
        else if builtins.isPath v then toString v
        else if isString v then v
        else if isCoercibleToString v then toString v
        else abort "The nix conf value: ${toPretty {} v} can not be encoded";

      mkKeyValue = k: v: "${escape [ "=" ] k} = ${mkValueString v}";

      mkKeyValuePairs = attrs: concatStringsSep "\n" (mapAttrsToList mkKeyValue attrs);

      isExtra = key: hasPrefix "extra-" key;

    in
    pkgs.writeTextFile {
      name = "nix.conf";
      text = ''
        # WARNING: this file is generated from the nix.* options in
        # your nix-darwin configuration. Do not edit it!
        ${mkKeyValuePairs (filterAttrs (key: value: !(isExtra key)) cfg.settings)}
        ${mkKeyValuePairs (filterAttrs (key: value: isExtra key) cfg.settings)}
        ${cfg.extraOptions}
      '';
      checkPhase =
        if pkgs.stdenv.hostPlatform != pkgs.stdenv.buildPlatform then ''
          echo "Ignoring validation for cross-compilation"
        ''
        else
        let
          showCommand = if isNixAtLeast "2.20pre" then "config show" else "show-config";
        in
        ''
          echo "Validating generated nix.conf"
          ln -s $out ./nix.conf
          set -e
          set +o pipefail
          NIX_CONF_DIR=$PWD \
            ${cfg.package}/bin/nix ${showCommand} ${optionalString (isNixAtLeast "2.3pre") "--no-net"} \
              ${optionalString (isNixAtLeast "2.4pre") "--option experimental-features nix-command"} \
            |& sed -e 's/^warning:/error:/' \
            | (! grep '${if cfg.checkConfig then "^error:" else "^error: unknown setting"}')
          set -o pipefail
        '';
    };

  legacyConfMappings = {
    useSandbox = "sandbox";
    buildCores = "cores";
    maxJobs = "max-jobs";
    sandboxPaths = "extra-sandbox-paths";
    binaryCaches = "substituters";
    trustedBinaryCaches = "trusted-substituters";
    binaryCachePublicKeys = "trusted-public-keys";
    autoOptimiseStore = "auto-optimise-store";
    requireSignedBinaryCaches = "require-sigs";
    trustedUsers = "trusted-users";
    allowedUsers = "allowed-users";
    # systemFeatures = "system-features";
  };

  semanticConfType = with types;
    let
      confAtom = nullOr
        (oneOf [
          bool
          int
          float
          str
          path
          package
        ]) // {
        description = "Nix config atom (null, bool, int, float, str, path or package)";
      };
    in
    attrsOf (either confAtom (listOf confAtom));

  # Not in NixOS module
  nixPathType = mkOptionType {
    name = "nix path";
    merge = loc: defs:
      let
        values = flatten (map (def:
          (map (x:
            if isAttrs x then (mapAttrsToList nameValuePair x)
            else if isString x then x
            else throw "The option value `${showOption loc}` in `${def.file}` is not a attset or string.")
            (if isList def.value then def.value else [def.value]))) defs);

        namedPaths = mapAttrsToList (n: v: "${n}=${(head v).value}")
          (zipAttrs
            (map (x: { "${x.name}" = { inherit (x) value; }; })
            (filter isAttrs values)));

        searchPaths = unique
          (filter isString values);
      in
        namedPaths ++ searchPaths;
  };

  handleUnmanaged = managedConfig: mkMerge [
    (mkIf cfg.enable managedConfig)
    (mkIf (!cfg.enable) {
      system.activationScripts.nix-daemon.text = ''
        # Restore unmanaged Nix daemon if present
        unmanagedNixProfile=/nix/var/nix/profiles/default
        if [[
          -e /run/current-system/Library/LaunchDaemons/org.nixos.nix-daemon.plist
          && -e $unmanagedNixProfile/Library/LaunchDaemons/org.nixos.nix-daemon.plist
        ]]; then
          printf >&2 'restoring unmanaged Nix daemon...\n'
          cp \
            "$unmanagedNixProfile/Library/LaunchDaemons/org.nixos.nix-daemon.plist" \
            /Library/LaunchDaemons
          launchctl load -w /Library/LaunchDaemons/org.nixos.nix-daemon.plist
        fi
      '';
    })
  ];

  managedDefault = name: default: {
    default = if cfg.enable then default else throw ''
      ${name}: accessed when `nix.enable` is off; this is a bug in
      nix-darwin or a third‐party module
    '';
    defaultText = default;
  };

in

{
  imports =
    let
      altOption = alt: "No `nix-darwin` equivalent to this NixOS option, consider using `${alt}` instead.";
      consider = alt: "Consider using `${alt}` instead.";
    in
    [
      # Only ever in NixOS
      (mkRemovedOptionModule [ "nix" "daemonCPUSchedPolicy" ] (altOption "nix.daemonProcessType"))
      (mkRemovedOptionModule [ "nix" "daemonIOSchedClass" ] (altOption "nix.daemonProcessType"))
      (mkRemovedOptionModule [ "nix" "daemonIOSchedPriority" ] (altOption "nix.daemonIOLowPriority"))
      (mkRemovedOptionModule [ "nix" "readOnlyStore" ] "No `nix-darwin` equivalent to this NixOS option.")

      # Option changes in `nix-darwin`
      (mkRemovedOptionModule [ "nix" "profile" ] "Use `nix.package` instead.")
      (mkRemovedOptionModule [ "nix" "version" ] (consider "nix.package.version"))
      (mkRenamedOptionModule [ "users" "nix" "configureBuildUsers" ] [ "nix" "configureBuildUsers" ])
      (mkRenamedOptionModule [ "users" "nix" "nrBuildUsers" ] [ "nix" "nrBuildUsers" ])
      (mkRenamedOptionModule [ "nix" "daemonIONice" ] [ "nix" "daemonIOLowPriority" ])
      (mkRemovedOptionModule [ "nix" "daemonNiceLevel" ] (consider "nix.daemonProcessType"))
      (mkRemovedOptionModule [ "nix" "useDaemon" ] ''
        nix-darwin now only supports managing multi‐user daemon
        installations of Nix.
      '')
      (mkRemovedOptionModule [ "nix" "configureBuildUsers" ] ''
        nix-darwin now manages build users unconditionally when
        `nix.enable` is on.
      '')
    ] ++ mapAttrsToList (oldConf: newConf: mkRenamedOptionModule [ "nix" oldConf ] [ "nix" "settings" newConf ]) legacyConfMappings;

  ###### interface

  options = {

    nix = {

      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to enable Nix.

          Disabling this will stop nix-darwin from managing the
          installed version of Nix, the nix-daemon launchd daemon, and
          the settings in {file}`/etc/nix/nix.conf`.

          This allows you to use nix-darwin without it taking over your
          system installation of Nix. Some nix-darwin functionality
          that relies on managing the Nix installation, like the
          `nix.*` options to adjust Nix settings or configure a Linux
          builder, will be unavailable. You will also have to upgrade
          Nix yourself, as nix-darwin will no longer do so.

          ::: {.warning}
          If you have already removed your global system installation
          of Nix, this will break nix-darwin and you will have to
          reinstall Nix to fix it.
          :::
        '';
      };

      package = mkOption {
        type = types.package;
        inherit (managedDefault "nix.package" pkgs.nix) default;
        defaultText = literalExpression "pkgs.nix";
        description = ''
          This option specifies the Nix package instance to use throughout the system.
        '';
      };

      distributedBuilds = mkOption {
        type = types.bool;
        inherit (managedDefault "nix.distributedBuilds" false) default defaultText;
        description = ''
          Whether to distribute builds to the machines listed in
          {option}`nix.buildMachines`.
        '';
      };

      # Not in NixOS module
      daemonProcessType = mkOption {
        type = types.enum [ "Background" "Standard" "Adaptive" "Interactive" ];
        inherit (managedDefault "nix.daemonProcessType" "Standard") default defaultText;
        description = ''
          Nix daemon process resource limits class. These limits propagate to
          build processes. `Standard` is the default process type
          and will apply light resource limits, throttling its CPU usage and I/O
          bandwidth.

          See {command}`man launchd.plist` for explanation of other
          process types.
        '';
      };

      # Not in NixOS module
      daemonIOLowPriority = mkOption {
        type = types.bool;
        inherit (managedDefault "nix.daemonIOLowPriority" false) default defaultText;
        description = ''
          Whether the Nix daemon process should considered to be low priority when
          doing file system I/O.
        '';
      };

      buildMachines = mkOption {
        type = types.listOf (types.submodule {
          options = {
            hostName = mkOption {
              type = types.str;
              example = "nixbuilder.example.org";
              description = ''
                The hostname of the build machine.
              '';
            };
            protocol = mkOption {
              type = types.enum [ null "ssh" "ssh-ng" ];
              default = "ssh";
              example = "ssh-ng";
              description = ''
                The protocol used for communicating with the build machine.
                Use `ssh-ng` if your remote builder and your
                local Nix version support that improved protocol.

                Use `null` when trying to change the special localhost builder
                without a protocol which is for example used by hydra.
              '';
            };
            system = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = "x86_64-linux";
              description = ''
                The system type the build machine can execute derivations on.
                Either this attribute or {var}`systems` must be
                present, where {var}`system` takes precedence if
                both are set.
              '';
            };
            systems = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = [ "x86_64-linux" "aarch64-linux" ];
              description = ''
                The system types the build machine can execute derivations on.
                Either this attribute or {var}`system` must be
                present, where {var}`system` takes precedence if
                both are set.
              '';
            };
            sshUser = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = "builder";
              description = ''
                The username to log in as on the remote host. This user must be
                able to log in and run nix commands non-interactively. It must
                also be privileged to build derivations, so must be included in
                {option}`nix.settings.trusted-users`.
              '';
            };
            sshKey = mkOption {
              type = types.nullOr types.str;
              default = null;
              example = "/root/.ssh/id_buildhost_builduser";
              description = ''
                The path to the SSH private key with which to authenticate on
                the build machine. The private key must not have a passphrase.
                If null, the building user (root on NixOS machines) must have an
                appropriate ssh configuration to log in non-interactively.

                Note that for security reasons, this path must point to a file
                in the local filesystem, *not* to the nix store.
              '';
            };
            maxJobs = mkOption {
              type = types.int;
              default = 1;
              description = ''
                The number of concurrent jobs the build machine supports. The
                build machine will enforce its own limits, but this allows hydra
                to schedule better since there is no work-stealing between build
                machines.
              '';
            };
            speedFactor = mkOption {
              type = types.int;
              default = 1;
              description = ''
                The relative speed of this builder. This is an arbitrary integer
                that indicates the speed of this builder, relative to other
                builders. Higher is faster.
              '';
            };
            mandatoryFeatures = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = [ "big-parallel" ];
              description = ''
                A list of features mandatory for this builder. The builder will
                be ignored for derivations that don't require all features in
                this list. All mandatory features are automatically included in
                {var}`supportedFeatures`.
              '';
            };
            supportedFeatures = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = [ "kvm" "big-parallel" ];
              description = ''
                A list of features supported by this builder. The builder will
                be ignored for derivations that require features not in this
                list.
              '';
            };
            publicHostKey = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = ''
                The (base64-encoded) public host key of this builder. The field
                is calculated via {command}`base64 -w0 /etc/ssh/ssh_host_type_key.pub`.
                If null, SSH will use its regular known-hosts file when connecting.
              '';
            };
          };
        });
        inherit (managedDefault "nix.buildMachines" [ ]) default defaultText;
        description = ''
          This option lists the machines to be used if distributed builds are
          enabled (see {option}`nix.distributedBuilds`).
          Nix will perform derivations on those machines via SSH by copying the
          inputs to the Nix store on the remote machine, starting the build,
          then copying the output back to the local Nix store.
        '';
      };

      # Environment variables for running Nix.
      envVars = mkOption {
        type = types.attrs;
        internal = true;
        inherit (managedDefault "nix.envVars" { }) default defaultText;
        description = "Environment variables used by Nix.";
      };

      nrBuildUsers = mkOption {
        type = types.int;
        inherit (managedDefault "nix.nrBuildUsers" 0) default defaultText;
        description = ''
          Number of `nixbld` user accounts created to
          perform secure concurrent builds.  If you receive an error
          message saying that “all build users are currently in use”,
          you should increase this value.
        '';
      };

      channel = {
        enable = mkOption {
          description = ''
            Whether the `nix-channel` command and state files are made available on the machine.

            The following files are initialized when enabled:
              - `/nix/var/nix/profiles/per-user/root/channels`
              - `$HOME/.nix-defexpr/channels` (on login)

            Disabling this option will not remove the state files from the system.
          '';
          type = types.bool;
          default = true;
        };
      };

      # Definition differs substantially from NixOS module
      nixPath = mkOption {
        type = nixPathType;
        inherit (managedDefault "nix.nixPath" (
          lib.optionals cfg.channel.enable (
            lib.optionals (config.environment.darwinConfig != null) [
              # Include default path <darwin-config>.
              { darwin-config = "${config.environment.darwinConfig}"; }
            ] ++ [
              "/nix/var/nix/profiles/per-user/root/channels"
            ]
          )
        )) default;

        defaultText = lib.literalExpression ''
          lib.optionals cfg.channel.enable [
            # Include default path <darwin-config>.
            { darwin-config = "''${config.environment.darwinConfig}"; }
            "/nix/var/nix/profiles/per-user/root/channels"
          ]
        '';
        description = ''
          The default Nix expression search path, used by the Nix
          evaluator to look up paths enclosed in angle brackets
          (e.g. `<nixpkgs>`).

          Named entries can be specified using an attribute set, if an
          entry is configured multiple times the value with the lowest
          ordering will be used.
        '';
      };

      checkConfig = mkOption {
        type = types.bool;
        inherit (managedDefault "nix.checkConfig" true) default defaultText;
        description = ''
          If enabled (the default), checks for data type mismatches and that Nix
          can parse the generated nix.conf.
        '';
      };

      registry = mkOption {
        type = types.attrsOf (types.submodule (
          let
            referenceAttrs = with types; attrsOf (oneOf [
              str
              int
              bool
              package
            ]);
          in
          { config, name, ... }:
          {
            options = {
              from = mkOption {
                type = referenceAttrs;
                example = { type = "indirect"; id = "nixpkgs"; };
                description = "The flake reference to be rewritten.";
              };
              to = mkOption {
                type = referenceAttrs;
                example = { type = "github"; owner = "my-org"; repo = "my-nixpkgs"; };
                description = "The flake reference {option}`from` is rewritten to.";
              };
              flake = mkOption {
                type = types.nullOr types.attrs;
                default = null;
                example = literalExpression "nixpkgs";
                description = ''
                  The flake input {option}`from` is rewritten to.
                '';
              };
              exact = mkOption {
                type = types.bool;
                default = true;
                description = ''
                  Whether the {option}`from` reference needs to match exactly. If set,
                  a {option}`from` reference like `nixpkgs` does not
                  match with a reference like `nixpkgs/nixos-20.03`.
                '';
              };
            };
            config = {
              from = mkDefault { type = "indirect"; id = name; };
              to = mkIf (config.flake != null) (mkDefault (
                {
                  type = "path";
                  path = config.flake.outPath;
                } // filterAttrs
                  (n: _: n == "lastModified" || n == "rev" || n == "revCount" || n == "narHash")
                  config.flake
              ));
            };
          }
        ));
        inherit (managedDefault "nix.registry" { }) default defaultText;
        description = ''
          A system-wide flake registry.
        '';
      };

      extraOptions = mkOption {
        type = types.lines;
        inherit (managedDefault "nix.extraOptions" "") default defaultText;
        example = ''
          keep-outputs = true
          keep-derivations = true
        '';
        description = "Additional text appended to {file}`nix.conf`.";
      };

      settings = mkOption {
        type = types.submodule {
          freeformType = semanticConfType;

          options = {
            max-jobs = mkOption {
              type = types.either types.int (types.enum [ "auto" ]);
              default = "auto";
              example = 64;
              description = ''
                This option defines the maximum number of jobs that Nix will try to
                build in parallel. The default is auto, which means it will use all
                available logical cores. It is recommend to set it to the total
                number of logical cores in your system (e.g., 16 for two CPUs with 4
                cores each and hyper-threading).
              '';
            };

            auto-optimise-store = mkOption {
              type = types.bool;
              default = false;
              example = true;
              description = ''
                If set to true, Nix automatically detects files in the store that have
                identical contents, and replaces them with hard links to a single copy.
                This saves disk space. If set to false (the default), you can enable
                {option}`nix.optimise.automatic` to run {command}`nix-store --optimise`
                periodically to get rid of duplicate files. You can also run
                {command}`nix-store --optimise` manually.
              '';
            };

            cores = mkOption {
              type = types.int;
              default = 0;
              example = 64;
              description = ''
                This option defines the maximum number of concurrent tasks during
                one build. It affects, e.g., -j option for make.
                The special value 0 means that the builder should use all
                available CPU cores in the system. Some builds may become
                non-deterministic with this option; use with care! Packages will
                only be affected if enableParallelBuilding is set for them.
              '';
            };

            sandbox = mkOption {
              type = types.either types.bool (types.enum [ "relaxed" ]);
              default = false;
              description = ''
                If set, Nix will perform builds in a sandboxed environment that it
                will set up automatically for each build. This prevents impurities
                in builds by disallowing access to dependencies outside of the Nix
                store by using network and mount namespaces in a chroot environment. It
                doesn't affect derivation hashes, so changing this option will not
                trigger a rebuild of packages.
              '';
            };

            extra-sandbox-paths = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = [ "/dev" "/proc" ];
              description = ''
                Directories from the host filesystem to be included
                in the sandbox.
              '';
            };

            substituters = mkOption {
              type = types.listOf types.str;
              description = ''
                List of binary cache URLs used to obtain pre-built binaries
                of Nix packages.

                By default https://cache.nixos.org/ is added.
              '';
            };

            trusted-substituters = mkOption {
              type = types.listOf types.str;
              default = [ ];
              example = [ "https://hydra.nixos.org/" ];
              description = ''
                List of binary cache URLs that non-root users can use (in
                addition to those specified using
                {option}`nix.settings.substituters`) by passing
                `--option binary-caches` to Nix commands.
              '';
            };

            require-sigs = mkOption {
              type = types.bool;
              default = true;
              description = ''
                If enabled (the default), Nix will only download binaries from binary caches if
                they are cryptographically signed with any of the keys listed in
                {option}`nix.settings.trusted-public-keys`. If disabled, signatures are neither
                required nor checked, so it's strongly recommended that you use only
                trustworthy caches and https to prevent man-in-the-middle attacks.
              '';
            };

            trusted-public-keys = mkOption {
              type = types.listOf types.str;
              example = [ "hydra.nixos.org-1:CNHJZBh9K4tP3EKF6FkkgeVYsS3ohTl+oS0Qa8bezVs=" ];
              description = ''
                List of public keys used to sign binary caches. If
                {option}`nix.settings.trusted-public-keys` is enabled,
                then Nix will use a binary from a binary cache if and only
                if it is signed by *any* of the keys
                listed here. By default, only the key for
                `cache.nixos.org` is included.
              '';
            };

            trusted-users = mkOption {
              type = types.listOf types.str;
              example = [ "root" "alice" "@admin" ];
              description = ''
                A list of names of users that have additional rights when
                connecting to the Nix daemon, such as the ability to specify
                additional binary caches, or to import unsigned NARs. You
                can also specify groups by prefixing them with
                `@`; for instance,
                `@admin` means all users in the wheel
                group.
              '';
            };

            # Not implemented yet
            # system-features = mkOption {
            #   type = types.listOf types.str;
            #   example = [ "kvm" "big-parallel" "gccarch-skylake" ];
            #   description = ''
            #     The set of features supported by the machine. Derivations
            #     can express dependencies on system features through the
            #     <literal>requiredSystemFeatures</literal> attribute.

            #     By default, pseudo-features <literal>nixos-test</literal>, <literal>benchmark</literal>,
            #     and <literal>big-parallel</literal> used in Nixpkgs are set, <literal>kvm</literal>
            #     is also included in it is avaliable.
            #   '';
            # };

            allowed-users = mkOption {
              type = types.listOf types.str;
              default = [ "*" ];
              example = [ "@admin" "@builders" "alice" "bob" ];
              description = ''
                A list of names of users (separated by whitespace) that are
                allowed to connect to the Nix daemon. As with
                {option}`nix.settings.trusted-users`, you can specify groups by
                prefixing them with `@`. Also, you can
                allow all users by specifying `*`. The
                default is `*`. Note that trusted users are
                always allowed to connect.
              '';
            };
          };
        };
        inherit (managedDefault "nix.settings" { }) default defaultText;
        description = ''
          Configuration for Nix, see
          <https://nixos.org/manual/nix/stable/#sec-conf-file>
          for avalaible options.
          The value declared here will be translated directly to the key-value pairs Nix expects.

          Nix configurations defined under {option}`nix.*` will be translated and applied to this
          option. In addition, configuration specified in {option}`nix.extraOptions` which will be appended
          verbatim to the resulting config file.
        '';
      };
    };
  };


  ###### implementation

  config = handleUnmanaged {
    environment.systemPackages =
      [
        nixPackage
        pkgs.nix-info
      ]
      ++ optional (config.programs.bash.completion.enable) pkgs.nix-bash-completions;

    environment.etc."nix/nix.conf".source = nixConf;

    # Not in NixOS module
    environment.etc."nix/nix.conf".knownSha256Hashes = [
      "7c2d80499b39256b03ee9abd3d6258343718306aca8d472c26ac32c9b0949093"  # official Nix installer
      "19299897fa312d9d32b3c968c2872dd143085aa727140cec51f57c59083e93b9"
      "c4ecc3d541c163c8fcc954ccae6b8cab28c973dc283fea5995c69aaabcdf785f"
      "ef78f401a9b5a42fd15e967c50da384f99ec62f9dbc66ea38f1390b46b63e1ff"  # official Nix installer 2.0
      "c06b0c6080dd1d62e61a30cfad100c0cfed2d3bcd378e296632dc3b28b31dc69"  # official Nix installer as of 2.0.1
      "ff08c12813680da98c4240328f828647b67a65ba7aa89c022bd8072cba862cf1"  # official Nix installer as of 2.4
      "f3e03d851c240c1aa7daccd144ee929f0f5971982424c868c434eb6030e961d4"  # DeterminateSystems Nix installer 0.10.0
      "c6080216f2a170611e339c3f46e4e1d61aaf0d8b417ad93ade8d647da1382c11"  # DeterminateSystems Nix installer 0.14.0
      "97f4135d262ca22d65c9554aad795c10a4491fa61b67d9c2430f4d82bbfec9a2"  # DeterminateSystems Nix installer 0.15.1
      "5d23e6d7015756c6f300f8cd558ec4d9234ca61deefd4f2478e91a49760b0747"  # DeterminateSystems Nix installer 0.16.0
      "e4974acb79c56148cb8e92137fa4f2de9b7356e897b332fc4e6769e8c0b83e18"  # DeterminateSystems Nix installer 0.20.0
      "966d22ef5bb9b56d481e8e0d5f7ca2deaf4d24c0f0fc969b2eeaa7ae0aa42907"  # DeterminateSystems Nix installer 0.22.0
      "53712b4335030e2dbfb46bb235f8cffcac83fea404bd32dc99417ac89e2dd7c5"  # DeterminateSystems Nix installer 0.33.0
      "6bb8d6b0dd16b44ee793a9b8382dac76c926e4c16ffb8ddd2bb4884d1ca3f811"  # DeterminateSystems Nix installer 0.34.0
      "24797ac05542ff8b52910efc77870faa5f9e3275097227ea4e50c430a5f72916"  # lix-installer 0.17.1 with flakes
      "b027b5cad320b5b8123d9d0db9f815c3f3921596c26dc3c471457098e4d3cc40"  # lix-installer 0.17.1 without flakes
      "74ee0ae5ad21a1b101617685fd3d001f74a9466d9d763d92eb75b99cc740db91"  # experimental official Nix installer 2.33.3
    ];

    environment.etc."nix/registry.json".text = builtins.toJSON {
      version = 2;
      flakes = mapAttrsToList (n: v: { inherit (v) from to exact; }) cfg.registry;
    };

    # List of machines for distributed Nix builds in the format
    # expected by build-remote.pl.
    environment.etc."nix/machines" = mkIf (cfg.buildMachines != [ ]) {
      text =
        concatMapStrings
          (machine:
            (concatStringsSep " " ([
              "${optionalString (machine.protocol != null) "${machine.protocol}://"}${optionalString (machine.sshUser != null) "${machine.sshUser}@"}${machine.hostName}"
              (if machine.system != null then machine.system else if machine.systems != [ ] then concatStringsSep "," machine.systems else "-")
              (if machine.sshKey != null then machine.sshKey else "-")
              (toString machine.maxJobs)
              (toString machine.speedFactor)
              (let res = (machine.supportedFeatures ++ machine.mandatoryFeatures);
               in if (res == []) then "-" else (concatStringsSep "," res))
              (let res = machine.mandatoryFeatures;
               in if (res == []) then "-" else (concatStringsSep "," machine.mandatoryFeatures))
            ]
            ++ optional (isNixAtLeast "2.4pre") (if machine.publicHostKey != null then machine.publicHostKey else "-")))
            + "\n"
          )
          cfg.buildMachines;
    };

    assertions =
      let
        badMachine = m: m.system == null && m.systems == [ ];

        # Not in NixOS module
        createdGroups = mapAttrsToList (n: v: v.name) config.users.groups;
        createdUsers = mapAttrsToList (n: v: v.name) config.users.users;
      in
      [
        {
          assertion = !(any badMachine cfg.buildMachines);
          message = ''
            At least one system type (via <varname>system</varname> or
              <varname>systems</varname>) must be set for every build machine.
              Invalid machine specifications:
          '' + "      " +
          (concatStringsSep "\n      "
            (map (m: m.hostName)
              (filter (badMachine) cfg.buildMachines)));
        }

        # Not in NixOS module
        { assertion = elem "nixbld" config.users.knownGroups -> elem "nixbld" createdGroups; message = "refusing to delete group nixbld in users.knownGroups, this would break nix"; }
        { assertion = elem "_nixbld1" config.users.knownUsers -> elem "_nixbld1" createdUsers; message = "refusing to delete user _nixbld1 in users.knownUsers, this would break nix"; }
        { assertion = config.users.groups ? "nixbld" -> config.users.groups.nixbld.members != []; message = "refusing to remove all members from nixbld group, this would break nix"; }

        {
          # Should be fixed in Lix by https://gerrit.lix.systems/c/lix/+/2100
          # Lix 2.92.0 will set `VERSION_SUFFIX` to `""`; `lib.versionAtLeast "" "pre20241107"` will return `true`.
          assertion = cfg.settings.auto-optimise-store -> (cfg.package.pname == "lix" && (isNixAtLeast "2.92.0" && versionAtLeast (strings.removePrefix "-" cfg.package.VERSION_SUFFIX) "pre20241107"));
          message = "`nix.settings.auto-optimise-store` is known to corrupt the Nix Store, please use `nix.optimise.automatic` instead.";
        }
      ];

    # Not in NixOS module
    warnings = [
      (mkIf (!cfg.distributedBuilds && cfg.buildMachines != []) "nix.distributedBuilds is not enabled, build machines won't be configured.")
    ];

    # Not in NixOS module
    nix.nixPath = mkIf (config.system.stateVersion < 2) (mkDefault [
      "darwin=${config.system.primaryUserHome}/.nix-defexpr/darwin"
      "darwin-config=${config.system.primaryUserHome}/.nixpkgs/darwin-configuration.nix"
      "/nix/var/nix/profiles/per-user/root/channels"
    ]);

    system.requiresPrimaryUser = mkIf (
      config.system.stateVersion < 2
      && options.nix.nixPath.highestPrio == (mkDefault {}).priority
    ) [
      "nix.nixPath"
    ];

    # Set up the environment variables for running Nix.
    environment.variables = cfg.envVars // { NIX_PATH = cfg.nixPath; };

    environment.extraInit = mkIf cfg.channel.enable ''
      if [ -e "$HOME/.nix-defexpr/channels" ]; then
        export NIX_PATH="$HOME/.nix-defexpr/channels''${NIX_PATH:+:$NIX_PATH}"
      fi
    '';

    environment.extraSetup = mkIf (!cfg.channel.enable) ''
      rm --force $out/bin/nix-channel
    '';

    nix.nrBuildUsers = mkDefault (max 32 (if cfg.settings.max-jobs == "auto" then 0 else cfg.settings.max-jobs));

    users.users = mkIf configureBuildUsers nixbldUsers;

    # Not in NixOS module
    users.groups.nixbld = mkIf configureBuildUsers {
      description = "Nix build group for nix-daemon";
      gid = config.ids.gids.nixbld;
      members = attrNames nixbldUsers;
    };
    users.knownUsers =
      let nixbldUserNames = attrNames nixbldUsers;
      in
      mkMerge [
        nixbldUserNames
        (map (removePrefix "_") nixbldUserNames) # delete old style nixbld users
      ];
    users.knownGroups = [ "nixbld" ];

    # The Determinate Systems installer puts user‐specified settings in
    # `/etc/nix/nix.custom.conf` since v0.33.0. Supplement the
    # `/etc/nix/nix.conf` hash check so that we don’t accidentally
    # clobber user configuration.
    #
    # TODO: Maybe this could use a more general file placement mechanism
    # to express that we want it deleted and know only one hash?
    system.activationScripts.checks.text = mkAfter ''
      nixCustomConfKnownSha256Hashes=(
        # DetSys v0.33.0
        6787fade1cf934f82db554e78e1fc788705c2c5257fddf9b59bdd963ca6fec63
        # DetSys v0.34.0
        3bd68ef979a42070a44f8d82c205cfd8e8cca425d91253ec2c10a88179bb34aa
        # Nix 2.33.3
        71f7fdc9f6c9e55ca0f2e6f85137037d660b3224a34d59305e8530ca292bc734
      )
      if [[ -e /etc/nix/nix.custom.conf ]]; then
        nixCustomConfSha256Output=$(shasum -a 256 /etc/nix/nix.custom.conf)
        nixCustomConfSha256Hash=''${nixCustomConfSha256Output%% *}
        nixCustomConfIsKnown=
        for nixCustomConfKnownSha256Hash
          in "''${nixCustomConfKnownSha256Hashes[@]}"
        do
          if
            [[ $nixCustomConfSha256Hash == "$nixCustomConfKnownSha256Hash" ]]
          then
            nixCustomConfIsKnown=1
            break
          fi
        done
        if [[ ! $nixCustomConfIsKnown ]]; then
          printf >&2 '\e[1;31merror: custom settings in `/etc/nix/nix.custom.conf`, aborting activation\e[0m\n'
          printf >&2 'You will need to migrate these to nix-darwin `nix.*` settings if you\n'
          printf >&2 'wish to keep them. Check the manual for the appropriate settings and\n'
          printf >&2 'add them to your system configuration, then run:\n'
          printf >&2 '\n'
          printf >&2 '  $ sudo mv /etc/nix/nix.custom.conf{,.before-nix-darwin}\n'
          printf >&2 '\n'
          printf >&2 'and activate your system again.\n'
          exit 2
        fi
      fi
    '';

    # Unrelated to use in NixOS module
    system.activationScripts.nix-daemon.text = ''
      # Follow up on the `/etc/nix/nix.custom.conf` check.
      # TODO: Use a more generalized file placement mechanism for this.
      if [[ -e /etc/nix/nix.custom.conf ]]; then
        mv /etc/nix/nix.custom.conf{,.before-nix-darwin}
      fi

      if ! diff /etc/nix/nix.conf /run/current-system/etc/nix/nix.conf &> /dev/null || ! diff /etc/nix/machines /run/current-system/etc/nix/machines &> /dev/null; then
          echo "reloading nix-daemon..." >&2
          launchctl kill HUP system/org.nixos.nix-daemon
      fi
      while ! nix-store --store daemon -q --hash ${pkgs.stdenv.shell} &>/dev/null; do
          echo "waiting for nix-daemon" >&2
          launchctl kickstart system/org.nixos.nix-daemon
      done
    '';

    nix.settings = mkMerge [
      {
        trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
        trusted-users = [ "root" ];
        substituters = mkAfter [ "https://cache.nixos.org/" ];

        # Not in NixOS module
        build-users-group = "nixbld";

        # Not implemented yet
        # system-features = mkDefault (
        #   [ "nixos-test" "benchmark" "big-parallel" "kvm" ] ++
        #   optionals (pkgs.hostPlatform ? gcc.arch) (
        #     # a builder can run code for `gcc.arch` and inferior architectures
        #     [ "gccarch-${pkgs.hostPlatform.gcc.arch}" ] ++
        #     map (x: "gccarch-${x}") systems.architectures.inferiors.${pkgs.hostPlatform.gcc.arch}
        #   )
        # );
      }

      (mkIf (!cfg.distributedBuilds) { builders = null; })

      (mkIf (isNixAtLeast "2.3pre") { sandbox-fallback = false; })

    ];

  };

}
