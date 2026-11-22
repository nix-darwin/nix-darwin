"""Run the command and environment from a generated launchd plist."""

import os
import plistlib
import sys

with open(sys.argv[1], "rb") as source:
    job = plistlib.load(source)

arguments = job.get("ProgramArguments") or [job["Program"]]
environment = os.environ | job.get("EnvironmentVariables", {})
os.execvpe(job.get("Program", arguments[0]), arguments, environment)
