#!/usr/bin/env bash
# analyze_logs.sh
# Analyze a log file (in the current directory) for common anomalies:
#  - SQL injection signatures (heuristic)
#  - XSS attempts
#  - Local file inclusion (LFI) patterns
#  - Suspicious user agents (scanners, sqlmap, masscan)
#  - Admin access from non-whitelisted IPs
#  - Data exfiltration (large response sizes / downloads)
#  - Brute-force login (many 401/403 from same IP)
#  - Error spikes (many 5xx responses)
#
# This version prompts the user ONLY for a filename (no path).
# Usage: ./analyze_logs.sh
# Place the log file in the same directory and run the script; enter only the filename (e.g. system_logs.txt).
set -uo pipefail

# Prompt for filename only (no path allowed)
read -rp "Enter the log filename (in current directory, e.g. system_logs.txt): " FILENAME

# Basic validation: non-empty and does not contain a slash
if [ -z "${FILENAME:-}" ]; then
  echo "Error: no filename provided. Exiting." >&2
  exit 1
fi

if printf '%s' "$FILENAME" | grep -q '/'; then
  echo "Error: please provide a filename only (no path). Place the file in the current directory and try again." >&2
  exit 1
fi

# Resolve to a file in the current directory
LOGFILE="./${FILENAME}"

if [ ! -f "$LOGFILE" ]; then
  echo "Error: file '$LOGFILE' not found in the current directory ($(pwd))." >&2
  exit 1
fi

REPORT="analysis_report.txt"
: > "$REPORT"

echo "Log analysis report for: $LOGFILE" | tee -a "$REPORT"
echo "Generated at: $(date -u '+%Y-%m-%d %H:%M:%S UTC')" | tee -a "$REPORT"
echo "----------------------------------------" | tee -a "$REPORT"

# Helper function to print a heading to console and report
heading() {
  echo
  echo "=== $1 ===" | tee -a "$REPORT"
}

# --- 1) SQLi heuristics ---
heading "SQL injection indicators (heuristic matches)"
# common SQLi fragments (case-insensitive)
grep -niE "' OR '1'='1|UNION SELECT| OR 1=1|sleep\(|benchmark\(|WAITFOR DELAY|-- " "$LOGFILE" | tee -a "$REPORT" || true
echo >> "$REPORT"

# --- 2) XSS heuristics ---
heading "XSS attempt indicators"
grep -niE "<script>|onerror=|alert\(|<img src=.+onerror=" "$LOGFILE" | tee -a "$REPORT" || true
echo >> "$REPORT"

# --- 3) LFI / file inclusion heuristics ---
heading "Local File Inclusion / path traversal indicators"
grep -niE "\.\./\.\.|/etc/passwd|php://input|/proc/self/environ" "$LOGFILE" | tee -a "$REPORT" || true
echo >> "$REPORT"

# --- 4) Suspicious user-agents (scanners and automated tools) ---
heading "Suspicious user-agent strings (scanning tools)"
grep -niE "sqlmap|masscan|nmap|python-requests|OWASP ZAP|Nmap|curl" "$LOGFILE" | tee -a "$REPORT" || true
echo >> "$REPORT"

# --- 5) Admin access events (non-whitelisted IPs flagged) ---
heading "Admin panel accesses (HTTP 200) - review for suspicious sources"
# Customize WHITELIST_REGEX to include internal administrative IPs; here we use common private ranges
WHITELIST_REGEX="^(10\.|172\.16\.|192\.168\.)"
# Show lines that access /admin and returned 200, then flag if not matching whitelist
while IFS= read -r line; do
  ip="$(printf '%s\n' "$line" | awk '{print $1}')"
  if ! printf '%s' "$ip" | grep -qE "$WHITELIST_REGEX"; then
    echo "$line" | tee -a "$REPORT"
  fi
done < <(grep -niE '\"(GET|POST).*/admin' "$LOGFILE" | grep ' 200 ' || true)
echo >> "$REPORT"

# --- 6) Data exfiltration heuristics (large responses / downloads) ---
heading "Potential data exfiltration: large responses and export/download endpoints"
# The bytes field is typically the numeric token after the status code in our log format.
# We'll select entries where the bytes value is unusually large (e.g., >100000).
awk '
  {
    # find the token index of the status code (first 3-digit token) then bytes is token+1
    status_index=0
    for(i=1;i<=NF;i++){
      if($i ~ /^[0-9]{3}$/){ status_index=i; break }
    }
    if(status_index>0 && (status_index+1)<=NF){
      bytes=$(status_index+1)
      if(bytes+0>100000) print $0
    }
  }
' "$LOGFILE" | tee -a "$REPORT" || true

# Also flag GET/POST to known export/download endpoints
grep -niE '/export|/download|/api/.*/export|/download/' "$LOGFILE" | tee -a "$REPORT" || true
echo >> "$REPORT"

# --- 7) Brute-force / failed login bursts ---
heading "Failed login bursts (many 401/403 from same IP)"
# Count 401/403 per IP and show IPs with more than a threshold (e.g., 5)
awk '$0 ~ / 401 |  403 / { ip=$1; count[ip]++ } END { for (i in count) if (count[i] >= 5) print count[i], i }' "$LOGFILE" | sort -nr | tee -a "$REPORT" || true
echo >> "$REPORT"

# --- 8) Error spikes ---
heading "Server error spike summary (5xx errors per 1-hour window approximation)"
# Extract timestamp and status; timestamps are like [16/Dec/2025:10:12:03 +0000]
awk '
  match($0, /\[([0-9]{2}\/[A-Za-z]{3}\/[0-9]{4}):([0-9]{2}):[0-9]{2}/, m) {
    hour = m[1] ":" m[2] "h"
    for(i=1;i<=NF;i++){ if($i ~ /^[0-9]{3}$/){ status=$i; break } }
    if(status ~ /^5[0-9][0-9]$/) { count[hour]++ }
  }
  END { for (h in count) print count[h], h }
' "$LOGFILE" | sort -rn | tee -a "$REPORT" || true
echo >> "$REPORT"

# --- 9) Summary counts ---
heading "Summary counts of detected indicators"
echo "Total lines scanned: $(wc -l < "$LOGFILE")" | tee -a "$REPORT"
echo "SQLi indicator matches: $(grep -ciE \"' OR '1'='1|UNION SELECT| OR 1=1|sleep\\(|benchmark\\(|WAITFOR DELAY|-- \" \"$LOGFILE\" || true)" | tee -a "$REPORT"
echo "XSS indicator matches: $(grep -ciE \"<script>|onerror=|alert\\(|<img src=.+onerror=\" \"$LOGFILE\" || true)" | tee -a "$REPORT"
echo "LFI indicator matches: $(grep -ciE \"\\.{2}/\\.{2}|/etc/passwd|php://input|/proc/self/environ\" \"$LOGFILE\" || true)" | tee -a "$REPORT"
echo "Suspicious UA matches: $(grep -ciE \"sqlmap|masscan|nmap|python-requests|OWASP ZAP|Nmap|curl\" \"$LOGFILE\" || true)" | tee -a "$REPORT"
echo "Lines flagged for admin access (200): $(grep -ciE '\"(GET|POST).*/admin' \"$LOGFILE\" | grep -c \"200\" || true)" | tee -a "$REPORT"

echo >> "$REPORT"
echo "Detailed report saved to $REPORT"
echo "End of analysis."
