#!/usr/bin/env bash
# merry_christmas.sh
# A simple Bash script that prints a festive message 20 times.
# Written to be clear and fully commented for learning or reuse.

# Exit immediately if a command exits with a non-zero status,
# treat unset variables as an error, and make pipelines fail on first error.
set -euo pipefail

# ---------- Configuration ----------
# The message to print. Put the exact text here so it's easy to change later.
message="AfricaHackon Wishes You Merry Christmas & Happy New Year"

# How many times to print the message.
# Using an integer ensures the loop below is explicit and easy to adjust.
count=20

# ---------- Main logic ----------
# Loop from 1 to $count and print the message each iteration.
# Using printf instead of echo for predictable behavior across environments.
for i in $(seq 1 "$count"); do
  # Print the message followed by a newline.
  printf '%s\n' "$message"
done

# ---------- End ----------
# Optionally print a final summary line (commented out).
# printf 'Printed the message %d times.\n' "$count"
