{ lib, pkgs, ... }:
with lib;
let 
  mkNullOpt = type: description: mkOption {
    type = types.nullOr type; 
    default = null; 
    inherit description;
  };

  # directly shadows the keys of upstream config options.
  # anything left null falls back to upstream defaults,
  # specified in https://github.com/BlueBubblesApp/bluebubbles-server/blob/9ee91200121888ed9dbe300dfccf8e6d2a8592d2/packages/server/src/server/databases/server/constants.ts#L18-L59
  # descriptions copied from UI field hints, where available: https://github.com/BlueBubblesApp/bluebubbles-server/tree/9ee91200121888ed9dbe300dfccf8e6d2a8592d2/packages/ui/src/app/components/fields
  # only settings omitted here are secrets; cf. `secretFiles` option
  settingsModule.options = {
    tutorial_is_done = mkNullOpt types.bool "Set to `true` to skip the tutorial";
    socket_port = mkNullOpt types.port "This is the port that the HTTP server is running on, and the port you will use when port forwarding for a dynamic DNS";
    # password = mkNullSecret "Path to password for clients to authenticate with the server";

    proxy_service = mkNullOpt (types.enum [
      "cloudflare" "dynamic-dns" "ngrok" "zrok" "lan-url"
    ]) "Select a proxy service to use to make your server internet-accessible. Without one selected, your server will only be accessible on your local network";

    ## proxy-service = "dynamic-dns"
    server_address = mkNullOpt types.str "This is the address that your clients will connect to";

    ## proxy-service = "ngrok"
    #ngrok_key = mkNullOpt types.path ''
    #  Using an Auth Token will allow you to use the benefits of the upgraded Ngrok
    #  service. This can improve connection stability and reliability. It is highly
    #  recommended that you setup an auth token, especially if you are having connection
    #  issues. If you do not have an Ngrok Account, sign up for free here:
    #  https://dashboard.ngrok.com/get-started/your-authtoken
    #'';
    ngrok_protocol = mkNullOpt types.str "";
    ngrok_region = mkNullOpt (types.enum ["us" "eu" "ap" "au" "sa" "jp" "in"]) ''
      Select the region closest to you. This will ensure latency is at its lowest when connecting to the server
    '';
    ngrok_custom_domain = mkNullOpt types.str ''
      On the Ngrok website, you can reserve a subdomain with Ngrok. This allows
      your URL to stay static, and never change. This may improve connectivity
      reliability. To reserve your domain today, go to the following link
      and create a new subdomain. Then copy and paste it into this field:
      https://dashboard.ngrok.com/cloud-edge/domains
    '';

    ## proxy-service = "zrok"
    #zrok_token = mkNullOpt types.path ''
    #  A Zrok Token is required to use the Zrok proxy service. If you do not have one, you can sign up for a free account within BlueBubbles
    #'';
    zrok_reserve_tunnel = mkNullOpt types.bool ''
      Enabling this will create a reserved tunnel with Zrok.
      This means your Zrok URL will be static and never change
    '';
    zrok_reserved_name = mkNullOpt types.str ''
      Reserved Subdomain (Optional): Enter a name to reserve for your Zrok tunnel.
      This name will be used as the subdomain for your Zrok tunnel.
      This name may only be lowercase alpha-numeric characters. If
      left blank, a randomly generated name will be used.
    '';
    # zrok_reserved_token = mkNullOpt types.path ""; # ??


    use_custom_certificate = mkNullOpt types.bool ''
      This will install a self-signed certificate at: `~/Library/Application Support/bluebubbles-server/Certs`
      Note: Only use this option if you have your own certificate! 
      Replace the certificates in the `Certs` directory
    '';
    auto_caffeinate = mkNullOpt types.bool ''
      When enabled, your Mac will not fall asleep due to inactivity or a screen screen saver.
      However, your computer lid's close action may override this.
      Make sure your computer does not go to sleep when the lid is closed.
    '';

    hide_dock_icon = mkNullOpt types.bool ''Hiding the dock icon will not close the app. You can open the app again via the status bar icon'';
    dock_badge = mkNullOpt types.bool "Disable this to hide the notifications badge in the dock";

    check_for_updates = mkNullOpt types.bool "When enabled, BlueBubbles will automatically check for updates on startup";
    enable_private_api = mkNullOpt types.bool "If you have set up the Private API features, enable this option to allow the server to comunicate with the iMessage Private APIs. This will run an instance of the Messages app with our helper dylib injected into it. Enabling this will allow you to send reactions, replies, editing, effects, use FindMy, etc.";
    enable_ft_private_api = mkNullOpt types.bool "If you have set up the Private API features, enabling this option will allow the server to communicate with the FaceTime Private APIs. This will run an instance of the FaceTime app with our helper dylib injected into it. Enabling this will allow the server to detect incoming FaceTime calls";
    use_oled_dark_mode = mkNullOpt types.bool "Enabling this will set the dark mode theme to OLED black";
    db_poll_interval = mkNullOpt types.ints.positive "Enter how often (in milliseconds) you want the server to check for new messages in the database";

    private_api_mode = mkNullOpt (types.enum ["process-dylib" "macforge"]) ''
      Select how you want the BlueBubbles Private API Helper Bundle to be injected into the Messages App. 
      Selecting "MacForge Bundle" will require MacForge to be installed. Selecting "Messages App DYLIB" will 
      attempt to inject the bundle into the Messages App directly.
    '';
    start_delay = mkNullOpt types.str "Enter the number of seconds to delay the server start by. This is useful on older hardware";
    start_minimized = mkNullOpt types.bool "When enabled, the BlueBubbles Server will be minimized after starting up";
    facetime_calling = mkNullOpt types.bool "(Experimental) When enabled, the server will detect incoming FaceTime calls and forward a notification to your device. If you choose to answer the call from the notification, the server will attempt to generate a link for you to join with";

    landing_page_path = mkNullOpt types.path "Path to custom landing page HTML";
    open_findmy_on_startup = mkNullOpt types.bool ''
      When enabled, BlueBubbles will automatically open, then hide the FindMy app when the server starts.
      This is to trigger the fetch of locations from the FindMy app so the server can cache them for clients.
    '';
    auto_lock_mac = mkNullOpt types.bool ''
      When enabled, your Mac will be automatically locked when the BlueBubbles Server detects that it has just booted up.
      The criteria for this is that the uptime for your Mac is less than 5 minutes.
    '';

    ## App tray settings. No upstream helptext; descriptions mine.
    headless = mkNullOpt types.bool ''
      Suppresses window creation at launch. App still requires a logged-in user session 
      (cannot be daemonized), and  (depending on other settings) may open other windows 
      (e.g. FindMy, Messages, FaceTime) to inject custom dylibs / force updates.
    ''; 

    ## hidden / unavailable in UI
    ## including with {visible = false;} for completeness, 
    ## despite being unfinished / not intended for config by users
    encrypt_coms = mkOption {
      default = null;
      visible = false;
      type = types.nullOr types.bool;
      # From unused UI module field hint / help text
      description = ''
        Enabling this will add an additional layer of security to the app communications by encrypting messages with a password-based AES-256-bit algorithm
      '';
    };
    last_fcm_restart = mkOption {
      default = null;
      visible = false;
      type = types.nullOr types.str;
      # Wholly undocumented upstream; text below _de moi_
      description = ''
        Last restart date of FCM; cf. `packages/server/src/server/services/fcmService/index.ts`
      '';
    };


    ## required default settings for compatibility with Nix / nix-darwin module
    ## (hence: { visible = false; internal = true; })
    auto_start = mkOption {
      # by virtue of the module being enabled, we want to auto-start
      # but this is controlled by Nix (a Nix-managed LaunchAgent),
      # not the application itself, hence, default = false;
      default = false;
      internal = true;
      visible = false;
      type = types.nullOr types.bool;
      description = ''
        When enabled, BlueBubbles will start automatically when you login to your computer.
      '';
    };
    auto_start_method = mkOption {
      # for same reason above, default to "unset"
      default = "unset";
      internal = true;
      visible = false;
      type = types.nullOr (types.enum [
        "none" "unset" "login-item" "launch-agent"
      ]);
      description = ''
        Select whether you want the BlueBubbles Server to automatically start when you login to your computer.
        The "Launch Agent" option will let BlueBubbles restart itself, even after a hard crash. If you try to
        switch away from the "Launch Agent" method, the server may automatically close itself.
      '';
    };
    auto_install_updates = mkOption {
      # updates are managed by Nix
      default = false;
      internal = true;
      visible = false;
      type = types.nullOr types.bool;
      description = ''
        When enabled, BlueBubbles will auto-install the latest available version when an update is detected
      '';
    };
    start_via_terminal = mkOption {
      # app should always be being launched by the LaunchAgent, never through the GUI
      # further, this kind of fork-and-kill is likely to cause issues with LaunchAgents, as to the
      # agent it will appear as though the process has died and needs to be restarted.
      default = false;
      internal = true;
      visible = false;
      type = types.nullOr types.bool;
      description = ''
        When BlueBubbles starts up, it will auto-reload itself in terminal mode.
        When in terminal, type "help" for command information.
      '';
    };
    disable_gpu = mkOption {
      # https://github.com/BlueBubblesApp/bluebubbles-server/issues/726
      # must be disabled when running as a LaunchAgent
      default = false;
      internal = true;
      visible = false;
      type = types.nullOr types.bool;
      description = ''
        "[A]dds flags to the executable to disable gpu utilization through electron"; 
        conflicts with running as a LaunchAgent
      '';
    };
  };
in {
  inherit settingsModule;
}