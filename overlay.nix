final: _: {
  nix-darwin = configuration: 
  let 
    result = import ./eval-config.nix {
      inherit (final) lib;
      modules = [
        ({ lib, ... }: {
          config.nixpkgs.pkgs = lib.mkDefault final;
          config.nixpkgs.source = lib.mkDefault final.path;
          config.nixpkgs.system = lib.mkDefault final.stdenv.hostPlatform;
        })
      ] ++ (if builtins.isList configuration then configuration else [ configuration ]);
    };
  in result.config.system.build // result;
}
