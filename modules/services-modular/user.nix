{ config, lib, pkgs, ... }:
let
  inherit (lib) concatMapAttrs mapAttrs' mkOption types;

  translate = import ./translate.nix { inherit lib; };

  userRootPath = userName: "/Users/${userName}/.config/system-services";

  # Build a per-user serviceSubmodule type with the user's home baked
  # into configData paths.
  servicesLibFor = userName:
    import ./lib.nix {
      inherit lib pkgs;
      rootPath = userRootPath userName;
    };

  agentEntries = userName: topName: top:
    let
      flat = translate.flatten { kind = "userAgent"; } topName top;
    in
    lib.mapAttrs (entryName: entry: entry // {
      managedBy = "users.users.${userName}.services.${topName}";
    }) flat;

  # Collect (name -> serviceTree) for a single user's services.
  agentsForUser = userName: services:
    concatMapAttrs (n: service: agentEntries userName n service) services;

  # Build the configData tree for a single user as a store derivation
  # whose entries we ln -sfn into ~user/.config/system-services at
  # activation time.
  configDataTreeFor = userName: services:
    let
      collect = prefix: service:
        let
          own = mapAttrs' (_: cfg: {
            name = "${prefix}/${cfg.name}";
            value = { inherit (cfg) source; };
          }) (lib.filterAttrs (_: cfg: cfg.enable) (service.configData or { }));
          subs = concatMapAttrs (
            n: sub: collect (translate.dash prefix n) sub
          ) (service.services or { });
        in
        own // subs;
      entries = concatMapAttrs (n: service: collect n service) services;
    in
    pkgs.runCommand "user-services-${userName}" { preferLocalBuild = true; } ''
      mkdir -p $out
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (rel: { source }: ''
          mkdir -p "$out/$(dirname ${lib.escapeShellArg rel})"
          ln -s ${lib.escapeShellArg "${source}"} "$out/${rel}"
        '') entries
      )}
    '';

  usersWithServices = lib.filterAttrs (_: user: user.services != { }) config.users.users;

  # Generate the activation snippet that materializes configData files
  # under ~user/.config/system-services for each user. The whole
  # per-user tree is a single store path; we expose it as a single
  # symlink at the well-known location so the per-file `path`s
  # (e.g. ~user/.config/system-services/foo/hello.conf) resolve
  # correctly through the symlink.
  activationSnippet =
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (
        userName: user:
        let
          tree = configDataTreeFor userName user.services;
          escUser = lib.escapeShellArg userName;
        in
        ''
          sudo --user=${escUser} -- mkdir -p ~${escUser}/.config
          sudo --user=${escUser} -- ln -sfn ${tree} ~${escUser}/.config/system-services
        ''
      ) usersWithServices
    );
in
{
  options.users.users = mkOption {
    type = types.attrsOf (types.submodule (
      { name, ... }:
      {
        options.services = mkOption {
          type = types.attrsOf (servicesLibFor name).serviceSubmodule;
          default = { };
          description = ''
            Modular services run as LaunchAgents for this user.

            Only honored for the primary user (`system.primaryUser`);
            other users' services are evaluated but not loaded since
            nix-darwin only manages the primary user's launchd domain.
          '';
          visible = "shallow";
        };
      }
    ));
  };

  config = {
    launchd.user.agents = concatMapAttrs (
      userName: user: agentsForUser userName user.services
    ) usersWithServices;

    assertions =
      lib.concatLists (
        lib.mapAttrsToList (
          userName: user:
          lib.concatLists (
            lib.mapAttrsToList (
              n: service:
              (servicesLibFor userName).getAssertions
                [ "users" "users" userName "services" n ] service
            ) user.services
          )
        ) usersWithServices
      )
      ++ lib.concatLists (
        lib.mapAttrsToList (
          userName: user:
          lib.concatLists (lib.mapAttrsToList (n: service:
            let
              userAgentChecks = service: [
                {
                  assertion = service.processConfig.user == null;
                  message = ''
                    `users.users.${userName}.services.${n}.processConfig.user`
                    is set, but launchd user agents always run as the
                    owning user. Remove `processConfig.user` or move
                    the service to `system.services`.
                  '';
                }
                {
                  assertion = service.processConfig.group == null;
                  message = ''
                    `users.users.${userName}.services.${n}.processConfig.group`
                    is set, but launchd user agents inherit the user's
                    primary group. Remove `processConfig.group` or move
                    the service to `system.services`.
                  '';
                }
              ];
            in
            userAgentChecks service
          ) user.services)
        ) usersWithServices
      );

    warnings = lib.concatLists (
      lib.mapAttrsToList (
        userName: user:
        lib.concatLists (lib.mapAttrsToList (n: service:
          (servicesLibFor userName).getWarnings
            [ "users" "users" userName "services" n ] service
        ) user.services)
      ) usersWithServices
    );

    system.activationScripts.userLaunchd.text =
      lib.mkIf (usersWithServices != { }) (lib.mkAfter activationSnippet);
  };
}
