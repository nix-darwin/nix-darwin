{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Discover the macOS tool shims and their dispatchers with:
  # find /usr/bin -samefile /usr/bin/git -print | sort
  commands = [
    "DeRez"
    "GetFileInfo"
    "ResMerger"
    "Rez"
    "SetFile"
    "SplitForks"
    "actool"
    "agvtool"
    "ar"
    "as"
    "asa"
    "bison"
    "bm4"
    "c++"
    "c++filt"
    "c89"
    "c99"
    "cc"
    "clang"
    "clang++"
    "clangd"
    "cmpdylib"
    "codesign_allocate"
    "cpp"
    "ctags"
    "ctf_insert"
    "desdp"
    "dsymutil"
    "dwarfdump"
    "dyld_info"
    "flex"
    "flex++"
    "g++"
    "gatherheaderdoc"
    "gcc"
    "gcov"
    "genstrings"
    "git"
    "git-receive-pack"
    "git-shell"
    "git-upload-archive"
    "git-upload-pack"
    "gm4"
    "gnumake"
    "gperf"
    "hdxml2manxml"
    "headerdoc2html"
    "ibtool"
    "ictool"
    "indent"
    "install_name_tool"
    "ld"
    "lex"
    "libtool"
    "lipo"
    "lldb"
    "llvm-g++"
    "llvm-gcc"
    "lorder"
    "m4"
    "make"
    "mig"
    "nm"
    "nmedit"
    "objdump"
    "opendiff"
    "otool"
    "pagestuff"
    "pip3"
    "python3"
    "ranlib"
    "resolveLinks"
    "rpcgen"
    "sdef"
    "sdp"
    "segedit"
    "size"
    "sourcekit-lsp"
    "stapler"
    "strings"
    "strip"
    "swift"
    "swiftc"
    "unifdef"
    "unifdefall"
    "vtool"
    "xcdebug"
    "xcode-select"
    "xcodebuild"
    "xcrun"
    "xcscontrol"
    "xcsdiagnose"
    "xctrace"
    "xed"
    "xml2man"
    "yacc"
  ];

  blocker = pkgs.writeShellScript "apple-developer-tool-blocker" ''
    echo "''${0##*/}: Apple developer tools are blocked by nix-darwin." >&2
    echo "To use this tool, add it to environment.systemPackages or run it in a nix shell/nix develop environment." >&2
    exit 127
  '';

  blockers = pkgs.linkFarm "apple-developer-tools-blockers" (
    lib.genAttrs (map (name: "bin/${name}") commands) (_: blocker)
  );
in
{
  meta.maintainers = [
    lib.maintainers.gordon01 or "gordon01"
  ];

  options.environment.appleDeveloperTools.block = lib.mkOption {
    type = lib.types.bool;
    default = false;
    example = true;
    description = ''
      Whether to shadow Apple developer-tool commands on {env}`PATH` with
      stubs that direct users to Nix, avoiding the Command Line Tools
      installation prompt. The stubs are placed after Nix profiles and before
      macOS paths, so Nix tools retain precedence. This does not uninstall Xcode
      or affect absolute paths such as {file}`/usr/bin/gcc`.
    '';
  };

  config = lib.mkIf config.environment.appleDeveloperTools.block {
    # After Nix profiles (default order 1000), before macOS paths (order 1200).
    environment.systemPath = lib.mkOrder 1100 [ blockers ];
  };
}
