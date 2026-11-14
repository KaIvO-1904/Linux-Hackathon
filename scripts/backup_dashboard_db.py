#!/usr/bin/env python3
"""Create a consistent SQLite online backup for backup_project.sh."""

import argparse
import os
import sqlite3
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--source", required=True)
parser.add_argument("--destination", required=True)
args = parser.parse_args()
source_path = Path(args.source).resolve()
destination = Path(args.destination)
destination.parent.mkdir(parents=True, exist_ok=True)
source = sqlite3.connect(f"file:{source_path.as_posix()}?mode=ro", uri=True, timeout=10)
target = sqlite3.connect(destination, timeout=10)
try:
    source.backup(target)
finally:
    target.close()
    source.close()
os.chmod(destination, 0o600)
print(f"Created consistent SQLite snapshot at {destination}")
