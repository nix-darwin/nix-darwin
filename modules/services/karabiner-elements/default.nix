{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.karabiner-elements;
in

{
  options.services.karabiner-elements = {
    enable = mkEnableOption "Karabiner-Elements";
    package = mkPackageOption pkgs "karabiner-elements" { };

  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
    ];
    environment.extraAppPaths = [
      "/Library/Application Support/org.pqrs/Karabiner-Elements"
    ];
    services.karabiner-dk = {
      enable = true;
      package = cfg.package.driver;
    };

    system.activationScripts.postActivation.text = ''
      echo "attempt to activate karabiner system extension and start daemons" >&2
      launchctl unload /Library/LaunchDaemons/org.nixos.start_karabiner_daemons.plist
      launchctl load -w /Library/LaunchDaemons/org.nixos.start_karabiner_daemons.plist
    '';

    # We need the karabiner_grabber and karabiner_observer daemons to run after the
    # Nix Store has been mounted, but we can't use wait4path as they need to be
    # executed directly for the Input Monitoring permission. We also want these
    # daemons to auto restart but if they start up without the Nix Store they will
    # refuse to run again until they've been unloaded and loaded back in so we can
    # use a helper daemon to start them. We also only want to run the daemons after
    # the system extension is activated, so we can call activate from the manager
    # which will block until the system extension is activated.
    launchd.daemons.start_karabiner_daemons = {
      script = ''
        launchctl kickstart -k system/org.nixos.start-karabiner-dk
        launchctl kickstart -k system/org.pqrs.service.daemon.karabiner_grabber
        launchctl kickstart -k system/org.pqrs.Karabiner-DriverKit-VirtualHIDDevice-Daemon
      '';
      serviceConfig.Label = "org.nixos.start_karabiner_daemons";
      serviceConfig.RunAtLoad = true;
    };

    launchd.daemons.karabiner_grabber = {
      serviceConfig.ProgramArguments = [
        "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_grabber"
      ];
      serviceConfig.ProcessType = "Interactive";
      serviceConfig.Label = "org.pqrs.service.daemon.karabiner_grabber";
      serviceConfig.KeepAlive.SuccessfulExit = true;
      serviceConfig.KeepAlive.Crashed = true;
      serviceConfig.KeepAlive.AfterInitialDemand = true;
    };

    # Normally karabiner_console_user_server calls activate on the manager but
    # because we use a custom location we need to call activate manually.
    # We need this to run every reboot as /run gets nuked so we can't put this
    # inside the preActivation script as it only gets run on darwin-rebuild switch.
    launchd.daemons.setsuid_karabiner_session_monitor = {
      script = ''
        rm -rf /run/wrappers
        mkdir -p /run/wrappers/bin
        install -m4555 "${cfg.package}/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_session_monitor" /run/wrappers/bin
      '';
      serviceConfig.RunAtLoad = true;
      serviceConfig.KeepAlive.SuccessfulExit = false;
    };
    launchd.user.agents.karabiner_session_monitor = {
      serviceConfig.ProgramArguments = [
        "/bin/sh"
        "-c"
        "/bin/wait4path /run/wrappers/bin && /run/wrappers/bin/karabiner_session_monitor"
      ];
      serviceConfig.Label = "org.pqrs.service.agent.karabiner_session_monitor";
      serviceConfig.KeepAlive = true;
      managedBy = "services.karabiner-elements.enable";
    };

    # from launch agents folder in karabiner elements executable
    environment.userLaunchAgents."org.pqrs.service.agent.karabiner_grabber.plist".source =
      "${cfg.package}/Library/Application Support/org.pqrs/Karabiner-Elements/Karabiner-Elements Non-Privileged Agents.app/Contents/Library/LaunchAgents/org.pqrs.service.agent.karabiner_grabber.plist";
    environment.userLaunchAgents."org.pqrs.service.agent.karabiner_console_user_server.plist".source =
      "${cfg.package}/Library/Application Support/org.pqrs/Karabiner-Elements/Karabiner-Elements Non-Privileged Agents.app/Contents/Library/LaunchAgents/org.pqrs.service.agent.karabiner_console_user_server.plist";
    environment.userLaunchAgents."org.pqrs.service.agent.Karabiner-Menu.plist".source =
      "${cfg.package}/Library/Application Support/org.pqrs/Karabiner-Elements/Karabiner-Elements Non-Privileged Agents.app/Contents/Library/LaunchAgents/org.pqrs.service.agent.Karabiner-Menu.plist";
    environment.userLaunchAgents."org.pqrs.service.agent.Karabiner-MultitouchExtension.plist".source =
      "${cfg.package}/Library/Application Support/org.pqrs/Karabiner-Elements/Karabiner-Elements Non-Privileged Agents.app/Contents/Library/LaunchAgents/org.pqrs.service.agent.Karabiner-MultitouchExtension.plist";
    environment.userLaunchAgents."org.pqrs.service.agent.Karabiner-NotificationWindow.plist".source =
      "${cfg.package}/Library/Application Support/org.pqrs/Karabiner-Elements/Karabiner-Elements Non-Privileged Agents.app/Contents/Library/LaunchAgents/org.pqrs.service.agent.Karabiner-NotificationWindow.plist";

  };
}
