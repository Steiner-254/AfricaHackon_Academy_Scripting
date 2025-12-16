#!/usr/bin/env bash
# md5_reverse_dictionary.sh
# Attempts to "reverse" MD5 hashes using a dictionary (wordlist).
#
# IMPORTANT:
# - MD5 CANNOT be decrypted.
# - This script works by hashing candidate passwords and matching hashes.
#
# Input:
#   1) File containing MD5 hashes (one per line)
#   2) File containing plaintext candidate passwords (one per line)
# Output:
#   File containing recovered hashes and their matching plaintexts

set -u

# ---------- Helper: compute_md5 ----------
compute_md5() {
  local data="$1"

  if command -v md5sum >/dev/null 2>&1; then
    printf '%s' "$data" | md5sum | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    printf '%s' "$data" | openssl md5 2>/dev/null | awk '{print $2}'
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$data" | python3 -c "import sys,hashlib; print(hashlib.md5(sys.stdin.buffer.read()).hexdigest())"
  else
    echo "Error: No MD5 tool available." >&2
    exit 2
  fi
}

# ---------- User input ----------
read -rp "Enter MD5 hash file: " HASH_FILE
read -rp "Enter plaintext password list (dictionary): " WORDLIST_FILE
read -rp "Enter output file for cracked passwords: " OUTPUT_FILE

# ---------- Validation ----------
for f in "$HASH_FILE" "$WORDLIST_FILE"; do
  if [ ! -f "$f" ]; then
    echo "Error: file '$f' not found." >&2
    exit 1
  fi
done

# Clear output file
: > "$OUTPUT_FILE"

echo "Starting MD5 dictionary attack..."
echo "--------------------------------"

# ---------- Core logic ----------
while IFS= read -r hash || [ -n "${hash-}" ]; do
  [ -z "$hash" ] && continue

  while IFS= read -r password || [ -n "${password-}" ]; do
    [ -z "$password" ] && continue

    candidate_hash="$(compute_md5 "$password")"

    if [ "$candidate_hash" = "$hash" ]; then
      echo "$hash : $password" | tee -a "$OUTPUT_FILE"
      break
    fi

  done < "$WORDLIST_FILE"

done < "$HASH_FILE"

echo "--------------------------------"
echo "Done. Results saved to $OUTPUT_FILE"
