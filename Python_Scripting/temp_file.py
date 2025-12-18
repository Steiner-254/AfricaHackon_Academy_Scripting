import tempfile

# Create a temporary file
with tempfile.NamedTemporaryFile(delete=True) as temp_file:
    temp_file.write(b'This is some temporary data.')
    temp_file.seek(0)  # Go back to the beginning of the file
    print(f"Temporary File Name: {temp_file.name}")
    print(f"Temporary File Content: {temp_file.read().decode()}")
    