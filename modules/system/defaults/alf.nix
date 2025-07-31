{ lib, ... }:

let
  path = [
    "system"
    "defaults"
    "alf"
  ];
in
{
  imports = [
    (lib.mkRemovedOptionModule (path ++ [ "globalstate" ])
      "Use `networking.applicationFirewall.enable' and `networking.applicationFirewall.blockAllIncoming' instead."
    )
    (lib.mkRemovedOptionModule (
      path ++ [ "allowsignedenabled" ]
    ) "Use `networking.applicationFirewall.allowSigned' instead.")
    (lib.mkRemovedOptionModule (
      path ++ [ "allowdownloadsignedenabled" ]
    ) "Use `networking.applicationFirewall.allowSignedApp' instead.")
    (lib.mkRemovedOptionModule (path ++ [ "loggingenabled" ]) "It's no longer necessary.")
    (lib.mkRemovedOptionModule (
      path ++ [ "stealthenabled" ]
    ) "Use `networking.applicationFirewall.enableStealthMode' instead.")
  ];
}
