{ config, pkgs, ... }:

{
  # case 1
  # Specify file owner, name, mode, count, size, and when
  services.newsyslog.modules.test1 = {
    "/var/log/case1.log" = {
      owner = "admin";
      mode = "640";
      count = 10;
      size = "1000";
      when = "$D0";
    };
  };

  # Combine two cases into one file to test line merging
  services.newsyslog.modules.test2 = {
    # case 2
    # Specify owner and group
    # case 3
    # Specify pid file and signal
    "/var/log/case2.log" = {
      owner = "nobody";
      group = "admin";
    };
    "/var/log/case3.log" = {
      mode = "600";
      count = 5;
      size = "500";
      when = "$M1D0";
      pathToPidFile = "/var/run/test.pid";
      signalNumber = 1;
    };
    # case 4
    # check for no trailing whitespace when no fields set
    "/var/log/case4.log" = {};
  };


  # test3
  # test for edge cases
  services.newsyslog.modules.test3 = {
  };

  test = ''
    echo >&2 "checking case 1"
    if grep -o '^/var/log/case1.log admin: 640 10 1000 $D0 -$' ${config.out}/etc/newsyslog.d/test1.conf; then
      echo >&2 "ok"
    else
      echo >&2 "case 1 failed. Found:"
      cat ${config.out}/etc/newsyslog.d/test1.conf
      exit 1
    fi

    echo >&2 "checking case 2"
    if grep -o '^/var/log/case2.log nobody:admin 600 10 \* $D0 -' ${config.out}/etc/newsyslog.d/test2.conf; then
      echo >&2 "ok"
    else
      echo >&2 "case 2 failed. Found:"
      cat ${config.out}/etc/newsyslog.d/test2.conf
      exit 1
    fi

    echo >&2 "checking case 3"
    if grep -o '^/var/log/case3.log 600 5 500 $M1D0 - /var/run/test.pid 1$' ${config.out}/etc/newsyslog.d/test2.conf; then
      echo >&2 "ok"
    else
      echo "case 3 failed. Found:"
      cat ${config.out}/etc/newsyslog.d/test2.conf
      exit 1
    fi

    echo >&2 "checking case 4"
    if grep -o '^/var/log/case4.log 600 10 \* $D0 -$' ${config.out}/etc/newsyslog.d/test2.conf; then
      echo >&2 "ok"
    else
      echo >&2 "case 4 failed. Found:"
      tr " " "." < ${config.out}/etc/newsyslog.d/test2.conf
      exit 1
    fi
  '';
}
