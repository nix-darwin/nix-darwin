{
  inputs = {
    nix-darwin.url = "github:nix-darwin/nix-darwin";
    flake-parts.url = "github:hercules-ci/flake-parts/ea2630b7470978622c7689a1ff75d2b389175399";
    flake-parts.inputs.nixpkgs-lib.follows = "nix-darwin/nixpkgs";
  };

  outputs = inputs@{ self, flake-parts, nix-darwin }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ ];
      imports = [
        nix-darwin.flakeModules.default
        { flake.darwinModules.shared.networking.hostName = "test-mac"; }
        { flake.darwinModules.shared.networking.domain = "example.org"; }
      ];

      flake.darwinConfigurations.test = nix-darwin.lib.darwinSystem {
        modules = [ self.darwinModules.shared ];
      };
    };
}
