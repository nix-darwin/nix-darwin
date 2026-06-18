# Shell assertion helpers for nix-darwin tests.
# Source this file from a test's `test` block: . ${./lib/assertions.sh}

normalizeStorePaths() {
  # Keep alphabetic-led name segments; drop trailing numeric version suffix.
  # Regex mirrors nmt's bash-lib/assertions.sh normalizeStorePaths.
  sed -E 's!/nix/store/[a-z0-9]{32}((-[a-zA-Z][a-zA-Z0-9+._?=]*)*)(-[a-zA-Z0-9+._?=-]*)?!/nix/store/00000000000000000000000000000000\1!g' "$1"
}

assertFileContent() {
  local actual="$1" expected="$2"
  if ! diff -u --label expected --label actual \
      <(cat "$expected") \
      <(normalizeStorePaths "$actual"); then
    echo "FAIL: $actual differs from $expected" >&2
    exit 1
  fi
}
