{ config, pkgs, ... }:

let
  contents = "Hello, world!";
  jq = pkgs.lib.getExe pkgs.jq;
in

{
  system.file."tmp/hello.txt".text = contents;

  test = ''
    echo 'checking that system links file exists' >&2
    test -e ${config.out}/links.json

    echo 'checking links file version' >&2
    test "$(${jq} .version ${config.out}/links.json)" = "1"

    echo 'checking that test file is in links.json' >&2
    test ! "$(${jq} '.files."/tmp/hello.txt"' ${config.out}/links.json)" = "null"

    echo 'checking that test file is a link' >&2
    test "$(${jq} '.files."/tmp/hello.txt".type == "link"' ${config.out}/links.json)" = "true"

    echo 'checking that the link source is correct' >&2
    diff <(${jq} -r '.files."/tmp/hello.txt".source' ${config.out}/links.json) <(echo ${config.system.file."tmp/hello.txt".source})

    # I wanted to check the contents of the file as well, but I am prevented from doing so, I think by the sandbox
    # echo 'checking that the link source has the correct contents' >&2
    # diff "$(${jq} '.files."/tmp/hello.txt".source' ${config.out}/links.json)" <(echo ${contents}) # >/dev/null
    # # grep '${contents}' "$(${jq} '.files."/tmp/hello.txt".source' ${config.out}/links.json)"
  '';
}
