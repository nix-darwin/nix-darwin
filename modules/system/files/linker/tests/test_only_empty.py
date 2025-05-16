from linker import only_empty
from .mock_path import MockPath

def test_no_enclosing_directories():
    assert only_empty([]) == []

def test_one_empty_dir():
    empty_dir = MockPath("empty_dir")
    empty_dir.contents = []
    assert only_empty([empty_dir]) == [empty_dir]

def test_one_full_dir():
    full_dir = MockPath("full_dir")
    full_dir.contents = [MockPath("file_in_dir"), MockPath("another_file_in_dir")]
    assert only_empty([full_dir]) == []

def test_mix():
    empty_dir = MockPath("empty_dir")
    empty_dir.contents = []
    full_dir = MockPath("full_dir")
    full_dir.contents = [MockPath("file_in_dir")]
    assert only_empty([empty_dir, full_dir]) == [empty_dir]
