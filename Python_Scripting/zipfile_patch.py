import zipfile

# Extract a ZIP file
zip_file_path = 'example.zip'
extract_folder = 'extracted_files/'

with zipfile.ZipFile(zip_file_path, 'r') as zip_ref:
    zip_ref.extractall(extract_folder)

print(f"Extracted all files to '{extract_folder}'")
