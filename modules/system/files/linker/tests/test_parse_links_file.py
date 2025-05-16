from linker import parse_links_file, FileInfo, FileType
from pathlib import Path
from uuid import uuid4
import json

def test_nonexistent_file():
    file = Path(f"/tmp/{uuid4()}")
    file.unlink(missing_ok=True)

    try:
        theDict = parse_links_file(filePath=file)
    except:
        assert True
    else:
        assert False

def test_nonjson_file():
    file = Path(f"/tmp/{uuid4()}")
    file.unlink(missing_ok=True)
    file.touch()

    try:
        theDict = parse_links_file(filePath=file)
    except:
        assert True
    else:
        assert False

def test_json_missing_version():
    file = Path(f"/tmp/{uuid4()}")
    file.unlink(missing_ok=True)
    with open(file, "w") as f:
        json.dump({}, f)

    try:
        theDict = parse_links_file(filePath=file)
    except:
        assert True
    else:
        assert False

def test_json_missing_files():
    file = Path(f"/tmp/{uuid4()}")
    file.unlink(missing_ok=True)
    with open(file, "w") as f:
        json.dump({"version": 1}, f)

    try:
        theDict = parse_links_file(filePath=file)
    except:
        assert True
    else:
        assert False

def test_json_no_files():
    file = Path(f"/tmp/{uuid4()}")
    file.unlink(missing_ok=True)
    with open(file, "w") as f:
        json.dump({"version": 1, "files": {}}, f)

    try:
        theDict = parse_links_file(filePath=file)
        assert theDict == {}
    except:
        assert False

def test_json_one_file():
    file = Path(f"/tmp/{uuid4()}")
    file.unlink(missing_ok=True)
    with open(file, "w") as f:
        json.dump({"version": 1, "files": {"/tmp/file.txt": {"source": "/nix/store/file.txt", "type": "link"}}}, f)

    try:
        theDict = parse_links_file(filePath=file)
        assert len(theDict) == 1
        el = theDict[Path("/tmp/file.txt")]
        assert el != None
        assert el.source == Path("/nix/store/file.txt")
        assert el.type == FileType.LINK
    except:
        assert False

def test_json_two_files():
    file = Path(f"/tmp/{uuid4()}")
    file.unlink(missing_ok=True)
    with open(file, "w") as f:
        json.dump({"version": 1, "files": {"/tmp/file.txt": {"source": "/nix/store/file.txt", "type": "link"}, "/tmp/other.txt": {"source": "/nix/store/other.txt", "type": "link"}}}, f)

    try:
        theDict = parse_links_file(filePath=file)
        assert len(theDict) == 2
        el = theDict[Path("/tmp/file.txt")]
        assert el != None
        assert el.source == Path("/nix/store/file.txt")
        assert el.type == FileType.LINK
        el = theDict[Path("/tmp/other.txt")]
        assert el != None
        assert el.source == Path("/nix/store/other.txt")
        assert el.type == FileType.LINK
    except:
        assert False
