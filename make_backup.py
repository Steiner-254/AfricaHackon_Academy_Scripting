#!/usr/bin/env python3
"""
make_backup.py

Creates a backup directory and copies all files from the directory
where this script is located into that backup directory.

Usage:
    python3 make_backup.py            # non-recursive (files only)
    python3 make_backup.py -r         # recursive (files + directories)
    python3 make_backup.py -n mybk    # set custom base name for backup folder
"""

import argparse
import shutil
import sys
from pathlib import Path
from datetime import datetime

def create_unique_backup_dir(base_dir: Path, base_name: str) -> Path:
    """Create a timestamped backup directory (avoids overwriting)."""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    candidate = base_dir / f"{base_name}_{timestamp}"
    candidate.mkdir(parents=True, exist_ok=False)
    return candidate

def copy_files_only(src_dir: Path, dst_dir: Path, exclude_names: set) -> int:
    """Copy files (non-recursive) from src_dir to dst_dir. Returns count."""
    count = 0
    for item in src_dir.iterdir():
        # skip the backup dir itself and excluded names (like the script)
        if item.name in exclude_names:
            continue
        if item.is_file():
            shutil.copy2(item, dst_dir / item.name)
            count += 1
    return count

def copy_recursive(src_dir: Path, dst_dir: Path, exclude_names: set) -> tuple:
    """
    Copy files and directories recursively.
    Creates dst_dir/<item.name> for each directory or copies files into dst_dir.
    Returns (files_copied, dirs_copied).
    """
    files_copied = 0
    dirs_copied = 0
    for item in src_dir.iterdir():
        if item.name in exclude_names:
            continue
        dest = dst_dir / item.name
        if item.is_file():
            shutil.copy2(item, dest)
            files_copied += 1
        elif item.is_dir():
            # copy directory tree into the backup directory
            try:
                # Python 3.8+ supports dirs_exist_ok
                shutil.copytree(item, dest, dirs_exist_ok=True)
            except TypeError:
                # fallback for older python versions: if dest exists, remove then copy
                if dest.exists():
                    shutil.rmtree(dest)
                shutil.copytree(item, dest)
            dirs_copied += 1
    return files_copied, dirs_copied

def main():
    parser = argparse.ArgumentParser(description="Create a backup of files in the script directory.")
    parser.add_argument("-r", "--recursive", action="store_true",
                        help="Copy directories recursively (files + directories).")
    parser.add_argument("-n", "--name", default="backup",
                        help="Base name for the backup directory (default: 'backup').")
    args = parser.parse_args()

    # Determine the directory where this script is located. Fallback to cwd.
    try:
        script_path = Path(__file__).resolve()
        base_dir = script_path.parent
    except NameError:
        # __file__ may not be defined (e.g., interactive run); fall back to cwd
        base_dir = Path.cwd()
        script_path = base_dir / Path(sys.argv[0]).name

    # The script file name (so we don't copy ourselves)
    script_name = script_path.name

    # Create unique backup directory
    try:
        backup_dir = create_unique_backup_dir(base_dir, args.name)
    except FileExistsError:
        # Extremely unlikely due to timestamp, but fallback to a safe increment
        i = 1
        while True:
            try:
                backup_dir = base_dir / f"{args.name}_{i}"
                backup_dir.mkdir(parents=True, exist_ok=False)
                break
            except FileExistsError:
                i += 1

    print(f"Source directory : {base_dir}")
    print(f"Backup directory  : {backup_dir}")
    print(f"Recursive copy    : {'Yes' if args.recursive else 'No'}")
    print("Starting copy...")

    exclude = {backup_dir.name, script_name}

    if args.recursive:
        files_count, dirs_count = copy_recursive(base_dir, backup_dir, exclude)
        print(f"Copied {files_count} files and {dirs_count} directories into '{backup_dir.name}'.")
    else:
        files_count = copy_files_only(base_dir, backup_dir, exclude)
        print(f"Copied {files_count} files into '{backup_dir.name}' (non-recursive).")

    print("Done.")

if __name__ == "__main__":
    main()
