from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path
import json
import os
import sys

class FileType(StrEnum):
    LINK = "link"
class TransactionType(StrEnum):
    LINK = "link"
    REMOVE = "remove"

    @classmethod
    def from_file_type(cls, f: FileType):
        return cls(f.value)

@dataclass
class FileInfo:
    """The configuration for a managed path on-disk.

    They have a source path in the Nix store.

    They can be of the following types:
    - LINK: a symlink from the on-disk path pointing to the Nix store
    """
    source: Path
    type: FileType

    @classmethod
    def from_dict(cls, d):
        return cls(Path(d['source']), FileType(d['type']))

@dataclass
class Transaction:
    """An action that must be taken to synchronize one file's on-disk state.

    Transactions always have an on-disk path. Unless they are of type REMOVE, they also have a path in the Nix store.

    They can be of the following types:
    - LINK: create a symlink from the on-disk path pointing to the Nix store
    - REMOVE: remove any file/link at the on-disk path
    """
    in_store: Path | None
    on_disk: Path
    type: TransactionType

    def __eq__(self, other):
        if not isinstance(other, Transaction):
            return False
        if self.on_disk != other.on_disk:
            return False
        if self.type != other.type:
            return False
        # store path doesn't matter for remove transactions
        if self.in_store != other.in_store:
            return self.type == TransactionType.REMOVE
        return True

    @classmethod
    def remove(cls, path):
        return cls(None, path, TransactionType.REMOVE)

def main():
    check_args()
    old_files, new_files = parse_links_files()
    transactions, problems = check_files(new_files, old_files)
    if len(problems) > 0:
        print("Detected problems at paths:")
        for problem in problems:
            print(f"- {problem}")
        print("Aborting")
        sys.exit(1)
    if "CHECK_ONLY" in os.environ.keys():
        sys.exit(0)
    removals = find_old_files(new_files, old_files)
    enclosing_directories = perform_transactions(transactions + removals, "DRY_RUN" in os.environ.keys())
    emptied_directories = only_empty(enclosing_directories)
    if len(emptied_directories) > 0:
        print("The following directories have been emptied; you may want to remove them")
        for directory in emptied_directories:
            print(f"- {directory}")

def check_args():
    """Check that the linker was given exactly two arguments"""
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <old_system_links.json> <new_system_links.json>")
        sys.exit(1)

def parse_links_files() -> tuple[dict[Path, FileInfo], dict[Path, FileInfo]]:
    """Parse the first and second arguments as links files"""
    old = parse_links_file(sys.argv[1])
    new = parse_links_file(sys.argv[2])
    return old, new

def parse_links_file(filePath: str) -> dict[Path, FileInfo]:
    """Read the given file, parse as JSON, and convert to a links dictionary"""
    with open(filePath, "r") as file:
        data = json.load(file)
        if data['version'] != 1:
            print(f"Unknown schema version in {filePath}")
            sys.exit(1)
        theDict: dict[Path, FileInfo] = {
            Path(k): FileInfo.from_dict(v)
            for
            (k,v)
            in
            data['files'].items()
        }
    return theDict

def check_files(new_files: dict[Path, FileInfo], old_files: dict[Path, FileInfo], adopt_identical_links: bool = False) -> tuple[list[Transaction], list[Path]]:
    """Check the current state of the filesystem against the new links, generating a list of transactions to perform and problems that will occur.

    This function will generate a list of transactions and problems incurred in the process of ensuring that every file in new_files is correct.
    It will not generate transactions to remove the remaining files in old_files.
    """
    transactions: list[Transaction] = []
    problems: list[Path] = []
    path: Path

    # Go through all files in the new generation
    for path in new_files:
        new_file: FileInfo = new_files[path]
        if not path.exists(follow_symlinks=False):
            # There is no file at this path
            transactions.append(Transaction(new_file.source, path, TransactionType.from_file_type(new_file.type)))
        else:
            # There is a file at this path
            # It could be a regular file or a symlink (including broken symlinks)

            if not path.is_symlink():
                # The file is a regular file
                problems.append(path)
            else:
                # The file is a symlink

                if path not in old_files:
                    # The old generation did not have a file at this path.

                    link_target = path.readlink()
                    # This handles both relative and absolute symlinks
                    #   If the link is relative, we need to prepend the parent
                    #   If the link is absolute, the prepended parent is ignored
                    if path.parent / link_target == new_file.source:
                        # The link already points to the new target
                        if adopt_identical_links:
                            # We are allowed to "adopt" these links and pretend as if we created them
                            continue
                        else:
                            # We must treat this as a problem, so that undoing this generation will not remove this file created before this generation
                            problems.append(path)
                    else:
                        # The link points somewhere else
                        problems.append(path)
                else:
                    # The old generation had a file at this path
                    if old_files[path].type != FileType.LINK:
                        # The old generation's file was not a link.
                        # Because we know that the file on disk is a link,
                        # we know that we can't overwrite this file
                        problems.append(path)
                    else:
                        # The old generation's file was a link
                        link_target = path.readlink()
                        if path.parent / link_target == old_files[path].source:
                            # The link has not changed since last system activation, so we can overwrite it
                            transactions.append(Transaction(new_file.source, path, TransactionType.from_file_type(new_file.type)))
                        elif path.parent / link_target == new_file.source:
                            # The link already points to the new target
                            if adopt_identical_links:
                                # We are allowed to "adopt" these links and pretend as if we created them
                                continue
                            else:
                                # We must treat this as a problem, so that undoing this generation will not remove this file created before this generation
                                problems.append(path)
                        else:
                            # The link is to somewhere else
                            problems.append(path)

    return transactions, problems

def find_old_files(new_files: dict[Path, FileInfo], old_files: dict[Path, FileInfo]) -> list[Transaction]:
    """Check the current state of the filesystem against the old links, generating a list of transactions to perform in order to remove them.

    This function will generate a list of transactions incurred in the process of removing every file in old_files that does not exist in new_files and has not been modified.
    It will not generate transactions to ensure that new_files is correct. Additionally, it will not generate problems for files on disk that have changed since old_files.
    """
    transactions: list[Transaction] = []

    # Remove all remaining files from the old generation that aren't in the new generation
    path: Path
    for path in old_files:
        old_file: FileInfo = old_files[path]
        if path in new_files:
            # Already handled when we iterated through new_files above
            continue
        if not path.exists(follow_symlinks=False):
            # There's no file at this path anymore, so we have nothing to do anyway
            continue
        else:
            # There is a file at this path
            # It could be a regular file or a symlink (including broken symlinks)

            if not path.is_symlink():
                # The file is a regular file
                continue
            else:
                # The file is a symlink

                if old_file.type != FileType.LINK:
                    # This files wasn't a link at last activation, which means that the user changed it
                    # Therefore we don't touch it
                    continue

                # Check that its destination remains the same
                link_target = path.readlink()
                if path.parent / link_target == old_file.source:
                    # The link has not changed since last system activation, so we can overwrite it
                    transactions.append(Transaction.remove(path))
                else:
                    # The link is to somewhere else, so leave it alone
                    continue

    return transactions

def perform_transactions(transactions: list[Transaction], DRY_RUN: bool) -> list[Path]:
    """Perform the given list of transactions (subject to the DRY_RUN variable), returning a list of directories that have had entries removed"""
    enclosingDirectories: list[Path] = []

    # Perform all transactions
    for t in transactions:
        if DRY_RUN:
            match t.type:
                case TransactionType.LINK:
                    print(f"ln -s {t.in_store} {t.on_disk}")
                case TransactionType.REMOVE:
                    print(f"rm {t.on_disk}")
                case _:
                    print(f"Unknown transaction type {t.type}")
        else:
            match t.type:
                case TransactionType.LINK:
                    # Ensure parent directory exists
                    t.on_disk.parent.mkdir(parents=True,exist_ok=True)
                    # Remove the file if it exists (we should only get to this case if it's an old symlink we're replacing)
                    # This does not properly handle race conditions, but I think we'd fail in the checking stage
                    #   if your config has a race condition
                    t.on_disk.unlink(missing_ok=True)
                    # Link the file into place
                    t.on_disk.symlink_to(t.in_store)
                case TransactionType.REMOVE:
                    enclosingDirectories.append(t.on_disk.parent)
                    t.on_disk.unlink()
                case _:
                    print(f"Unknown transaction type {t.type}")

    return enclosingDirectories

def only_empty(enclosing_directories: list[Path]) -> list[Path]:
    """Keep only the directories that are empty out of the given list"""
    return list(filter(lambda directory: not any(directory.iterdir()), enclosing_directories))
