{ pkgs, ... }:

let
  emacs = pkgs.writeTextFile {
    name = "emacs";
    destination = "/bin/tools/Emacs Wrapper";
    executable = true;
    text = ''
      #!${pkgs.runtimeShell}
      printf '%s\n' "$@"
    '';
  };
in
{
  imports = [ ./services-emacs.nix ];
  services.emacs.package = emacs.outPath;
  services.emacs.exec = "tools/Emacs Wrapper";
}
