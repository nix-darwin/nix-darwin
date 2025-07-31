{
  config,
  ...
}:

{
  system.newsyslog = {
    enable = true;

    files = {
      myapp = [
        {
          logfilename = "/var/log/myapp.log";
          owner = "myuser";
          group = "wheel";
          mode = "644";
          count = 7;
          size = "4096";
          flags = [
            "Z"
            "C"
          ];
          pidFile = "/var/run/myapp.pid";
          signal = "USR1";
        }
        {
          logfilename = "/var/log/myapp-debug.log";
          owner = "myuser";
          mode = "600";
          count = 3;
          size = "2048";
          flags = [ "Z" ];
        }
      ];

      system = [
        {
          logfilename = "/var/log/system.log";
          mode = "644";
          count = 5;
          when = "@T00";
          flags = [ "Z" ];
        }
        {
          logfilename = "/var/log/mail.log";
          group = "mail";
          mode = "640";
          count = 10;
          size = "1024";
          flags = [
            "B"
            "Z"
          ];
          pidFile = "/var/run/syslogd.pid";
        }
      ];

      minimal = [
        {
          logfilename = "/tmp/test.log";
          mode = "644";
          count = 2;
          size = "100K";
        }
      ];

      both-size-when = [
        {
          logfilename = "/var/log/both.log";
          mode = "644";
          count = 3;
          size = "2048";
          when = "@T12";
          flags = [ "Z" ];
        }
      ];

      empty-flags = [
        {
          logfilename = "/var/log/empty-flags.log";
          mode = "644";
          count = 1;
          size = "1024";
        }
      ];

      pidfile-empty-flags = [
        {
          logfilename = "/var/log/pidfile-empty-flags.log";
          mode = "644";
          count = 1;
          size = "1024";
          pidFile = "/var/run/pidfile-empty-flags.pid";
        }
      ];
    };
  };

  test = ''
    set -e

    check_pattern() {
      local pattern="$1"
      local file="$2"
      echo "--> Checking for pattern: '$pattern'"
      echo "    in file:              '$file'"

      if grep --color=never -E "$pattern" "$file"; then
        echo "    +++ PASS: Pattern found."
        echo
      else
        echo "    --- FAIL: Pattern NOT found."
        exit 1
      fi
    }

    echo "checking newsyslog.d configuration files exist"
    test -f ${config.out}/etc/newsyslog.d/myapp.conf
    test -f ${config.out}/etc/newsyslog.d/system.conf
    test -f ${config.out}/etc/newsyslog.d/minimal.conf
    test -f ${config.out}/etc/newsyslog.d/both-size-when.conf
    test -f ${config.out}/etc/newsyslog.d/empty-flags.conf
    test -f ${config.out}/etc/newsyslog.d/pidfile-empty-flags.conf

    echo
    echo "checking file content patterns"
    check_pattern "myuser:wheel.*644.*7.*4096.*\*.*ZC.*USR1"   ${config.out}/etc/newsyslog.d/myapp.conf
    check_pattern "myuser:.*600.*3.*2048.*\*.*Z"               ${config.out}/etc/newsyslog.d/myapp.conf
    check_pattern "system.log.*644.*5.*\*.*@T00.*Z"          ${config.out}/etc/newsyslog.d/system.conf
    check_pattern ":mail.*640.*10.*1024.*\*.*BZ"               ${config.out}/etc/newsyslog.d/system.conf
    check_pattern "test.log.*644.*2.*100K.*\*"               ${config.out}/etc/newsyslog.d/minimal.conf
    check_pattern "both.log.*644.*3.*2048.*@T12.*Z"            ${config.out}/etc/newsyslog.d/both-size-when.conf
    check_pattern "empty-flags.log.*644.*1.*1024.*\*"          ${config.out}/etc/newsyslog.d/empty-flags.conf
    check_pattern "pidfile-empty-flags.log.*644.*1.*1024.*\*.*-.*pidfile-empty-flags.pid" ${config.out}/etc/newsyslog.d/pidfile-empty-flags.conf

    # Verify no colons in minimal.conf (no owner/group)
    echo "--> Verifying no colons in minimal.conf"
    if grep -v "^#" ${config.out}/etc/newsyslog.d/minimal.conf | grep -q ":"; then
      echo "    --- FAIL: minimal.conf should not contain colons"
      exit 1
    else
        echo "    +++ PASS: No colons found."
    fi

    # Verify group-only format
    echo "--> Verifying group-only format in system.conf"
    if ! grep -q ":mail" ${config.out}/etc/newsyslog.d/system.conf; then
      echo "    --- FAIL: Did not find group-only format ':mail'"
      exit 1
    else
      echo "    +++ PASS: Found group-only format."
    fi

    echo
    echo "All tests passed successfully."
  '';
}
