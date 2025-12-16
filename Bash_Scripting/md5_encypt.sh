#!/usr/bin/env bash
# md5_hash_file.sh
# Read a file of plaintext passwords (one per line), hash each password with MD5,
# and write the resulting hashes to an output file (one hash per line).
#
# The script prompts for the input filename and the output filename.
# It includes a portable MD5 implementation using md5sum / openssl / python fallback.
#
# NOTE: This script writes only the hashes (not the plaintext) to the output file.
#       MD5 is a one-way hash — it cannot be decrypted.

set -u  # treat unset variables as an error

# ---------- Helper: compute_md5 ----------
# compute_md5 "<string>"
# Returns the MD5 hex digest for the given string using whichever tool is available.
compute_md5() {
  local data="$1"

  if command -v md5sum >/dev/null 2>&1; then
    printf '%s' "$data" | md5sum | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    # openssl md5 prints: "(stdin)= <hash>" so awk '{print $2}'
    printf '%s' "$data" | openssl md5 2>/dev/null | awk '{print $2}'
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$data" | python3 -c "import sys,hashlib; print(hashlib.md5(sys.stdin.buffer.read()).hexdigest())"
  elif command -v python >/dev/null 2>&1; then
    # Python 2 fallback
    printf '%s' "$data" | python -c "import sys,hashlib; print(hashlib.md5(sys.stdin.read()).hexdigest())"
  else
    echo "Error: no MD5 tool found (md5sum/openssl/python). Install one." >&2
    exit 2
  fi
}

# ---------- Prompt user for filenames ----------
read -rp "Enter the path to the input file containing plaintext passwords: " INPUT_FILE
if [ -z "$INPUT_FILE" ]; then
  echo "No input file provided. Exiting."
  exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: input file '$INPUT_FILE' not found or is not a regular file." >&2
  exit 1
fi

read -rp "Enter the path for the output file to write MD5 hashes (will be overwritten): " OUTPUT_FILE
if [ -z "$OUTPUT_FILE" ]; then
  echo "No output filename provided. Exiting."
  exit 1
fi

# ---------- Process file ----------
# Clear or create the output file
: > "$OUTPUT_FILE" || { echo "Error: cannot write to '$OUTPUT_FILE'." >&2; exit 1; }

# Read the input file line-by-line. This handles passwords that may contain spaces.
# Using '|| [ -n "$line" ]' ensures the last line is processed even if it doesn't end with a newline.
while IFS= read -r line || [ -n "${line-}" ]; do
  # Skip empty lines to avoid blank hashes (optional)
  if [ -z "$line" ]; then
    continue
  fi

  # Compute the MD5 of the exact line (no trailing newline included)
  hash="$(compute_md5 "$line")"
  printf '%s\n' "$hash" >> "$OUTPUT_FILE"
done < "$INPUT_FILE"

echo "Done. MD5 hashes written to: $OUTPUT_FILE"
