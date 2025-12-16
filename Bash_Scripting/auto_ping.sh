#!/usr/bin/env bash
# ping-monitor.sh
# This script asks the user to enter a domain or IP address,
# then continuously pings it every 10 seconds and reports
# whether the target is live or unreachable.

# Do not use 'set -e' because ping returns non-zero when a host is down,
# and we want the script to continue running.
set -uo pipefail

# ---------- Configuration ----------
# Time (in seconds) to wait between pings
SLEEP_TIME=10

# ---------- User input ----------
# Prompt the user to enter a domain or IP address
read -rp "Enter a domain or IP to monitor: " DOMAIN

# Ensure the user actually entered something
if [ -z "$DOMAIN" ]; then
  echo "Error: No domain provided. Exiting."
  exit 1
fi

# ---------- Signal handling ----------
# Handle Ctrl+C gracefully
cleanup() {
  echo
  echo "Stopping ping monitor. Goodbye."
  exit 0
}

trap cleanup INT TERM

# ---------- Main loop ----------
while true; do
  # Get the current date and time for logging
  TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"

  # Ping the domain once (-c 1 sends a single ICMP packet)
  if ping -c 1 "$DOMAIN" >/dev/null 2>&1; then
    # If ping succeeds (exit code 0), the host is reachable
    echo "$TIMESTAMP - $DOMAIN is LIVE"
  else
    # If ping fails (non-zero exit code), the host is unreachable
    echo "$TIMESTAMP - $DOMAIN is DOWN"
  fi

  # Wait for the specified number of seconds before pinging again
  sleep "$SLEEP_TIME"
done
