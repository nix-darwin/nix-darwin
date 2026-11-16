{ config, pkgs, ... }:

let
  _1password-cli = pkgs.runCommand "_1password-cli-0.0.0" { meta.mainProgram = "op"; } ''
    mkdir -p $out/bin
    cat <<'EOF' > $out/bin/op
    #!/bin/sh
    exit 0
    EOF
    chmod +x $out/bin/op
  '';

  _1password-gui = pkgs.runCommand "_1password-gui-0.0.0" { } ''
    mkdir -p $out/Applications/1Password.app
  '';
in

{
  programs._1password.enable = true;
  programs._1password.package = _1password-cli;

  programs._1password-gui.enable = true;
  programs._1password-gui.package = _1password-gui;

  test = ''
    echo "checking 1Password CLI installation in /activate" >&2
    grep "install -o root -g wheel -m0555 -D" ${config.out}/activate
    grep "${_1password-cli}/bin/op /usr/local/bin/op" ${config.out}/activate

    echo "checking 1Password GUI installation in /activate" >&2
    grep 'install -o root -g wheel -m0555 -d "/Applications/1Password.app"' ${config.out}/activate
    grep "${_1password-gui}/Applications/1Password.app/ /Applications/1Password.app" ${config.out}/activate
  '';
}
