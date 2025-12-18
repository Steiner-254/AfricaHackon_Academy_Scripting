#!/usr/bin/env python3
"""
make_backup.py

Creates a timestamped backup directory and copies files from the directory
where this script lives into that backup directory. Optionally deletes
the original files after successful verification.

Usage examples:
    # Non-recursive copy, no deletion
    python3 make_backup.py

    # Recursive copy and then delete originals (asks for confirmation)
    python3 make_backup.py --recursive --delete

    # Recursive + delete originals + remove empty source directories + skip confirmation
    python3 make_backup.py -r -d --remove-empty-dirs --force

    # Use SHA-256 verification before deleting (slower, but stronger)
    python3 make_backup.py -r -d --hash
"""

import argparse
import shutil
import sys
import os
from pathlib import Path
from datetime import datetime
import hashlib

def create_unique_backup_dir(base_dir: Path, base_name: str) -> Path:
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    candidate = base_dir / f"{base_name}_{timestamp}"
    candidate.mkdir(parents=True, exist_ok=False)
    return candidate

def sha256_of_file(path: Path, chunk_size: int = 8192) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(chunk_size), b""):
            h.update(chunk)
    return h.hexdigest()

def copy_files_non_recursive(src_dir: Path, dst_dir: Path, exclude_names: set):
    copied_pairs = []  # list of (src_path, dst_path)
    for item in src_dir.iterdir():
        if item.name in exclude_names:
            continue
        if item.is_file():
            dst = dst_dir / item.name
            shutil.copy2(item, dst)
            copied_pairs.append((item, dst))
    return copied_pairs

def copy_files_recursive(src_dir: Path, dst_dir: Path, exclude_names: set):
    copied_pairs = []
    # Walk directory tree and copy files individually so we can track them
    for root, dirs, files in os.walk(src_dir):
        root_path = Path(root)
        # Skip the backup directory if it appears in the tree
        if any(part in exclude_names for part in root_path.relative_to(src_dir).parts if part):
            # If the path's components include an excluded name, skip this subtree
            continue
        # replicate directory structure in dst
        rel_root = root_path.relative_to(src_dir)
        target_root = dst_dir.joinpath(rel_root)
        target_root.mkdir(parents=True, exist_ok=True)
        for fname in files:
            if fname in exclude_names:
                continue
            src_file = root_path / fname
            dst_file = target_root / fname
            # copy file
            shutil.copy2(src_file, dst_file)
            copied_pairs.append((src_file, dst_file))
    return copied_pairs

def verify_pair(src: Path, dst: Path, use_hash: bool) -> bool:
    # Basic check: file exists at dst and sizes match
    try:
        if not dst.exists() or not src.exists():
            return False
        if src.stat().st_size != dst.stat().st_size:
            return False
        if use_hash:
            return sha256_of_file(src) == sha256_of_file(dst)
        return True
    except Exception:
        return False

def delete_backed_files(copied_pairs, exclude_names: set, use_hash: bool, remove_empty_dirs: bool):
    deleted = []
    failed = []
    for src, dst in copied_pairs:
        # Safety: don't allow deleting if src is the backup dir or script
        if any(part == n for part in src.parts for n in exclude_names):
            failed.append((src, "excluded"))
            continue
        ok = verify_pair(src, dst, use_hash)
        if not ok:
            failed.append((src, "verification_failed"))
            continue
        try:
            src.unlink()  # delete file
            deleted.append(src)
        except Exception as e:
            failed.append((src, f"delete_error:{e}"))
    # Optionally remove now-empty directories (walk bottom-up)
    if remove_empty_dirs:
        # Collect candidate directories (parents of deleted files), unique and sorted deepest-first
        dirs = {p.parent for p in deleted}
        # Walk deeper levels first
        dirs = sorted(dirs, key=lambda p: len(p.parts), reverse=True)
        for d in dirs:
            try:
                # Only remove if directory is empty and within the original src tree
                if d.exists() and d.is_dir() and not any(d.iterdir()):
                    d.rmdir()
            except Exception:
                pass
    return deleted, failed

def determine_script_and_base_dir():
    try:
        script_path = Path(__file__).resolve()
        base_dir = script_path.parent
    except NameError:
        # interactive interpreter / __file__ not defined
        base_dir = Path.cwd()
        script_path = base_dir / Path(sys.argv[0]).name
    return script_path, base_dir

def main():
    parser = argparse.ArgumentParser(description="Backup current script directory and optionally delete originals.")
    parser.add_argument("-r", "--recursive", action="store_true", help="Copy directories recursively (files + directories).")
    parser.add_argument("-n", "--name", default="backup", help="Base name for the backup directory (default: 'backup').")
    parser.add_argument("-d", "--delete", action="store_true", help="Delete original files after successful backup (requires confirmation unless --force).")
    parser.add_argument("--remove-empty-dirs", action="store_true", help="After deleting backed up files, remove empty source directories (recursive mode only).")
    parser.add_argument("--hash", action="store_true", help="Verify copies using SHA-256 hash before deleting (slower).")
    parser.add_argument("--force", action="store_true", help="Skip confirmation prompt when --delete is used.")
    args = parser.parse_args()

    script_path, base_dir = determine_script_and_base_dir()
    script_name = script_path.name

    try:
        backup_dir = create_unique_backup_dir(base_dir, args.name)
    except FileExistsError:
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
    print(f"Delete originals  : {'Yes' if args.delete else 'No'}")
    if args.delete:
        print(f"Verification mode : {'SHA-256' if args.hash else 'size-only'}")
        print(f"Remove empty dirs : {'Yes' if args.remove_empty_dirs else 'No'}")

    # Exclude script and backup dir name to avoid copying/deleting them
    exclude = {backup_dir.name, script_name}

    print("Starting copy...")
    if args.recursive:
        copied = copy_files_recursive(base_dir, backup_dir, exclude)
    else:
        copied = copy_files_non_recursive(base_dir, backup_dir, exclude)

    print(f"Copied {len(copied)} files.")
    if len(copied) == 0:
        print("No files copied. Exiting.")
        return

    # If deletion requested, confirm and perform verification then deletion
    if args.delete:
        if not args.force:
            resp = input("Are you sure you want to DELETE the original files that were backed up? THIS CANNOT BE UNDONE. (y/N): ").strip().lower()
            if resp != "y":
                print("Aborting deletion. Backup completed, originals kept.")
                return
        print("Verifying copies and deleting originals...")
        deleted, failed = delete_backed_files(copied, exclude, args.hash, args.remove_empty_dirs)
        print(f"Deleted {len(deleted)} files.")
        if failed:
            print(f"Failed to delete {len(failed)} files. Details (first 10 shown):")
            for f in failed[:10]:
                print(" -", f[0], "reason:", f[1])
        else:
            print("All backed files deleted successfully (subject to verification).")
    else:
        print("Backup completed. Originals kept (deletion not requested).")

    print("Done.")

if __name__ == "__main__":
    main()
