{ config, pkgs, ... }:

{
  environment.systemPath = [ pkgs.hello ];

  test = ''
    echo checking systemPath in setEnvironment >&2
    grep 'export PATH=${pkgs.hello}/bin' ${config.system.build.setEnvironment}
  '';
}
