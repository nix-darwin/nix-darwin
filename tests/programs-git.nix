{
  config,
  lib,
  pkgs,
  ...
}:

let
  git = pkgs.runCommand "git-0.0.0" {
    passthru.defaultSystemConfig = "/git-defaults/gitconfig";
  } "mkdir -p $out/bin";
  git-lfs = pkgs.runCommand "git-lfs-0.0.0" { } "mkdir -p $out/bin";
in

{
  programs.git.enable = true;
  programs.git.package = git;
  programs.git.config.init.defaultBranch = "main";
  programs.git.lfs.enable = true;
  programs.git.lfs.package = git-lfs;
  programs.git.attributes = "*.pdf diff=pdf";

  test = ''
    echo >&2 "checking that /etc/gitconfig first includes the package's default system config"
    head -n 1 ${config.out}/etc/gitconfig | grep -Fx '[include]'
    head -n 2 ${config.out}/etc/gitconfig | grep -F 'path = "/git-defaults/gitconfig"'

    echo >&2 "checking init.defaultBranch in /etc/gitconfig"
    grep -F 'defaultBranch = "main"' ${config.out}/etc/gitconfig

    echo >&2 "checking the lfs filter in /etc/gitconfig"
    grep -F 'process = "git-lfs filter-process"' ${config.out}/etc/gitconfig

    echo >&2 "checking /etc/gitattributes"
    grep -F '*.pdf diff=pdf' ${config.out}/etc/gitattributes
  '';
}
