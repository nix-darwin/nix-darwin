# Based on: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/misc/ids.nix

# This module defines the global list of uids and gids.  We keep a
# central list to prevent id collisions.

# IMPORTANT!
# We only add static uids and gids for services where it is not feasible
# to change uids/gids on service start, in example a service with a lot of
# files.

{ lib, config, ... }:

let
  inherit (lib) types;
in
{
  options = {

    ids.uids = lib.mkOption {
      internal = true;
      description = ''
        The user IDs used in NixOS.
      '';
      type = types.attrsOf types.int;
    };

    ids.gids = lib.mkOption {
      internal = true;
      description = ''
        The group IDs used in NixOS.
      '';
      type = types.attrsOf types.int;
    };

  };

  config = {

    ids.uids = {
      nixbld = lib.mkDefault 350;
      _prometheus-node-exporter = 534;
      _dnscrypt-proxy = 535;
      _harmonia = 536;
    };

    ids.gids = {
      nixbld = lib.mkDefault (if config.system.stateVersion < 5 then 30000 else 350);
      _prometheus-node-exporter = 534;
      _dnscrypt-proxy = 535;
      _harmonia = 536;
    };

  };

}
