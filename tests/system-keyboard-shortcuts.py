"""Exercise generated activation without calling any desktop or user commands."""

import json
import os
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile


MOCK = r'''
import json
import os
from pathlib import Path
import plistlib
import sys

command = Path(sys.argv[0]).name
args = sys.argv[1:]
root = Path(os.environ["SHORTCUT_TEST_ROOT"])
if command == "id":
    assert args == ["-u", "--", "test-shortcuts-user"], args
    print("501")
elif command == "launchctl":
    assert args[:2] == ["asuser", "501"], args
    with (root / "calls.jsonl").open("a") as stream:
        stream.write(json.dumps([command, args]) + "\n")
    os.execvp(args[2], args[2:])
elif command == "sudo":
    assert args[:2] == ["--user=test-shortcuts-user", "--"], args
    with (root / "calls.jsonl").open("a") as stream:
        stream.write(json.dumps([command, args]) + "\n")
    os.execvp(args[2], args[2:])
elif command == "defaults":
    assert args[:4] == [
        "write", "com.apple.symbolichotkeys", "AppleSymbolicHotKeys", "-dict-add"
    ], args
    assert len(args) == 6, args
    path = root / "preferences.plist"
    with path.open("rb") as stream:
        preferences = plistlib.load(stream)
    preferences["AppleSymbolicHotKeys"][args[4]] = plistlib.loads(args[5].encode())
    with path.open("wb") as stream:
        plistlib.dump(preferences, stream)
    with (root / "calls.jsonl").open("a") as stream:
        stream.write(json.dumps([command, args[4]]) + "\n")
else:
    raise AssertionError(command)
'''


with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    mock_bin = root / "bin"
    mock_bin.mkdir()
    for command in ["id", "launchctl", "sudo", "defaults"]:
        script = mock_bin / command
        script.write_text(f"#!{sys.executable}\n{MOCK}")
        script.chmod(0o755)

    original = {
        "UnrelatedPreference": "preserve this",
        "AppleSymbolicHotKeys": {
            "64": {"enabled": False},
            "15": {"enabled": True, "custom": "preserve this too"},
            "118": {"enabled": False},
        },
    }
    path = root / "preferences.plist"
    with path.open("wb") as stream:
        plistlib.dump(original, stream)

    env = os.environ | {
        "PATH": f"{mock_bin}:{os.environ['PATH']}",
        "SHORTCUT_TEST_ROOT": str(root),
    }
    subprocess.run(["bash", sys.argv[1]], check=True, env=env)
    with path.open("rb") as stream:
        actual = plistlib.load(stream)

    expected = {
        "118": [65535, 18, 0x80000],
        "121": [65535, 21, 0x80000],
        "126": [65535, 25, 0xC0000],
        "127": [65535, 109, 0x100000],
        "133": [65535, 124, 0x9E0000],
    }
    for identifier, parameters in expected.items():
        assert actual["AppleSymbolicHotKeys"][identifier] == {
            "enabled": True,
            "value": {"type": "standard", "parameters": parameters},
        }, actual["AppleSymbolicHotKeys"][identifier]
    assert actual["AppleSymbolicHotKeys"]["119"] == {"enabled": False}
    for identifier in ["64", "15"]:
        assert actual["AppleSymbolicHotKeys"][identifier] == original["AppleSymbolicHotKeys"][identifier]
    assert actual["UnrelatedPreference"] == original["UnrelatedPreference"]
    assert set(actual["AppleSymbolicHotKeys"]) == set(expected) | {"119", "64", "15"}

    calls = [json.loads(line) for line in (root / "calls.jsonl").read_text().splitlines()]
    assert [call[0] for call in calls] == ["launchctl", "sudo", "defaults"] * 6
    assert {call[1] for call in calls if call[0] == "defaults"} == set(expected) | {"119"}
    print("Checked typed shortcuts, primary-user dispatch, and preservation of other preferences.")
