1. `encode_base64.sh`
   - Prompts the user for an **input file** containing plaintext passwords (one per line).
   - Prompts the user for an **output file** to write Base64-encoded lines (one encoded string per line).
   - Uses a portable method to Base64-encode (works on GNU/Linux and macOS; falls back to Python3 if needed).
   - Skips empty lines in the input and preserves order of non-empty lines.
   - Provides clear error messages and exits with non-zero on fatal errors.
   - Includes usage instructions in comments.

2. `decode_base64.sh`
   - Prompts the user for an **input file** containing Base64 strings (one per line).
   - Prompts the user for an **output file** to write the decoded plaintext (one line per decoded entry).
   - Detects the correct Base64 decode flag for the system (`--decode`, `-d`, or `-D`) and falls back to Python3 if needed.
   - Handles decode errors gracefully (writes an explanatory placeholder line and continues).
   - Provides clear error messages and exits with non-zero on fatal errors.
   - Includes usage instructions in comments.
