{
  config,
  pkgs,
  ...
}:
let
  kanata =
    pkgs.runCommand "kanata-0.0.0"
      {
        # The kanata service runs kanata before building the config to check if it's valid.
        # Since we don't use the real binary here we point it to a fake-kanata
        # that always returns true when invoked.
        meta.mainProgram = "fake-kanata";
      }
      ''
        mkdir $out
        mkdir $out/bin
        cat <<EOF > $out/bin/fake-kanata
        #!/usr/bin/env bash
        true
        EOF
        chmod +x $out/bin/fake-kanata
      '';
in

{
  system.primaryUser = "test-kanata-user";

  services.kanata.enable = true;
  services.kanata.package = kanata;

  services.kanata.keyboards.internal = {
    devices = [ "Apple Internal Keyboard / Trackpad" ];
    extraDefCfg = ''
      danger-enable-cmd yes
      process-unmapped-keys yes
    '';
    config = ''
      (defsrc
          esc  f1   f2   f3   f4   f5   f6   f7   f8   f9   f10  f11  f12
          IntlBackslash 1    2    3    4    5    6    7    8    9    0    -    =    bspc
          tab  q    w    e    r    t    y    u    i    o    p    [    ]
          caps a    s    d    f    g    h    j    k    l    ;    '    \    ret
          lsft Backquote  z    x    c    v    b    n    m    ,    .    /    rsft
          fn   lctl lalt lmet           spc            rmet ralt
      )

      (deflayer base
          @esc  🔅   🔆    ✗    ✗    ✗    ✗    ◀◀   ▶⏸   ▶▶   🔇   🔉   🔊
          @grv 1    2    3    4    5    6    7    8    9    0    -    =    bspc
          tab  q    w    e    r    t    y    u    i    o    p    [    ]
          @cap a    s    d    f    g    h    j    k    _    _    '    \    ret
          lsft lsft  z    x    c    v    b    n    m    ,    .    /    rsft
          lctl   lctl lalt lmet           spc            rmet ralt
      )

      (deflayer mylayer
          @esc  _   _    _    _    _    _    _   _   _   _   _   _
          @grv lrld  lrld-next    _    _    _    _    _    _    _    _    _    _    _
          _  _    _    _    _    _    _    _    _    _    _    _    _
          _ _    _    _    _    _    left    down    up    right    _    _    _    _
          _ _  _    _    _    _    _    _    _    _    _    _    _
          _   _ _ _           _            _ _
      )

      (defalias
        cap (tap-hold-press 200 200 esc lctl)
        grv (tap-hold-press 200 200 grv (layer-toggle mylayer))
        esc (tap-hold-press 200 200 esc (layer-toggle mylayer))
      )
    '';
  };

  test = ''
    echo >&2 "checking kanata service in /Library/LaunchDaemons"
    plist="${config.out}/Library/LaunchDaemons/org.nixos.kanata.plist"

    grep "org.nixos.kanata" $plist
    echo >&2 "hello world"
    cat $plist
    echo >&2 "checking for ${kanata}"
    grep "${kanata}" $plist
    echo >&2 "goodbye world"

    conf=`sed -n 's/^ *--cfg \(.*\) \\\/\1/p' \
      $plist`

    echo >&2 "checking config in $conf"
    grep "\"Apple Internal Keyboard / Trackpad\"" $conf

    grep "process-unmapped-keys yes" $conf
  '';
}
