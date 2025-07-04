{
  lib,
  config,
  pkgs,
  ...
}:

{
  users.knownGroups = [
    "foo"
    "created.group"
    "deleted.group"
  ];
  users.groups.foo.gid = 42000;
  users.groups.foo.description = "Foo group";
  users.groups.foo.members = [
    "admin"
    "foo"
  ];

  users.groups."created.group".gid = 42001;
  users.groups."unknown.group".gid = 42002;

  users.knownUsers = [
    "foo"
    "created.user"
    "deleted.user"
  ];
  users.users.foo.uid = 42000;
  users.users.foo.gid = 42000;
  users.users.foo.description = "Foo user";
  users.users.foo.isHidden = false;
  users.users.foo.home = "/Users/foo";
  users.users.foo.createHome = true;
  users.users.foo.shell = pkgs.bashInteractive;

  users.users."created.user".uid = 42001;
  users.users."created.user".description = null;
  users.users."created.user".home = null;
  users.users."created.user".shell = null;

  users.users."unknown.user".uid = 42002;

  test = ''
    set -v

    # checking group creation in /activate
    grep "dscl . -create ${lib.escapeShellArg "/Groups/foo"} PrimaryGroupID 42000" ${config.out}/activate
    grep "dscl . -create ${lib.escapeShellArg "/Groups/foo"} RealName ${lib.escapeShellArg "Foo group"}" ${config.out}/activate
    grep "dscl . -create ${lib.escapeShellArg "/Groups/created.group"} PrimaryGroupID 42001" ${config.out}/activate
    (! grep "dscl . -delete ${lib.escapeShellArg "/Groups/created.group"}" ${config.out}/activate)

    # checking group deletion in /activate
    grep "dscl . -delete ${lib.escapeShellArg "/Groups/deleted.group"}" ${config.out}/activate
    (! grep "dscl . -create ${lib.escapeShellArg "/Groups/deleted.group"}" ${config.out}/activate)

    echo "checking group membership in /activate" >&2
    grep "dscl . -create ${lib.escapeShellArg "/Groups/foo"} GroupMembership ${
      lib.escapeShellArgs [
        "admin"
        "foo"
      ]
    }" ${config.out}/activate
    grep "dscl . -create ${lib.escapeShellArg "/Groups/created.group"} GroupMembership" ${config.out}/activate

    # checking unknown group in /activate
    # checking groups not in knownGroups don't appear in /activate
    (! grep "dscl . -create ${lib.escapeShellArg "/Groups/unknown.group"}" ${config.out}/activate)
    (! grep "dscl . -delete ${lib.escapeShellArg "/Groups/unknown.group"}" ${config.out}/activate)

    # checking user creation in /activate
    grep "sysadminctl -addUser ${
      lib.escapeShellArgs [
        "foo"
        "-UID"
        42000
        "-GID"
        42000
        "-fullName"
        "Foo user"
        "-home"
        "/Users/foo"
        "-shell"
        "/run/current-system/sw/bin/bash"
      ]
    }" ${config.out}/activate
    grep "createhomedir -cu ${lib.escapeShellArg "foo"}" ${config.out}/activate
    grep "sysadminctl -addUser ${
      lib.escapeShellArgs [
        "created.user"
        "-UID"
        42001
      ]
    } .* ${
      lib.escapeShellArgs [
        "-shell"
        "/usr/bin/false"
      ]
    }" ${config.out}/activate
    grep "sysadminctl -addUser ${lib.escapeShellArg "created.user"} .* ${
      lib.escapeShellArgs [
        "-home"
        "/var/empty"
      ]
    }" ${config.out}/activate
    (! grep "dscl . -delete ${lib.escapeShellArg "/Users/created.user"}" ${config.out}/activate)
    (! grep "dscl . -delete ${lib.escapeShellArg "/Groups/created.user"}" ${config.out}/activate)

    # checking user properties always get updated in /activate
    grep "dscl . -create ${lib.escapeShellArg "/Users/foo"} PrimaryGroupID 42000" ${config.out}/activate
    grep "dscl . -create ${lib.escapeShellArg "/Users/foo"} RealName ${lib.escapeShellArg "Foo user"}" ${config.out}/activate
    grep "createhomedir -cu ${lib.escapeShellArg "foo"}" ${config.out}/activate
    grep "dscl . -create ${lib.escapeShellArg "/Users/foo"} UserShell ${lib.escapeShellArg "/run/current-system/sw/bin/bash"}" ${config.out}/activate
    grep "dscl . -create ${lib.escapeShellArg "/Users/foo"} IsHidden 0" ${config.out}/activate

    # checking user properties that are null don't get updated in /activate
    (! grep "dscl . -create ${lib.escapeShellArg "/Users/created.user"} RealName" ${config.out}/activate)
    (! grep "dscl . -create ${lib.escapeShellArg "/Users/created.user"} UserShell" ${config.out}/activate)

    # checking user deletion in /activate
    grep "dscl . -delete ${lib.escapeShellArg "/Users/deleted.user"}" ${config.out}/activate
    (! grep "sysadminctl -addUser ${lib.escapeShellArg "deleted.user"}" ${config.out}/activate)

    # checking that users not specified in knownUsers doesn't get changed in /activate
    (! grep "sysadminctl -addUser ${lib.escapeShellArg "unknown.user"}" ${config.out}/activate)
    (! grep "dscl . -delete ${lib.escapeShellArg "/Users/unknown.user"}" ${config.out}/activate)
    (! grep "dscl . -create ${lib.escapeShellArg "/Users/unknown.user"}" ${config.out}/activate)

    set +v
  '';
}
