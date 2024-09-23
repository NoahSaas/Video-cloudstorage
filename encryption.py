from cryptography.fernet import Fernet

def generate_key():
    return Fernet.generate_key()

def encrypt_b64_string(b64_string, key):
    f = Fernet(key)
    encrypted_bytes = f.encrypt(b64_string.encode())
    return encrypted_bytes.decode()  # Returns another string

def decrypt_b64_string(encrypted_string, key):
    f = Fernet(key)
    decrypted_bytes = f.decrypt(encrypted_string.encode())
    return decrypted_bytes.decode()  # Returns the original Base64 string

# Example usage
key = generate_key()
original_b64 = "SGVsbG8sIFdvcmxkIQ=="  # Base64 for "Hello, World!"
encrypted = encrypt_b64_string(original_b64, key)
decrypted = decrypt_b64_string(encrypted, key)

print(f"Original Base64: {original_b64}")
print(f"Encrypted: {encrypted}")
print(f"Decrypted: {decrypted}")
print(f"Decrypted matches original: {original_b64 == decrypted}")