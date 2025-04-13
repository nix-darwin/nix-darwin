{ config, lib, pkgs, ... }:

with lib;

{
  environment.systemPath = mkMerge [
    (mkBefore [ "beforePath" ])
    [ "myPath" ]
    (mkAfter [ "afterPath" ])
  ];

  environment.profiles = mkMerge [
    (mkBefore [ "beforeProfile" ])
    [ "myProfile" ]
    (mkAfter [ "afterProfile" ])
  ];

  test = ''
    echo 'checking PATH' >&2
    env_path=$(bash -c 'source ${config.system.build.setEnvironment}; echo $PATH')

    test "$env_path" = "${builtins.concatStringsSep ":" [
      "/run/wrappers/bin"
      "beforePath"
      "myPath"
      "beforeProfile/bin"
      "/homeless-shelter/.nix-profile/bin"
      "myProfile/bin"
      "/run/current-system/sw/bin"
      "/nix/var/nix/profiles/default/bin"
      "afterProfile/bin"
      "/usr/local/bin"
      "/usr/bin"
      "/bin"
      "/usr/sbin"
      "/sbin"
      "afterPath"
    ]}"
  '';
}
