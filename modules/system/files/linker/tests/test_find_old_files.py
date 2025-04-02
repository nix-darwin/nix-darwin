from linker import find_old_files, FileInfo, FileType, Transaction, TransactionType
from .mock_path import MockPath

def test_empty_to_empty():
    transactions = find_old_files({}, {})
    assert transactions == []

def test_empty_to_single_file_nothing_on_disk():
    on_disk = MockPath("/tmp/file.txt")
    in_store = MockPath("/nix/store/file.txt")
    on_disk.exists_action = lambda follow_symlinks: False

    new_files = {
        on_disk: FileInfo(
            in_store,
            FileType.LINK
        )
    }
    old_files = {}
    
    transactions = find_old_files(new_files, old_files)

    assert transactions == []

def test_empty_to_single_file_broken_symlink_on_disk():
    on_disk = MockPath("/tmp/file.txt")
    in_store = MockPath("/nix/store/file.txt")
    on_disk.exists_action = lambda follow_symlinks: not follow_symlinks
    on_disk.is_symlink_action = lambda: True
    on_disk.readlink_action = lambda: MockPath("/tmp/nonexistent.txt")

    new_files = {
        on_disk: FileInfo(
            in_store,
            FileType.LINK
        )
    }
    old_files = {}
    
    transactions = find_old_files(new_files, old_files)

    assert transactions == []

def test_empty_to_single_file_working_symlink_to_correct_file_on_disk():
    on_disk = MockPath("/tmp/file.txt")
    in_store = MockPath("/nix/store/file.txt")
    on_disk.exists_action = lambda follow_symlinks: True
    on_disk.is_symlink_action = lambda: True
    on_disk.readlink_action = lambda: in_store

    new_files = {
        on_disk: FileInfo(
            in_store,
            FileType.LINK
        )
    }
    old_files = {}
    
    transactions = find_old_files(new_files, old_files)

    assert transactions == []

def test_empty_to_single_file_working_symlink_to_incorrect_file_on_disk():
    on_disk = MockPath("/tmp/file.txt")
    in_store = MockPath("/nix/store/file.txt")
    on_disk.exists_action = lambda follow_symlinks: True
    on_disk.is_symlink_action = lambda: True
    on_disk.readlink_action = lambda: MockPath("/tmp/other.txt")

    new_files = {
        on_disk: FileInfo(
            in_store,
            FileType.LINK
        )
    }
    old_files = {}
    
    transactions = find_old_files(new_files, old_files)

    assert transactions == []

def test_empty_to_single_file_file_on_disk():
    on_disk = MockPath("/tmp/file.txt")
    in_store = MockPath("/nix/store/file.txt")
    on_disk.exists_action = lambda follow_symlinks: True
    on_disk.is_symlink_action = lambda: False

    new_files = {
        on_disk: FileInfo(
            in_store,
            FileType.LINK
        )
    }
    old_files = {}
    
    transactions = find_old_files(new_files, old_files)

    assert transactions == []

def test_single_file_to_empty_broken_symlink_on_disk():
    on_disk = MockPath("/tmp/file.txt")
    in_store = MockPath("/nix/store/file.txt")
    on_disk.exists_action = lambda follow_sylinks: not follow_sylinks
    on_disk.is_symlink_action = lambda: True
    on_disk.readlink_action = lambda: MockPath("/tmp/nonexistent.txt")
    parent = MockPath(".") # in_store is absolute, so these three lines don't have any effect
    parent.concat_action = lambda this, other: other
    on_disk._parent = parent

    new_files = {}
    old_files = {
        on_disk: FileInfo(
            in_store,
            FileType.LINK
        )
    }

    transactions = find_old_files(new_files, old_files)

    assert transactions == []

def test_single_file_to_empty_working_symlink_to_correct_file_on_disk():
    on_disk = MockPath("/tmp/file.txt")
    in_store = MockPath("/nix/store/file.txt")
    on_disk.exists_action = lambda follow_sylinks: True
    on_disk.is_symlink_action = lambda: True
    on_disk.readlink_action = lambda: in_store
    parent = MockPath(".") # in_store is absolute, so these three lines don't have any effect
    parent.concat_action = lambda this, other: other
    on_disk._parent = parent

    new_files = {}
    old_files = {
        on_disk: FileInfo(
            in_store,
            FileType.LINK
        )
    }

    transactions = find_old_files(new_files, old_files)

    t = Transaction.remove(on_disk)
    assert transactions == [t]

def test_single_file_to_empty_working_symlink_to_incorrect_file_on_disk():
    on_disk = MockPath("/tmp/file.txt")
    in_store = MockPath("/nix/store/file.txt")
    on_disk.exists_action = lambda follow_sylinks: True
    on_disk.is_symlink_action = lambda: True
    on_disk.readlink_action = lambda: MockPath("/tmp/other.txt")
    parent = MockPath(".") # in_store is absolute, so these three lines don't have any effect
    parent.concat_action = lambda this, other: other
    on_disk._parent = parent

    new_files = {}
    old_files = {
        on_disk: FileInfo(
            in_store,
            FileType.LINK
        )
    }

    transactions = find_old_files(new_files, old_files)

    assert transactions == []

def test_single_file_to_empty_file_on_disk():
    on_disk = MockPath("/tmp/file.txt")
    in_store = MockPath("/nix/store/file.txt")
    on_disk.exists_action = lambda follow_sylinks: True
    on_disk.is_symlink_action = lambda: False

    new_files = {}
    old_files = {
        on_disk: FileInfo(
            in_store,
            FileType.LINK
        )
    }

    transactions = find_old_files(new_files, old_files)

    assert transactions == []

def test_update_single_file_broken_symlink_on_disk():
    on_disk = MockPath("/tmp/file.txt")
    old_in_store = MockPath("/nix/store/old.txt")
    new_in_store = MockPath("/nix/store/new.txt")
    on_disk.exists_action = lambda follow_sylinks: not follow_sylinks
    on_disk.is_symlink_action = lambda: True
    on_disk.readlink_action = lambda: MockPath("/tmp/nonexistent.txt")
    
    new_files = {
        on_disk: FileInfo(
            new_in_store,
            FileType.LINK
        )
    }
    old_files = {
        on_disk: FileInfo(
            old_in_store,
            FileType.LINK
        )
    }

    transactions = find_old_files(new_files, old_files)

    assert transactions == []

def test_update_single_file_working_symlink_to_correct_file_on_disk():
    on_disk = MockPath("/tmp/file.txt")
    old_in_store = MockPath("/nix/store/old.txt")
    new_in_store = MockPath("/nix/store/new.txt")
    on_disk.exists_action = lambda follow_sylinks: True
    on_disk.is_symlink_action = lambda: True
    on_disk.readlink_action = lambda: old_in_store
    
    new_files = {
        on_disk: FileInfo(
            new_in_store,
            FileType.LINK
        )
    }
    old_files = {
        on_disk: FileInfo(
            old_in_store,
            FileType.LINK
        )
    }

    transactions = find_old_files(new_files, old_files)

    assert transactions == []

def test_update_single_file_working_symlink_to_incorrect_file_on_disk():
    on_disk = MockPath("/tmp/file.txt")
    old_in_store = MockPath("/nix/store/old.txt")
    new_in_store = MockPath("/nix/store/new.txt")
    on_disk.exists_action = lambda follow_sylinks: True
    on_disk.is_symlink_action = lambda: True
    on_disk.readlink_action = lambda: MockPath("/tmp/other.txt")

    new_files = {
        on_disk: FileInfo(
            new_in_store,
            FileType.LINK
        )
    }
    old_files = {
        on_disk: FileInfo(
            old_in_store,
            FileType.LINK
        )
    }

    transactions = find_old_files(new_files, old_files)

    assert transactions == []

def test_update_single_file_file_on_disk():
    on_disk = MockPath("/tmp/file.txt")
    old_in_store = MockPath("/nix/store/old.txt")
    new_in_store = MockPath("/nix/store/new.txt")
    on_disk.exists_action = lambda follow_sylinks: True
    on_disk.is_symlink_action = lambda: False

    new_files = {
        on_disk: FileInfo(
            new_in_store,
            FileType.LINK
        )
    }
    old_files = {
        on_disk: FileInfo(
            old_in_store,
            FileType.LINK
        )
    }

    transactions = find_old_files(new_files, old_files)

    assert transactions == []
