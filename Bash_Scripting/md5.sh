#!/usr/bin/env bash

# md5_hash_keywords.sh
# --------------------
# Interactive Bash script that:
#  1) Asks the user for a filename that contains keywords (one per line)
#  2) Asks the user for an output filename
#  3) Computes the MD5 hash for each keyword (the string itself, not the file)
#  4) Writes the results to the output file in the format: keyword:md5hash
#
# The script is written to be portable: it uses `md5sum` if available, and
# falls back to `openssl dgst -md5` when `md5sum` is not present.
#
# Usage:
#   Make executable: chmod +x md5_hash_keywords.sh
#   Run: ./md5_hash_keywords.sh

set -euo pipefail
IFS=$'\n\t'

# -----------------
# Helper functions
# -----------------

# print an error message to stderr and exit
err() {
  printf '%s\n' "$1" >&2
  exit 1
}

# check for required hashing commands and set HASH_TOOL variable
select_hash_tool() {
  if command -v md5sum >/dev/null 2>&1; then
    HASH_TOOL="md5sum"
  elif command -v openssl >/dev/null 2>&1; then
    HASH_TOOL="openssl"
  else
    err "Error: neither 'md5sum' nor 'openssl' is available. Install one of them and retry."
  fi
}

# compute md5 hash of a string (no trailing newline added)
# arguments: 1 -> the string to hash
compute_md5() {
  local input="$1"
  local hash

  if [[ "$HASH_TOOL" == "md5sum" ]]; then
    # md5sum prints: <hash>  -  so extract first column
    hash=$(printf '%s' "$input" | md5sum | awk '{print $1}')
  else
    # openssl dgst -md5 prints: (stdin)= <hash>  OR just <hash> depending on version
    # use awk to extract the last field which should be the hash
    hash=$(printf '%s' "$input" | openssl dgst -md5 | awk '{print $NF}')
  fi

  printf '%s' "$hash"
}

# -----------------
# Script starts here
# -----------------

select_hash_tool

# Prompt user for input filename
read -rp "Enter path to keywords file (one keyword per line): " INPUT_FILE

# Validate input file
if [[ ! -f "$INPUT_FILE" || ! -r "$INPUT_FILE" ]]; then
  err "Input file '$INPUT_FILE' does not exist or is not readable."
fi

# Prompt user for output filename
read -rp "Enter output filename (will create or overwrite): " OUTPUT_FILE

# If output exists, ask whether to overwrite
if [[ -e "$OUTPUT_FILE" ]]; then
  read -rp "Output file '$OUTPUT_FILE' already exists. Overwrite? (y/N): " confirm
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Aborted by user. No changes made."
    exit 0
  fi
fi

# Create/truncate the output file and add a header with timestamp
: > "$OUTPUT_FILE" || err "Cannot write to output file '$OUTPUT_FILE'."
printf '# md5 hashes generated on %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$OUTPUT_FILE"
printf '# format: keyword:md5hash\n\n' >> "$OUTPUT_FILE"

# Process the input file line-by-line. Preserve spaces inside keywords.
count=0
while IFS= read -r line || [[ -n "$line" ]]; do
  # Trim leading/trailing whitespace
  # Use parameter expansion to avoid external commands where possible
  keyword="$line"
  # remove leading spaces
  keyword="${keyword##[[:space:]]}"
  # remove trailing spaces
  keyword="${keyword%%[[:space:]]}"

  # Skip empty lines
  if [[ -z "$keyword" ]]; then
    continue
  fi

  # Skip lines that start with a hash (helpful for commented lists)
  if [[ "$keyword" =~ ^# ]]; then
    continue
  fi

  # Compute md5 and append to output
  hash_val=$(compute_md5 "$keyword")

  # Write result in the form: keyword:md5hash
  printf '%s:%s\n' "$keyword" "$hash_val" >> "$OUTPUT_FILE"
  count=$((count + 1))

done < "$INPUT_FILE"

# Final message
printf '\nCompleted. Processed %d keywords. Results saved to: %s\n' "$count" "$OUTPUT_FILE"

exit 0
