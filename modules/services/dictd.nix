{ lib, pkgs, config, ... }:
with lib;
let
  cfg = config.services.dictd;
in
{
  options = {
    services.dictd = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to enable the DICT.org dictionary server.
        '';
      };

      DBs = mkOption {
        type = types.listOf types.package;
        default = with pkgs.dictdDBs; [
          wiktionary
          wordnet
        ];
        defaultText = literalExpression "with pkgs.dictdDBs; [ wiktionary wordnet ]";
        example = literalExpression "[ pkgs.dictdDBs.nld2eng ]";
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
      mkIf cfg.enable {
        environment.systemPackages = [ pkgs.dict ];

        environment.etc."dict.conf".text = ''
          server localhost
        '';

        users.users.dictd = {
          description = "DICT.org dictd server";
          home = "${dictdb}/share/dictd";
          uid = 105;
        };
        users.knownUsers = [ "dictd" ];
        users.groups.dictd = {
          members = [ "dictd" ];
          gid = 105;
        };
        users.knownGroups = [ "dictd" ];

        launchd.daemons.dictd.serviceConfig = {
          ProgramArguments = [
            "${pkgs.dict}/sbin/dictd"
            "-s"
            "-c"
            "${dictdb}/share/dictd/dictd.conf"
            "--locale"
            "en_US.UTF-8"
            "--pid-file"
            "/var/run/dictd/dictd.pid"
          ];
          GroupName = "dictd";
          UserName = "dictd";
          RunAtLoad = true;
          StandardOutPath = "/tmp/dictd.out.log";
          StandardErrorPath = "/tmp/dictd.err.log";
        };

        system.activationScripts.postActivation.text = ''
          mkdir -p /var/run/dictd
          chown -R dictd:dictd /var/run/dictd
        '';
      };
}
