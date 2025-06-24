{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.nix.linux-builder;
in

{
  imports = [
    (mkRemovedOptionModule [ "nix" "linux-builder" "modules" ] "This option has been replaced with `nix.linux-builder.config` which allows setting options directly like `nix.linux-builder.config.networking.hostName = \"banana\";.")
  ];

  options.nix.linux-builder = {
    enable = mkEnableOption "Linux builder";

    package = mkOption {
      type = types.package;
      default = pkgs.darwin.linux-builder;
      defaultText = "pkgs.darwin.linux-builder";
      apply = pkg: pkg.override (old: {
        # the linux-builder package requires `modules` as an argument, so it's
        # always non-null.
        modules = old.modules ++ [ cfg.config ];
      });
      description = ''
        This option specifies the Linux builder to use.
      '';
    };

    config = mkOption {
      type = types.deferredModule;
      default = { };
      example = literalExpression ''
        ({ pkgs, ... }:

        {
          environment.systemPackages = [ pkgs.neovim ];
        })
      '';
      description = ''
        This option specifies extra NixOS configuration for the builder. You should first use the Linux builder
        without changing the builder configuration otherwise you may not be able to build the Linux builder.
      '';
    };

    mandatoryFeatures = mkOption {
      type = types.listOf types.str;
      default = [];
      defaultText = literalExpression ''[]'';
      example = literalExpression ''[ "big-parallel" ]'';
      description = ''
        A list of features mandatory for the Linux builder. The builder will
        be ignored for derivations that don't require all features in
        this list. All mandatory features are automatically included in
        {var}`supportedFeatures`.

        This sets the corresponding `nix.buildMachines.*.mandatoryFeatures` option.
      '';
    };

    maxJobs = mkOption {
      type = types.ints.positive;
      default = cfg.package.nixosConfig.virtualisation.cores;
      defaultText = ''
        The `virtualisation.cores` of the build machine's final NixOS configuration.
      '';
      example = 2;
      description = ''
        Instead of setting this directly, you should set
        {option}`nix.linux-builder.config.virtualisation.cores` to configure
        the amount of cores the Linux builder should have.

        The number of concurrent jobs the Linux builder machine supports. The
        build machine will enforce its own limits, but this allows hydra
        to schedule better since there is no work-stealing between build
        machines.

        This sets the corresponding `nix.buildMachines.*.maxJobs` option.
      '';
    };

    protocol = mkOption {
      type = types.str;
      default = "ssh-ng";
      defaultText = literalExpression ''"ssh-ng"'';
      example = literalExpression ''"ssh"'';
      description = ''
        The protocol used for communicating with the build machine.  Use
        `ssh-ng` if your remote builder and your local Nix version support that
        improved protocol.

        Use `null` when trying to change the special localhost builder without a
        protocol which is for example used by hydra.
      '';
    };

    speedFactor = mkOption {
      type = types.ints.positive;
      default = 1;
      defaultText = literalExpression ''1'';
      description = ''
        The relative speed of the Linux builder. This is an arbitrary integer
        that indicates the speed of this builder, relative to other
        builders. Higher is faster.

        This sets the corresponding `nix.buildMachines.*.speedFactor` option.
      '';
    };

    supportedFeatures = mkOption {
      type = types.listOf types.str;
      default = [ "kvm" "benchmark" "big-parallel" ];
      defaultText = literalExpression ''[ "kvm" "benchmark" "big-parallel" ]'';
      example = literalExpression ''[ "kvm" "big-parallel" ]'';
      description = ''
        A list of features supported by the Linux builder. The builder will
        be ignored for derivations that require features not in this
        list.

        This sets the corresponding `nix.buildMachines.*.supportedFeatures` option.
      '';
    };

    systems = mkOption {
      type = types.listOf types.str;
      default = [ cfg.package.nixosConfig.nixpkgs.hostPlatform.system ];
      defaultText = ''
        The `nixpkgs.hostPlatform.system` of the build machine's final NixOS configuration.
      '';
      example = literalExpression ''
        [
          "x86_64-linux"
          "aarch64-linux"
        ]
      '';
      description = ''
        This option specifies system types the build machine can execute derivations on.

        This sets the corresponding `nix.buildMachines.*.systems` option.
      '';
    };


    workingDirectory = mkOption {
      type = types.str;
      default = "/var/lib/linux-builder";
      description = ''
        The working directory of the Linux builder daemon process.
      '';
    };

    ephemeral = mkEnableOption ''
      wipe the builder's filesystem on every restart.

      This is disabled by default as maintaining the builder's Nix Store reduces
      rebuilds. You can enable this if you don't want your builder to accumulate
      state.
    '';
  };

  config = mkMerge [
    (mkIf (!cfg.enable) {
      system.activationScripts.preActivation.text = ''
        rm -rf ${cfg.workingDirectory}
      '';
    })
    (mkIf cfg.enable {
      assertions = [
        {
          assertion = config.nix.enable;
          message = ''`nix.linux-builder.enable` requires `nix.enable`'';
        }
      ];

      system.activationScripts.preActivation.text = ''
        # Migrate if using the old working directory
        if [ -e /var/lib/darwin-builder ] && [ ! -e ${cfg.workingDirectory} ]; then
          mv /var/lib/darwin-builder ${cfg.workingDirectory}
        fi

        mkdir -p ${cfg.workingDirectory}
      '';

      launchd.daemons.linux-builder = {
        environment = {
          inherit (config.environment.variables) NIX_SSL_CERT_FILE;
        };

        # create-builder uses TMPDIR to share files with the builder, notably certs.
        # macOS will clean up files in /tmp automatically that haven't been accessed in 3+ days.
        # If we let it use /tmp, leaving the computer asleep for 3 days makes the certs vanish.
        # So we'll use /run/org.nixos.linux-builder instead and clean it up ourselves.
        script = ''
          export TMPDIR=/run/org.nixos.linux-builder USE_TMPDIR=1
          rm -rf $TMPDIR
          mkdir -p $TMPDIR
          trap "rm -rf $TMPDIR" EXIT
          ${lib.optionalString cfg.ephemeral ''
            rm -f ${cfg.workingDirectory}/${cfg.package.nixosConfig.networking.hostName}.qcow2
          ''}
          ${cfg.package}/bin/create-builder
        '';

        serviceConfig = {
          KeepAlive = true;
          RunAtLoad = true;
          WorkingDirectory = cfg.workingDirectory;
        };
      };

      environment.etc."ssh/ssh_config.d/100-linux-builder.conf".text = ''
        Host linux-builder
          User builder
          Hostname localhost
          HostKeyAlias linux-builder
          Port 31022
          IdentityFile /etc/nix/builder_ed25519
      '';

      nix.distributedBuilds = true;

      nix.buildMachines = [{
        hostName = "linux-builder";
        sshUser = "builder";
        sshKey = "/etc/nix/builder_ed25519";
        publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUpCV2N4Yi9CbGFxdDFhdU90RStGOFFVV3JVb3RpQzVxQkorVXVFV2RWQ2Igcm9vdEBuaXhvcwo=";
        inherit (cfg) mandatoryFeatures maxJobs protocol speedFactor supportedFeatures systems;
      }];

      nix.settings.builders-use-substitutes = true;
    })
  ];
}
