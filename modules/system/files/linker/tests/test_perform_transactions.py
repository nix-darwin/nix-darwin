from linker import perform_transactions, Transaction, TransactionType
from .mock_path import MockPath
from pathlib import Path

def test_no_transactions():
    assert perform_transactions([], False) == []
    assert perform_transactions([], True) == []

def test_link_transaction():
    source = MockPath("/nix/store/file.txt")
    destination = MockPath("/tmp/file.txt")
    parent = MockPath("/tmp/parent")
    did_symlink = False
    def action(target: Path):
        nonlocal did_symlink
        did_symlink = True
    destination.symlink_to_action = action
    destination._parent = parent
    destination.unlink_action = lambda missing_ok: None
    parent.mkdir_action = lambda parents, exist_ok: None
    t = Transaction(source, destination, TransactionType.LINK)
    assert perform_transactions([t], False) == []
    assert did_symlink

def test_link_transaction_dry_run():
    source = MockPath("/nix/store/file.txt")
    destination = MockPath("/tmp/file.txt")
    did_symlink = False
    def action(target: Path):
        nonlocal did_symlink
        did_symlink = True
    destination.symlink_to_action = action
    t = Transaction(source, destination, TransactionType.LINK)
    assert perform_transactions([t], True) == []
    assert not did_symlink

def test_remove_transaction():
    source = MockPath("/tmp/file.txt")
    did_remove = False
    def action(missing_ok: bool):
        nonlocal did_remove
        did_remove = True
    source.unlink_action = action
    source._parent = MockPath("/tmp/parent")
    t = Transaction.remove(source)
    assert perform_transactions([t], False) == [MockPath("/tmp/parent")]
    assert did_remove

def test_remove_transaction_dry_run():
    source = MockPath("/tmp/file.txt")
    did_remove = False
    def action(missing_ok: bool):
        nonlocal did_remove
        did_remove = True
    source.unlink_action = action
    t = Transaction.remove(source)
    assert perform_transactions([t], True) == []
    assert not did_remove
