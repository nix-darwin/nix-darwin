{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.dictd;
in

{
  meta.maintainers = [ lib.maintainers.philocalyst or "philocalyst" ];

  options = {

    services.dictd = {

      enable = lib.mkEnableOption "the DICT.org dictionary server";

      DBs = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs.dictdDBs; [
          wiktionary
          wordnet
        ];
        defaultText = lib.literalExpression "with pkgs.dictdDBs; [ wiktionary wordnet ]";
        example = lib.literalExpression "[ pkgs.dictdDBs.nld2eng ]";
        description = "List of databases to make available.";
      };

    };

  };

  config =
    let
      dictdb = pkgs.dictDBCollector {
        dictlist = map (x: {
          name = x.name;
          filename = x;
        }) cfg.DBs;
      };
    in
    lib.mkIf cfg.enable {

      environment.systemPackages = [ pkgs.dict ];

      environment.etc."dict.conf".text = ''
        server localhost
      '';

      launchd.daemons.dictd = {
        command = "${pkgs.dict}/sbin/dictd -c ${dictdb}/share/dictd/dictd.conf --locale en_US.UTF-8";
        serviceConfig = {
          KeepAlive = true;
          RunAtLoad = true;
        };
        managedBy = "services.dictd.enable";
      };

    };
}
