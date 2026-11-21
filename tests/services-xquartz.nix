{
  config,
  lib,
  pkgs,
  ...
}:

let
  xquartz = pkgs.runCommand "xquartz-0.0.0" { } ''
    mkdir -p $out/bin $out/libexec $out/etc/X11/xinit/privileged_startx.d
    touch $out/bin/Xquartz $out/bin/startx
    touch $out/libexec/launchd_startx $out/libexec/privileged_startx
  '';
  agent = "${config.out}/Library/LaunchAgents/org.nixos.xquartz.startx.plist";
  daemon = "${config.out}/Library/LaunchDaemons/org.nixos.xquartz.privileged_startx.plist";
in
{
  services.xquartz = {
    enable = true;
    package = xquartz;
    configureSsh = true;
  };

  test = ''
    echo >&2 "checking XQuartz package in /sw/bin"
    test "$(readlink -f ${config.out}/sw/bin/Xquartz)" = "${xquartz}/bin/Xquartz"

    echo >&2 "checking XQuartz LaunchAgent"
    grep -F '${xquartz}/libexec/launchd_startx ${xquartz}/bin/startx -- ${xquartz}/bin/Xquartz' ${agent}
    grep -F '<key>SecureSocketWithKey</key>' ${agent}
    grep -F '<string>DISPLAY</string>' ${agent}
    test ! -e ${config.out}/user/Library/LaunchAgents/org.nixos.xquartz.startx.plist

    echo >&2 "checking XQuartz privileged LaunchDaemon"
    grep -F '${xquartz}/libexec/privileged_startx -d ${xquartz}/etc/X11/xinit/privileged_startx.d' ${daemon}
    grep -F '<key>MachServices</key>' ${daemon}
    grep -F '<key>org.nixos.xquartz.privileged_startx</key>' ${daemon}

    echo >&2 "checking system-wide LaunchAgent activation"
    grep -F "launchctl load -w '/Library/LaunchAgents/org.nixos.xquartz.startx.plist'" ${config.out}/activate

    echo >&2 "checking OpenSSH XAuthLocation"
    grep -F 'XAuthLocation ${lib.getExe pkgs.xauth}' ${config.out}/etc/ssh/ssh_config.d/100-nix-darwin.conf
  '';
}
