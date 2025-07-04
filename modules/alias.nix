{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let

in

{
  options = {

    networking.networkservices = mkOption {
      internal = true;
      default = null;
    };
    security.enableAccessibilityAccess = mkOption {
      internal = true;
      default = null;
    };
    security.accessibilityPrograms = mkOption {
      internal = true;
      default = null;
    };

  };

  config = {

    assertions = [
      {
        assertion = config.security.enableAccessibilityAccess == null;
        message = "security.enableAccessibilityAccess was removed, it's broken since 10.12 because of SIP";
      }
      {
        assertion = config.system.activationScripts.extraPostActivation.text == "";
        message = "system.activationScripts.extraPostActivation was renamed to system.activationScripts.postActivation";
      }
      {
        assertion = config.system.activationScripts.extraUserPostActivation.text == "";
        message = "system.activationScripts.extraUserPostActivation was renamed to system.activationScripts.postUserActivation";
      }
    ];

    warnings = mkIf (config.networking.networkservices != null) [
      "networking.networkservices was renamed to networking.knownNetworkServices"
    ];

    networking.knownNetworkServices = mkIf (
      config.networking.networkservices != null
    ) config.networking.networkservices;

    system.activationScripts.extraPostActivation.text = mkDefault "";
    system.activationScripts.extraUserPostActivation.text = mkDefault "";

  };
}
