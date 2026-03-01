{config, lib, pkgs, ...}:
with lib;
let 
  inherit (import ./settings.nix { inherit lib pkgs; }) settingsModule;

  mkSecret = description: mkOption {
    type = types.nullOr types.path;
    default = null;
    inherit description;
    example = "/run/secrets/sops-secret";
    # ensure it isn't added to the store
    apply = final: if final == null then null else toString final;
  };

  secretsModule.options = {
    password = mkSecret ''
      Path to file containing password value, "for clients to authenticate with the server". 
      A password must be set here or through the GUI. 
    '';
    ngrok_key = mkSecret ''
      Path to file containing ngrok_key value. "Using an Auth Token will allow you to use the benefits of the upgraded Ngrok
      service. This can improve connection stability and reliability. It is highly
      recommended that you setup an auth token, especially if you are having connection
      issues. If you do not have an Ngrok Account, sign up for free here:
      https://dashboard.ngrok.com/get-started/your-authtoken"
    '';
    zrok_token = mkSecret ''
      Path to file containing zrok_token value. 
      "A Zrok Token is required to use the Zrok proxy service. 
      If you do not have one, you can sign up for a free account within BlueBubbles"
    '';
    zrok_reserved_token = mkSecret ''
      Path to file containing zrok_reserved_token value. No upstream documentation available.
    '';
  };

  # present while bluebubbles-server is running
  lockPath = "Library/Application Support/bluebubbles-server/SingletonLock";
  logDir = "Library/Logs/bluebubbles-server";
  exePath = "Applications/BlueBubbles.app/Contents/MacOS/BlueBubbles";
  # upstream appId is `com.BlueBubbles.BlueBubbles-Server`, but website is `https://bluebubbles.app`.
  # (https://github.com/BlueBubblesApp/bluebubbles-server/blob/95204ac18513fffcbb76cafed26008952e8346b3/packages/server/scripts/electron-builder-config.js#L5)
  # to conform with reverse domain name notation, I'm opting to use `app.bluebubbles.*` for LaunchAgents
  agentPrefix = "app.bluebubbles";

  cfg = config.services.bluebubbles-server;
in
{
  options.services.bluebubbles-server = {
    enable = mkEnableOption "BlueBubbles Server";
    package = mkPackageOption pkgs "bluebubbles-server" { };
    settings = mkOption {
      default = { };
      description = ''
        Settings for the server; passed as CLI args.
      '';
      example = literalExpression ''
        {
          socket_port = 1234;
          server_address = "https://imsg.my-website.com";
          proxy_service = "dynamic-dns";

          enable_private_api = true;
          enable_ft_private_api = true;

          auto_caffeinate = true;
          open_findmy_on_startup = true;
          auto_lock_mac = true;

          headless = true;
          hide_dock_icon = true;
          dock_badge = false;

          tutorial_is_done = true;
          check_for_updates = false;
        }
      '';
      type = types.submoduleWith { modules = [settingsModule]; };
    };

    secretFiles = mkOption {
      type = types.submoduleWith { modules = [ secretsModule ]; };
      default = { };
      description = ''
        Files providing secrets for the server. 
        Passed as CLI args at launch: `--secret-key-name=$(<"secret-file-path")`
      '';
    };

    webhooks = mkOption {
      type = types.listOf (types.submodule {
        options = {
          url = mkOption {
            type = types.str;
            default = null;
            example = "https://ntfy-sh.my-website.com/upasdfQ1FZ9LOX?up=1";
            description = ''
              URL for the webhook
            '';
          };
          events = mkOption {
            # events can be either all (["*"]) or one of
            # https://github.com/BlueBubblesApp/bluebubbles-server/blob/95204ac18513fffcbb76cafed26008952e8346b3/packages/server/src/server/events.ts
            # better way to represent literal ["*"]?
            type = with types; either (listOf (enum ["*"])) (listOf (enum [
              "scheduled-message-error"
              "scheduled-message-sent"
              "scheduled-message-deleted"
              "scheduled-message-updated"
              "scheduled-message-created"
              "new-message"
              "message-send-error"
              "updated-message"
              "new-server"
              "participant-removed"
              "participant-added"
              "participant-left"
              "group-icon-changed"
              "group-icon-removed"
              "chat-read-status-changed"
              "hello-world"
              "typing-indicator"
              "server-update"
              "server-update-downloading"
              "server-update-installing"
              "group-name-change"
              "incoming-facetime"
              "settings-backup-created"
              "settings-backup-deleted"
              "settings-backup-updated"
              "theme-backup-created"
              "theme-backup-deleted"
              "theme-backup-updated"
              "imessage-aliases-removed"
              "ft-call-status-changed"
              "new-findmy-location"
            ]));
            default = ["*"];
            example = [ "new-message" "updated-message" ];
            description = ''
              List of events to subscribe to for this webhook. 
              Use `["*"]` to subscribe to all events.
            '';
          };
        };
      });
      default = [ ];
      example = literalExpression ''
        [
          {
            url = "https://ntfy-sh.my-website.com/upasdfQ1FZ9LOX?up=1";
            events = [ "*" ]; # all events
          }
          {
            url = "https://example.com/webhook";
            events = [ "new-message" "updated-message" ];
          }
        ]
      '';
      description = ''
        List of webhooks to set up on the server, such as 
        [UnifiedPush notifications](https://docs.bluebubbles.app/client/usage-guides/using-unified-push-for-notifications).  
        To configure webhooks through Nix, the password must also be set through Nix 
        ({option}`secretFiles.password`), 
        as webhooks are managed through authenticated cURLs to the REST API.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = !(cfg.secretFiles.password == null && cfg.webhooks != []);
        message = ''
          For webhooks to be Nix-managed, you must also set the password ({option}`secretFiles.password`) 
          through Nix, as webhooks are set up through authenticated cURLs to the REST API.
        '';
      }
    ];
    warnings = mkIf (cfg.webhooks != [] && cfg.settings.socket_port == null) [
      ''
        Webhooks are set up through the REST API. As {option}`settings.socket_port` is not set, 
        it is assumed the server is running on the default port (1234); if this has been changed 
        imperatively/externally, webhook setup will fail. 
        Explicitly set the port to suppress this warning.
      ''
    ];

    environment.systemPackages = [ cfg.package ];

    system.requiresPrimaryUser = [ "services.bluebubbles-server.enable" ];

    launchd.user.agents = {
      bluebubbles-server = {
        script = ''
          exec ${cfg.package}/${exePath} ${concatStringsSep " "
            ((
              mapAttrsToList 
              (k: v: 
                "--${k} \"${if builtins.isBool v
                  then (
                    # Bools by default stringify to "0"/"1"
                    if v
                    then "true"
                    else "false"
                  )
                  else toString v
                }\"") 
              (lib.filterAttrs (_: v: v != null) cfg.settings)
            ) ++ 
            ( 
              # script executed in stdenv.shell (bash), so we can use `$(<file)` (else would need cat/read)
              # to read file contents at runtime & avoid adding secrets to the store
              # Do something to trim whitespace? 
              mapAttrsToList
              (k: v: "--${k} \"$(<\"${v}\")\"")
              (lib.filterAttrs (_: v: v != null) cfg.secretFiles)
            ))}
        '';
        serviceConfig = let 
          label = "server"; 
        in {
          KeepAlive = true;
          RunAtLoad = true;
          Label = "${agentPrefix}.${label}";
          StandardErrorPath = "${config.system.primaryUserHome}/${logDir}/${label}.log";
          StandardOutPath = "${config.system.primaryUserHome}/${logDir}/${label}.log";
          ProcessType = "Interactive"; # do not throttle
        };
      };

      bluebubbles-set-webhooks = mkIf (cfg.webhooks != []) {
        # while there is no direct way to declaratively specify webhooks, there are undocumented REST API endpoints 
        # cf. https://github.com/BlueBubblesApp/bluebubbles-server/blob/95204ac18513fffcbb76cafed26008952e8346b3/packages/server/src/server/api/http/api/v1/httpRoutes.ts#L666-L687
        # list webhooks  = GET    api/v1/webhook
        # create webhook = POST   api/v1/webhook
        # delete webhook = DELETE api/v1/webhook/{id}
        # ping = GET api/v1/ping
        # for all of these, must be authenticated with the server password, by passing as param (guid, password, or token; all aliases)
        # so, to setup webhooks, we cURL the endpoints, first getting the existing webhooks, deleting them, and creating new ones
        script = let
          jq = "${pkgs.jq}/bin/jq";
          curl = "${pkgs.curl}/bin/curl";
          lockFile = "${config.system.primaryUserHome}/${lockPath}";
        in
          ''
          set -euo pipefail

          log() {
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
          }

          call_api() {
            local method="$1"
            local endpoint="$2"
            local data="$3"

            local url="http://127.0.0.1:${
              if cfg.settings.socket_port != null 
              then toString cfg.settings.socket_port 
              else "1234"
            }/api/v1/''${endpoint}?password=$(<"${cfg.secretFiles.password}")"


            if [ -n "$data" ]; then
              ${curl} -s -X "$method" "$url" \
                -H "Content-Type: application/json" \
                -d "$data"
            else
              ${curl} -s -X "$method" "$url"
            fi
          }

          get_webhooks() {
            local response=$(call_api "GET" "webhook" "")
            local status=$(echo "$response" | ${jq} '.status')
            if [ "$status" -ne 200 ]; then
              log "Failed to fetch webhooks: $($response | ${jq})"
              exit 1
            fi
            echo "$response" 
          }
          get_webhook_ids() {
            get_webhooks | ${jq} -c '.data[].id'
          }
          delete_webhook() {
            call_api "DELETE" "webhook/$1" "" | ${jq} '.status'
          }
          create_webhook() {
            call_api "POST" "webhook" "$1" | ${jq} '.status'
          }
          ping_api() {
            call_api "GET" "ping" "" | ${jq} '.status'
          }


          # if triggered by lockfile disappearance, rather than creation, quit
          # if [ ! -e "${lockFile}" ]; then
          #  log "Lockfile missing, exiting."
          #  exit 0;
          #fi

          # else, server just started, wait for the ping to return OK
          log "Server running, waiting for API to be ready..."

          MAX_RETRIES=30
          RETRY_DELAY=2
          RETRIES=0
          while [ $RETRIES -lt $MAX_RETRIES ]; do
            status=$(ping_api)
            if [ $status -eq 200 ]; then
              log "Server is ready!"
              break
            fi
            log "Waiting for server... (attempt $((RETRIES + 1))/$MAX_RETRIES)"
            sleep $RETRY_DELAY
            RETRIES=$((RETRIES + 1))
          done
          
          if [ $RETRIES -eq $MAX_RETRIES ]; then
            log "Server failed to become ready after $MAX_RETRIES attempts"
            exit 1
          fi
          
          log "Cleaning up existing webhooks..."
          get_webhook_ids | while read -r ID; do
            if [ -n "$ID" ]; then
              log "Deleting webhook $ID"
              if [ $(delete_webhook "$ID") -ne 200 ]; then
                log "Failed to delete webhook $ID"
                exit 1
              fi
            fi
          done
          
          ${lib.concatMapStringsSep "\n" (webhook: ''
            log "Creating webhook for \"${webhook.url}\"..."
            if [ $(create_webhook '${builtins.toJSON webhook}') -ne 200 ]; then
              log "Failed to create webhook for \"${webhook.url}\""
              exit 1
            fi
          '') cfg.webhooks}

          log "Setup complete. Webhooks: $(get_webhooks | ${jq} '.data')"
        '';
        serviceConfig = let 
          label = "set-webhooks";
        in {
          # lockfile present while bluebubbles-server is running
          WatchPaths = [ "${config.system.primaryUserHome}/${lockPath}" ];
          RunAtLoad = true;
          Label = "${agentPrefix}.${label}";
          StandardErrorPath = "${config.system.primaryUserHome}/${logDir}/${label}.log";
          StandardOutPath = "${config.system.primaryUserHome}/${logDir}/${label}.log";
        };
      };

    };

  };

  meta.maintainers = [
    maintainers.zacharyweiss or "zacharyweiss"
  ];
}
