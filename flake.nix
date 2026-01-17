{
  description = "A collection of darwin modules";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }: let
    forAllSystems = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-darwin" "aarch64-linux" "x86_64-linux" ];
    forDarwinSystems = nixpkgs.lib.genAttrs [ "aarch64-darwin" "x86_64-darwin" ];

    jobs = forAllSystems (system: import ./release.nix {
      inherit nixpkgs system;

      nix-darwin = self;
    });
  in {
    lib = {
      evalConfig = import ./eval-config.nix;

      darwinSystem = args@{ modules, ... }: self.lib.evalConfig (
        { inherit (nixpkgs) lib; }
        // nixpkgs.lib.optionalAttrs (args ? pkgs) { inherit (args.pkgs) lib; }
        // builtins.removeAttrs args [ "system" "pkgs" "inputs" ]
        // {
          modules = modules
            ++ nixpkgs.lib.optional (args ? pkgs) ({ lib, ... }: {
              _module.args.pkgs = lib.mkForce args.pkgs;
            })
            # Backwards compatibility shim; TODO: warn?
            ++ nixpkgs.lib.optional (args ? system) ({ lib, ... }: {
              nixpkgs.system = lib.mkDefault args.system;
            })
            # Backwards compatibility shim; TODO: warn?
            ++ nixpkgs.lib.optional (args ? inputs) {
              _module.args.inputs = args.inputs;
            }
            ++ [ ({ lib, ... }: {
              nixpkgs.source = lib.mkDefault nixpkgs;
              nixpkgs.flake.source = lib.mkDefault nixpkgs.outPath;

              system.checks.verifyNixPath = lib.mkDefault false;

              system.darwinVersionSuffix = ".${self.shortRev or self.dirtyShortRev or "dirty"}";
              system.darwinRevision = let
                rev = self.rev or self.dirtyRev or null;
              in
                lib.mkIf (rev != null) rev;
            }) ];
          });
    };

    overlays.default = final: prev: {
      inherit (prev.callPackage ./pkgs/nix-tools { }) darwin-rebuild darwin-option darwin-version;

      darwin-uninstaller = prev.callPackage ./pkgs/darwin-uninstaller { };
    };

    flakeModules.default = ./flake-module.nix;

    darwinModules.hydra = ./modules/examples/hydra.nix;
    darwinModules.lnl = ./modules/examples/lnl.nix;
    darwinModules.simple = ./modules/examples/simple.nix;

    templates.default = {
      path = ./modules/examples/flake;
      description = "nix flake init -t nix-darwin";
    };

    checks = forDarwinSystems (system: jobs.${system}.tests // jobs.${system}.examples);

    packages = forAllSystems (system: {
      inherit (jobs.${system}.docs) manualHTML manpages optionsJSON;
    } // (nixpkgs.lib.optionalAttrs (nixpkgs.lib.hasSuffix "darwin" system) (let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
      };
    in {
      default = self.packages.${system}.darwin-rebuild;

      inherit (pkgs) darwin-option darwin-rebuild darwin-version darwin-uninstaller;

      # TODO: Include manuals for active release branches in the website.
      # (This may involve moving it to a separate repository.)
      website = pkgs.linkFarm "nix-darwin-website" {
        "index.html" = ./doc/website/index.html;
        manual = "${self.packages.${system}.manualHTML}/share/doc/darwin";
      };
    })));
  };
}
