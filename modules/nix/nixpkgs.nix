{
  config,
  options,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.nixpkgs;
  opt = options.nixpkgs;

  isConfig = x: builtins.isAttrs x || lib.isFunction x;

  optCall = f: x: if lib.isFunction f then f x else f;

  mergeConfig =
    lhs_: rhs_:
    let
      lhs = optCall lhs_ { inherit pkgs; };
      rhs = optCall rhs_ { inherit pkgs; };
    in
    lib.recursiveUpdate lhs rhs
    // lib.optionalAttrs (lhs ? packageOverrides) {
      packageOverrides =
        pkgs:
        optCall lhs.packageOverrides pkgs // optCall (lib.attrByPath [ "packageOverrides" ] { } rhs) pkgs;
    }
    // lib.optionalAttrs (lhs ? perlPackageOverrides) {
      perlPackageOverrides =
        pkgs:
        optCall lhs.perlPackageOverrides pkgs
        // optCall (lib.attrByPath [ "perlPackageOverrides" ] { } rhs) pkgs;
    };

  configType = lib.mkOptionType {
    name = "nixpkgs-config";
    description = "nixpkgs config";
    check =
      x:
      let
        traceXIfNot = c: if c x then true else lib.traceSeqN 1 x false;
      in
      traceXIfNot isConfig;
    merge = args: lib.foldr (def: mergeConfig def.value) { };
  };

  overlayType = lib.mkOptionType {
    name = "nixpkgs-overlay";
    description = "nixpkgs overlay";
    check = lib.isFunction;
    merge = lib.mergeOneOption;
  };

  pkgsType = lib.types.pkgs // {
    # This type is only used by itself, so let's elaborate the description a bit
    # for the purpose of documentation.
    description = "An evaluation of Nixpkgs; the top level attribute set of packages";
  };

  hasBuildPlatform = opt.buildPlatform.highestPrio < (lib.mkOptionDefault { }).priority;
  hasHostPlatform = opt.hostPlatform.isDefined;
  hasPlatform = hasHostPlatform || hasBuildPlatform;

  # Context for messages
  hostPlatformLine = lib.optionalString hasHostPlatform "${lib.showOptionWithDefLocs opt.hostPlatform}";
  buildPlatformLine = lib.optionalString hasBuildPlatform "${lib.showOptionWithDefLocs opt.buildPlatform}";

  legacyOptionsDefined = lib.optional (
    opt.system.highestPrio < (lib.mkDefault { }).priority
  ) opt.system;

  defaultPkgs =
    if opt.hostPlatform.isDefined then
      let
        isCross = cfg.buildPlatform != cfg.hostPlatform;
        systemArgs =
          if isCross then
            {
              localSystem = cfg.buildPlatform;
              crossSystem = cfg.hostPlatform;
            }
          else
            {
              localSystem = cfg.hostPlatform;
            };
      in
      import cfg.source (
        {
          inherit (cfg) config overlays;
        }
        // systemArgs
      )
    else
      import cfg.source {
        inherit (cfg) config overlays;
        localSystem = { inherit (cfg) system; };
      };

  finalPkgs = if opt.pkgs.isDefined then cfg.pkgs.appendOverlays cfg.overlays else defaultPkgs;

in

{
  options.nixpkgs = {
    pkgs = lib.mkOption {
      type = pkgsType;
      example = lib.literalExpression "import <nixpkgs> {}";
      description = ''
        If set, the pkgs argument to all nix-darwin modules is the value of
        this option, extended with `nixpkgs.overlays`, if
        that is also set. The nix-darwin and Nixpkgs architectures must
        match. Any other options in `nixpkgs.*`, notably `config`,
        will be ignored.

        The default value imports the Nixpkgs from
        [](#opt-nixpkgs.source). The `config`, `overlays`, `localSystem`,
        and `crossSystem` are based on this option's siblings.

        This option can be used to increase
        the performance of evaluation, or to create packages that depend
        on a container that should be built with the exact same evaluation
        of Nixpkgs, for example. Applications like this should set
        their default value using `lib.mkDefault`, so
        user-provided configuration can override it without using
        `lib`.
      '';
    };

    config = lib.mkOption {
      default = { };
      example = lib.literalExpression ''
        { allowBroken = true; allowUnfree = true; }
      '';
      type = configType;
      description = ''
        Global configuration for Nixpkgs.
        The complete list of [Nixpkgs configuration options](https://nixos.org/manual/nixpkgs/unstable/#sec-config-options-reference) is in the [Nixpkgs manual section on global configuration](https://nixos.org/manual/nixpkgs/unstable/#chap-packageconfig).

        Ignored when {option}`nixpkgs.pkgs` is set.
      '';
    };

    overlays = lib.mkOption {
      default = [ ];
      example = lib.literalExpression ''
        [
          (self: super: {
            openssh = super.openssh.override {
              hpnSupport = true;
              kerberos = self.libkrb5;
            };
          })
        ]
      '';
      type = lib.types.listOf overlayType;
      description = ''
        List of overlays to apply to Nixpkgs.
        This option allows modifying the Nixpkgs package set accessed through the `pkgs` module argument.

        For details, see the [Overlays chapter in the Nixpkgs manual](https://nixos.org/manual/nixpkgs/stable/#chap-overlays).

        If the {option}`nixpkgs.pkgs` option is set, overlays specified using `nixpkgs.overlays` will be applied after the overlays that were already included in `nixpkgs.pkgs`.
      '';
    };

    hostPlatform = lib.mkOption {
      type = lib.types.either lib.types.str lib.types.attrs; # TODO utilize lib.systems.parsedPlatform
      example = {
        system = "aarch64-darwin";
      };
      # Make sure that the final value has all fields for sake of other modules
      # referring to this. TODO make `lib.systems` itself use the module system.
      apply = lib.systems.elaborate;
      description = ''
        Specifies the platform where the nix-darwin configuration will run.

        To cross-compile, set also `nixpkgs.buildPlatform`.

        Ignored when `nixpkgs.pkgs` is set.
      '';
    };

    buildPlatform = lib.mkOption {
      type = lib.types.either lib.types.str lib.types.attrs; # TODO utilize lib.systems.parsedPlatform
      default = cfg.hostPlatform;
      example = {
        system = "x86_64-darwin";
      };
      # Make sure that the final value has all fields for sake of other modules
      # referring to this.
      apply =
        inputBuildPlatform:
        let
          elaborated = lib.systems.elaborate inputBuildPlatform;
        in
        if lib.systems.equals elaborated cfg.hostPlatform then
          cfg.hostPlatform # make identical, so that `==` equality works; see https://github.com/NixOS/nixpkgs/issues/278001
        else
          elaborated;
      defaultText = lib.literalExpression "config.nixpkgs.hostPlatform";
      description = ''
        Specifies the platform on which nix-darwin should be built.
        By default, nix-darwin is built on the system where it runs, but you can
        change where it's built. Setting this option will cause nix-darwin to be
        cross-compiled.

        For instance, if you're doing distributed multi-platform deployment,
        or if you're building machines, you can set this to match your
        development system and/or build farm.

        Ignored when `nixpkgs.pkgs` is set.
      '';
    };

    system = lib.mkOption {
      type = lib.types.str;
      example = "x86_64-darwin";
      default =
        if opt.hostPlatform.isDefined then
          throw ''
            Neither ${opt.system} nor any other option in nixpkgs.* is meant
            to be read by modules and configurations.
            Use pkgs.stdenv.hostPlatform instead.
          ''
        else
          throw ''
            Neither ${opt.hostPlatform} nor the legacy option ${opt.system} has been set.
            The option ${opt.system} is still fully supported for interoperability,
            but will be deprecated in the future, so we recommend to set ${opt.hostPlatform}.
          '';
      defaultText = lib.literalMD ''
        Traditionally `builtins.currentSystem`, but unset when invoking nix-darwin through `lib.darwinSystem`.
      '';
      description = ''
        Specifies the Nix platform type on which nix-darwin should be built.
        It is better to specify `nixpkgs.hostPlatform` instead.

        Ignored when `nixpkgs.pkgs` or `nixpkgs.hostPlatform` is set.
      '';
    };

    # nix-darwin only

    source = lib.mkOption {
      type = lib.types.path;
      defaultText = lib.literalMD ''
        `<nixpkgs>` or nix-darwin's `nixpkgs` flake input
      '';
      description = ''
        The path to import Nixpkgs from. If you're setting a custom
        [](#opt-nixpkgs.pkgs) or `_module.args.pkgs`, setting this
        to something with `rev` and `shortRev` attributes (such as a
        flake input or `builtins.fetchGit` result) will also set
        `system.nixpkgsRevision` and related options.
        (nix-darwin only)
      '';
    };

    constructedByUs = lib.mkOption {
      type = lib.types.bool;
      internal = true;
      description = ''
        Whether `pkgs` was constructed by this module. This is false when any of
        `nixpkgs.pkgs` or `_module.args.pkgs` is set. (nix-darwin only)
      '';
    };
  };

  config = {
    _module.args = {
      pkgs =
        # We explicitly set the default override priority, so that we do not need
        # to evaluate finalPkgs in case an override is placed on `_module.args.pkgs`.
        # After all, to determine a definition priority, we need to evaluate `._type`,
        # which is somewhat costly for Nixpkgs. With an explicit priority, we only
        # evaluate the wrapper to find out that the priority is lower, and then we
        # don't need to evaluate `finalPkgs`.
        lib.mkOverride lib.modules.defaultOverridePriority finalPkgs.__splicedPackages;
    };

    nixpkgs.constructedByUs =
      # We set it with default priority and it can not be merged, so if the
      # pkgs module argument has that priority, it's from us.
      (lib.modules.mergeAttrDefinitionsWithPrio options._module.args).pkgs.highestPrio
      == lib.modules.defaultOverridePriority
      # Although, if nixpkgs.pkgs is set, we did forward it, but we did not construct it.
      && !opt.pkgs.isDefined;

    assertions = [
      (
        let
          pkgsSystem = finalPkgs.stdenv.targetPlatform.system;
        in
        {
          assertion = cfg.constructedByUs -> !hasPlatform -> cfg.system == pkgsSystem;
          message = "The nix-darwin nixpkgs.pkgs option was set to a Nixpkgs invocation that compiles to target system ${pkgsSystem} but nix-darwin was configured for system ${config.nixpkgs.system} via nix-darwin option nixpkgs.system. The nix-darwin system settings must match the Nixpkgs target system.";
        }
      )
      {
        assertion = cfg.constructedByUs -> hasPlatform -> legacyOptionsDefined == [ ];
        message = ''
          Your system configures nixpkgs with the platform parameter${lib.optionalString hasBuildPlatform "s"}:
          ${hostPlatformLine}${buildPlatformLine}
          However, it also defines the legacy options:
          ${lib.concatMapStrings lib.showOptionWithDefLocs legacyOptionsDefined}
          For a future proof system configuration, we recommend to remove
          the legacy definitions.
        '';
      }
      {
        assertion = opt.pkgs.isDefined -> cfg.config == { };
        message = ''
          Your system configures nixpkgs with an externally created instance.
          `nixpkgs.config` options should be passed when creating the instance instead.

          Current value:
          ${lib.generators.toPretty { multiline = true; } cfg.config}

          Defined in:
          ${lib.concatMapStringsSep "\n" (file: "  - ${file}") opt.config.files}
        '';
      }
    ];
  };
}
