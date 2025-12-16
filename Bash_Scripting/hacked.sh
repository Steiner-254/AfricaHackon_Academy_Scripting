#!/usr/bin/env bash
# hacked-funny.sh
# A fun (non-malicious) Bash script that prints a colorful,
# joking message to the terminal.
# No hacking involved — just terminal colors and humor 😄

# ---------- Safety settings ----------
# We don't use 'set -e' because nothing here should stop the script
set -u

# ---------- ANSI color codes ----------
# These codes tell the terminal to change text color
RED="\033[0;31m"
BLUE="\033[0;34m"
GREEN="\033[0;32m"
RESET="\033[0m"   # Resets color back to default

# ---------- Message ----------
MESSAGE="💀 YOU ARE HACKED BY ANONYMOUS 💀 (Pay Ksh 10 bob To 123456789 To Remove The Virus!)"

# ---------- Number of times to print ----------
COUNT=15

# ---------- Main loop ----------
for i in $(seq 1 "$COUNT"); do
  # Pick a color based on the loop count (rotates colors)
  case $((i % 3)) in
    0)
      COLOR="$RED"
      ;;
    1)
      COLOR="$BLUE"
      ;;
    2)
      COLOR="$GREEN"
      ;;
  esac

  # Print the message in the chosen color
  # -e enables interpretation of color escape sequences
  echo -e "${COLOR}${MESSAGE}${RESET}"

  # Tiny delay for dramatic effect (optional but funny)
  sleep 1.0
done

# ---------- End ----------
# Terminal color is reset automatically, so no lasting damage 😎
