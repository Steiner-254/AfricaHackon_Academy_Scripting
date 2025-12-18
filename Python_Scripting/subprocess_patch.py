import subprocess

# Run a simple shell command
result = subprocess.run(['ls', '-l'], capture_output=True, text=True)

# Print the output
print("Command Output:")
print(result.stdout)

# Check for errors
if result.returncode != 0:
    print("Error:", result.stderr)
    