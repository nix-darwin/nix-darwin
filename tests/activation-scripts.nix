{ config, pkgs, ... }:

{
  system.activationScripts.preActivation.text = "echo hook preActivation";
  system.activationScripts.extraActivation.text = "echo hook extraActivation";
  system.activationScripts.postActivation.text = "echo hook postActivation";

  test = ''
    countHooks() {
      awk '/echo hook / {i++ ; print i " => " $0}' "$2" | grep "$1"
    }

    echo checking activation hooks in /activate >&2
    countHooks "1 => echo hook preActivation" ${config.out}/activate
    countHooks "2 => echo hook extraActivation" ${config.out}/activate
    countHooks "3 => echo hook postActivation" ${config.out}/activate
  '';
}
