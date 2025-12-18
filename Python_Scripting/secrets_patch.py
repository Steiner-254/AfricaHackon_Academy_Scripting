import secrets
import string

def generate_secure_password(length=12):
    characters = string.ascii_letters + string.digits + string.punctuation
    secure_password = ''.join(secrets.choice(characters) for _ in range(length))
    return secure_password

# Generate a secure password
password = generate_secure_password()
print("Generated Secure Password:", password)
