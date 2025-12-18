import os

# Specify the file path
file_path = 'example.txt'

# Get the file size
file_size = os.path.getsize(file_path)

# Print the file size in bytes
print(f"File Size: {file_size} bytes")
