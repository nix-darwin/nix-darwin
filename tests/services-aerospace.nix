{ config, pkgs, ... }:

let
  aerospace = pkgs.runCommand "aerospace-0.0.0" { } "mkdir $out";
in

{
  system.primaryUser = "test-aerospace-user";

  services.aerospace.enable = true;
  services.aerospace.package = aerospace;
  services.aerospace.settings = {
    after-startup-command = [ "layout tiles" ];
    gaps = {
      outer.left = 8;
      outer.bottom = 8;
      outer.top = 8;
      outer.right = 8;
    };
    mode.main.binding = {
      alt-h = "focus left";
      alt-j = "focus down";
      alt-k = "focus up";
      alt-l = "focus right";
    };
    on-window-detected = [
      {
        # New recommended form: a `test` command string.
        "if" = ''test %{app-bundle-id} = org.alacritty'';
        run = [ "layout floating" ];
      }
      {
        # New form with a compound condition.
        "if" = ''test %{app-bundle-id} = com.google.Chrome || test %{app-bundle-id} = org.mozilla.firefox'';
        run = "move-node-to-workspace W";
      }
      {
        # Legacy attribute-set form (soft-deprecated, still supported).
        "if" = {
          app-id = "Another.Cool.App";
          during-aerospace-startup = false;
        };
        check-further-callbacks = false;
        run = "move-node-to-workspace m";
      }
      {
        "if".app-name-regex-substring = "finder|calendar";
        run = "layout floating";
      }
      {
        "if".workspace = "1";
        run = "layout h_accordion";
      }
    ];
    workspace-to-monitor-force-assignment = {
        "1" = 1;
        "2" = "main";
        "3" = "secondary";
        "4" = "built-in";
        "5" = "^built-in retina display$";
        "6" = [ "secondary" "dell" ];
    };
  };

  test = ''
    echo >&2 "checking aerospace service in ~/Library/LaunchAgents"
    grep "org.nixos.aerospace" ${config.out}/user/Library/LaunchAgents/org.nixos.aerospace.plist
    grep "${aerospace}/Applications/AeroSpace.app/Contents/MacOS/AeroSpace" ${config.out}/user/Library/LaunchAgents/org.nixos.aerospace.plist

    conf=`sed -En 's/^[[:space:]]*<string>.*--config-path (.*)<\/string>$/\1/p' \
      ${config.out}/user/Library/LaunchAgents/org.nixos.aerospace.plist`

    echo >&2 "checking config in $conf"
    grep 'after-startup-command = \["layout tiles"\]' $conf

    grep 'bottom = 8' $conf
    grep 'left = 8' $conf
    grep 'right = 8' $conf
    grep 'top = 8' $conf

    grep 'alt-h = "focus left"' $conf
    grep 'alt-j = "focus down"' $conf
    grep 'alt-k = "focus up"' $conf
    grep 'alt-l = "focus right"' $conf

    # New (recommended) string form of `on-window-detected.*.if`.
    grep 'if = "test %{app-bundle-id} = org.alacritty"' $conf
    grep 'run = \["layout floating"\]' $conf
    grep 'if = "test %{app-bundle-id} = com.google.Chrome || test %{app-bundle-id} = org.mozilla.firefox"' $conf
    grep 'run = "move-node-to-workspace W"' $conf

    grep 'check-further-callbacks = false' $conf
    grep 'run = "move-node-to-workspace m"' $conf
    grep 'app-id = "Another.Cool.App"' $conf
    grep 'during-aerospace-startup = false' $conf

    grep 'run = "layout floating"' $conf
    grep 'app-name-regex-substring = "finder|calendar"' $conf
    (! grep 'window-title-regex-substring' $conf)
    
    grep 'workspace = "1"' $conf
    grep 'run = "layout h_accordion"' $conf

    grep '1 = 1' $conf
    grep '2 = "main"' $conf
    grep '3 = "secondary"' $conf
    grep '4 = "built-in"' $conf
    grep '5 = "^built-in retina display$"' $conf
    grep '6 = \["secondary", "dell"\]' $conf
  '';
}
