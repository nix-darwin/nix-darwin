{ nixpkgs ? <nixpkgs>
# Adapted from https://github.com/NixOS/nixpkgs/blob/e818264fe227ad8861e0598166cf1417297fdf54/pkgs/top-level/release.nix#L11
, nix-darwin ? { }
, system ? builtins.currentSystem
, supportedSystems ? [ "x86_64-darwin" "aarch64-darwin" ]
, scrubJobs ? true
}:

let
  buildFromConfig = configuration: sel: sel
    (import ./. { inherit nixpkgs configuration system; }).config;

  makeSystem = configuration: buildFromConfig configuration (config: config.system.build.toplevel);

  makeTest = test:
    let
      testName =
        builtins.replaceStrings [ ".nix" ] [ "" ]
          (builtins.baseNameOf test);

      configuration =
        { config, lib, pkgs, ... }:
        with lib;
        {
          imports = [ test ];

          options = {
            out = mkOption {
              type = types.package;
            };

            test = mkOption {
              type = types.lines;
            };
          };

          config = {
            system.stateVersion = lib.mkDefault config.system.maxStateVersion;

            system.build.run-test = pkgs.runCommand "darwin-test-${testName}"
              { allowSubstitutes = false; preferLocalBuild = true; }
              ''
                #! ${pkgs.stdenv.shell}
                set -e

                echo >&2 "running tests for system ${config.out}"
                echo >&2
                ${config.test}
                echo >&2 ok
                touch $out
              '';

            out = config.system.build.toplevel;
          };
        };
    in
      buildFromConfig configuration (config: config.system.build.run-test);

  manual = buildFromConfig ({ lib, config, ... }: {
    system.stateVersion = lib.mkDefault config.system.maxStateVersion;

    system.darwinVersionSuffix = let
      shortRev = nix-darwin.shortRev or nix-darwin.dirtyShortRev or null;
    in
      lib.mkIf (shortRev != null) ".${shortRev}";
    system.darwinRevision = let
      rev = nix-darwin.rev or nix-darwin.dirtyRev or null;
    in
      lib.mkIf (rev != null) rev;
  }) (config: config.system.build.manual);

in {
  docs = {
    inherit (manual) manualHTML manpages optionsJSON;
  };

  examples.hydra = makeSystem ./modules/examples/hydra.nix;
  examples.lnl = makeSystem ./modules/examples/lnl.nix;
  examples.simple = makeSystem ./modules/examples/simple.nix;

  tests.activation-scripts = makeTest ./tests/activation-scripts.nix;
  tests.autossh = makeTest ./tests/autossh.nix;
  tests.checks-nh-clean = makeTest ./tests/checks-nh-clean.nix;
  tests.environment-path = makeTest ./tests/environment-path.nix;
  tests.environment-terminfo = makeTest ./tests/environment-terminfo.nix;
  tests.homebrew = makeTest ./tests/homebrew.nix;
  tests.launchd-daemons = makeTest ./tests/launchd-daemons.nix;
  tests.launchd-setenv = makeTest ./tests/launchd-setenv.nix;
  tests.networking-hostname = makeTest ./tests/networking-hostname.nix;
  tests.networking-networkservices = makeTest ./tests/networking-networkservices.nix;
  tests.nix-enable = makeTest ./tests/nix-enable.nix;
  tests.nixpkgs-overlays = makeTest ./tests/nixpkgs-overlays.nix;
  tests.programs-nh = makeTest ./tests/programs-nh.nix;
  tests.programs-ssh = makeTest ./tests/programs-ssh.nix;
  tests.programs-tmux = makeTest ./tests/programs-tmux.nix;
  tests.programs-zsh = makeTest ./tests/programs-zsh.nix;
  tests.programs-ssh-empty-known-hosts = makeTest ./tests/programs-ssh-empty-known-hosts.nix;
  tests.security-pki = makeTest ./tests/security-pki.nix;
  tests.services-activate-system = makeTest ./tests/services-activate-system.nix;
  tests.services-activate-system-changed-label-prefix = makeTest ./tests/services-activate-system-changed-label-prefix.nix;
  tests.services-buildkite-agent = makeTest ./tests/services-buildkite-agent.nix;
  tests.services-github-runners = makeTest ./tests/services-github-runners.nix;
  tests.services-lorri = makeTest ./tests/services-lorri.nix;
  tests.services-nix-daemon = makeTest ./tests/services-nix-daemon.nix;
  tests.sockets-nix-daemon = makeTest ./tests/sockets-nix-daemon.nix;
  tests.services-aerospace = makeTest ./tests/services-aerospace.nix;
  tests.services-dnsmasq = makeTest ./tests/services-dnsmasq.nix;
  tests.services-dnscrypt-proxy = makeTest ./tests/services-dnscrypt-proxy.nix;
  tests.services-eternal-terminal = makeTest ./tests/services-eternal-terminal.nix;
  tests.services-nix-gc = makeTest ./tests/services-nix-gc.nix;
  tests.services-nix-optimise = makeTest ./tests/services-nix-optimise.nix;
  tests.services-nextdns = makeTest ./tests/services-nextdns.nix;
  tests.services-netdata = makeTest ./tests/services-netdata.nix;
  tests.services-ofborg = makeTest ./tests/services-ofborg.nix;
  tests.services-offlineimap = makeTest ./tests/services-offlineimap.nix;
  tests.services-openssh = makeTest ./tests/services-openssh.nix;
  tests.services-privoxy = makeTest ./tests/services-privoxy.nix;
  tests.services-redis = makeTest ./tests/services-redis.nix;
  tests.services-skhd = makeTest ./tests/services-skhd.nix;
  tests.services-spacebar = makeTest ./tests/services-spacebar.nix;
  tests.services-spotifyd = makeTest ./tests/services-spotifyd.nix;
  tests.services-synapse-bt = makeTest ./tests/services-synapse-bt.nix;
  tests.services-synergy = makeTest ./tests/services-synergy.nix;
  tests.services-yabai = makeTest ./tests/services-yabai.nix;
  tests.services-jankyborders = makeTest ./tests/services-jankyborders.nix;
  tests.system-defaults-write = makeTest ./tests/system-defaults-write.nix;
  tests.system-environment = makeTest ./tests/system-environment.nix;
  tests.system-keyboard-mapping = makeTest ./tests/system-keyboard-mapping.nix;
  tests.system-packages = makeTest ./tests/system-packages.nix;
  tests.system-path = makeTest ./tests/system-path.nix;
  tests.system-shells = makeTest ./tests/system-shells.nix;
  tests.users-groups = makeTest ./tests/users-groups.nix;
  tests.users-packages = makeTest ./tests/users-packages.nix;
  tests.fonts = makeTest ./tests/fonts.nix;
}
