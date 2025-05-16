from pathlib import Path
from typing import Generator, Callable

class MockPath(Path):
    def __init__(self, name: str):
        super().__init__(name)
        self.exists_action: Callable[[bool], bool] | None = None
        self.is_symlink_action: Callable[[], bool] | None = None
        self.readlink_action: Callable[[], Path] | None = None
        self.mkdir_action: Callable[[bool, bool], None] | None = None
        self.unlink_action: Callable[[bool], None] | None = None
        self.symlink_to_action: Callable[[str | Path], None] | None = None
        self.contents: list[Path] | None = None
        self._parent: Path | None = None
        self.concat_action: Callable[[Path, Path], Path] | None = None

    def exists(self, follow_symlinks: bool = True) -> bool:
        return self.exists_action(follow_symlinks)

    def is_symlink(self) -> bool:
        return self.is_symlink_action()

    def readlink(self) -> Path:
        return self.readlink_action()

    @property
    def parent(self):
        if self._parent is not None:
            return self._parent
        else:
            raise Exception

    def __truediv__(self, other) -> Path:
        return self.concat_action(self, other)

# perform_transactions

    def mkdir(self, parents: bool = False, exist_ok: bool = False):
        return self.mkdir_action(parents, exist_ok)

    def unlink(self, missing_ok: bool = False):
        return self.unlink_action(missing_ok)

    def symlink_to(self, target: str | Path):
        return self.symlink_to_action(target)

# only_empty

    def iterdir(self) -> Generator[Path, None, None]:
        for element in self.contents:
            yield element
        return
