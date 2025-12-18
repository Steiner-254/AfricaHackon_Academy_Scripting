import re

# Sample text
text = "Hello, my email is example@example.com and my phone number is 123-456-7890."

# Search for email addresses
emails = re.findall(r'\S+@\S+', text)
print("Found emails:", emails)
