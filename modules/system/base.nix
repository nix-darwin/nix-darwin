{ ... }:

{
  system.activationScripts.createRun.text = ''
    if [[ $(stat -c '%a' /etc/synthetic.conf) != "644" ]]; then
      echo "fixing permissions on /etc/synthetic.conf..."
      chmod 644 /etc/synthetic.conf
    fi

    if [[ $(grep -c '^run\b' /etc/synthetic.conf) -gt 1 ]]; then
      echo "found duplicate run entries in /etc/synthetic.conf, removing..."
      sed -i "" -e '/^run\tprivate\/var\/run$/d' /etc/synthetic.conf
    fi

    if ! grep -q '^run\b' /etc/synthetic.conf 2>/dev/null; then
      echo "setting up /run via /etc/synthetic.conf..."
      printf 'run\tprivate/var/run\n' | tee -a /etc/synthetic.conf >/dev/null
    fi

    /System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -t || true

    if [[ ! -L /run ]]; then
      printf >&2 '[1;31merror: apfs.util failed to symlink /run, aborting activation[0m\n'
      printf >&2 'To create a symlink from /run to /var/run, please run:\n'
      printf >&2 '\n'
      printf >&2 "$ printf 'run\tprivate/var/run\n' | tee -a /etc/synthetic.conf\n"
      printf >&2 '$ sudo /System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -t\n'
      printf >&2 '\n'
      printf >&2 'The current contents of /etc/synthetic.conf is:\n'
      printf >&2 '\n'
      sed 's/^/    /' /etc/synthetic.conf >&2
      printf >&2 '\n'
      exit 1
    fi
  '';
}
