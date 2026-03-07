{ name, lib, ... }:

{
  options =
    let
      inherit (lib) mkOption types;
    in
    {
      name = mkOption {
        type = types.str;
        default = name;
        description = ''
          The group's name. If undefined, the name of the attribute set
          will be used.
        '';
      };

      gid = mkOption {
        type = types.int;
        description = "The group's GID.";
      };

      members = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "The group's members.";
      };

      description = mkOption {
        type = types.str;
        default = "";
        description = "The group's description.";
      };
    };
}
