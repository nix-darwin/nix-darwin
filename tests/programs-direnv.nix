{ config, pkgs, ... }:

let
  direnv = pkgs.runCommand "direnv-0.0.0" { meta.mainProgram = "direnv"; } ''
    mkdir -p $out/bin
    cat <<'EOF' > $out/bin/direnv
    #!/bin/sh
    exit 0
    EOF
    chmod +x $out/bin/direnv
  '';

  nix-direnv = pkgs.runCommand "nix-direnv-0.0.0" { } ''
    mkdir -p $out/share/nix-direnv
    touch $out/share/nix-direnv/direnvrc
  '';
in

{
  programs.bash.enable = true;
  programs.zsh.enable = true;
  programs.fish.enable = true;

  programs.direnv.enable = true;
  programs.direnv.package = direnv;
  programs.direnv.nix-direnv.enable = true;
  programs.direnv.nix-direnv.package = nix-direnv;
  programs.direnv.settings = {
    global = {
      load_dotenv = true;
    };
  };

  test = ''
    echo "checking direnv hook in /etc/bashrc" >&2
    grep 'eval "$(/nix/store/.*-direnv-0.0.0/bin/direnv hook bash)"' ${config.out}/etc/bashrc

    echo "checking direnv hook in /etc/zshrc" >&2
    grep 'eval "$(/nix/store/.*-direnv-0.0.0/bin/direnv hook zsh)"' ${config.out}/etc/zshrc

    echo "checking direnv hook in /etc/fish/config.fish" >&2
    grep '/nix/store/.*-direnv-0.0.0/bin/direnv hook fish | source' ${config.out}/etc/fish/config.fish

    echo "checking direnv configuration in /etc/direnv/direnv.toml" >&2
    grep 'load_dotenv = true' ${config.out}/etc/direnv/direnv.toml

    echo "checking nix-direnv sourcing in /etc/direnv/direnvrc" >&2
    grep 'source ${nix-direnv}/share/nix-direnv/direnvrc' ${config.out}/etc/direnv/direnvrc
  '';
}
