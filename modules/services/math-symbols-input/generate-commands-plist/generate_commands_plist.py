from functools import reduce
from pathlib import Path
from collections.abc import Iterable
from typing import TypedDict

from operator import ior
from cytoolz import compose_left
from cytoolz.curried import filter, map

###############################################################################
#                                    Types                                    #
###############################################################################

Commands = dict[str, str]


# This is the structure in the Math Symbols Input plist file
class MathSymbolsPlist(TypedDict):
    CustomCommands: Commands
    DefaultCommands: Commands
    PreferencesTab: str


###############################################################################
#                                Pure Commands                                #
###############################################################################


def valid_line(line: str) -> bool:
    """Is this line a command line (true) or a comment (false)"""
    return not line.startswith("#") and not line.isspace()


def clean_line(line: str) -> str:
    """Remove whitespace so commands don't have random whitespace in them"""
    return line.strip()


def command_line_to_commands(line: str) -> Commands:
    """Convert a single command string line to a Commands"""
    command, symbol = line.split(" ")
    return {command: symbol}


def combine_commands(commands: Iterable[Commands]) -> Commands:
    """Combine a bunch of Commands dicts into one

    Equivalent to combining a bunch of [d1, d2, ..., dn] as

    d = {}
    d |= d1
    d |= d2
    ...
    d |= dn
    """
    return reduce(ior, commands, dict())


# Operates on a generator, so only reads one line at a time
def lines_to_commands(lines: Iterable[str]) -> Commands:
    """Convert an iterable of command strings onto one Commands dict"""
    return compose_left(
        filter(valid_line),
        map(compose_left(clean_line, command_line_to_commands)),
        combine_commands,
    )(lines)


def commands_to_plist(custom: Commands, default: Commands) -> MathSymbolsPlist:
    return MathSymbolsPlist(
        CustomCommands=custom, DefaultCommands=default, PreferencesTab="custom-commands"
    )


###############################################################################
#                          Stateful/Impure functions                          #
###############################################################################


def path_to_commands(p: Path) -> Commands:
    with open(p, "r") as f:
        return lines_to_commands(f)


def command_paths_to_plist(custom_path: Path, default_path: Path) -> MathSymbolsPlist:
    custom = path_to_commands(custom_path)
    default = path_to_commands(default_path)

    return commands_to_plist(custom, default)


###############################################################################
#                                     Main                                    #
###############################################################################

if __name__ == "__main__":
    import sys
    import plistlib

    locations = sys.argv[1:4]
    default_path, custom_path, output_path = map(Path, locations)

    commands = command_paths_to_plist(custom_path, default_path)

    with open(output_path, "wb") as f:
        plistlib.dump(commands, f, fmt=plistlib.FMT_BINARY)
