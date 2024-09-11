import base64
from PIL import Image
import numpy as np
import os

def encode_to_image(file_path, max_width=1280, max_height=720):
    file_ext = os.path.splitext(file_path)[1][1:]
    
    with open(file_path, "rb") as f:
        file_bytes = f.read()
    
    b64_bytes = base64.b64encode(file_bytes)
    b64_bytes = f'{file_ext}:'.encode() + b64_bytes

    chunk_size = max_width * max_height * 3
    output_dir = 'encoded_images'
    os.makedirs(output_dir, exist_ok=True)

    for img_index, i in enumerate(range(0, len(b64_bytes), chunk_size)):
        chunk = b64_bytes[i:i+chunk_size]
        
        # Pad the chunk to fill the entire image
        padding_needed = chunk_size - len(chunk)
        chunk += b'\0' * padding_needed
        
        # Reshape the chunk into a 2D array
        img_array = np.frombuffer(chunk, dtype=np.uint8).reshape(max_height, max_width, 3)
        
        # Create and save the image
        encoded_img = Image.fromarray(img_array)
        img_path = os.path.join(output_dir, f'{img_index:030d}.png')
        encoded_img.save(img_path, compress_level=1)  # Use minimal compression for speed
    
    print(f"Encoding complete. {img_index + 1} images created.")



def decode_from_image(directory):
    if not os.path.exists(directory):
        raise FileNotFoundError(f"The directory '{directory}' does not exist.")

    img_paths = sorted([os.path.join(directory, file) for file in os.listdir(directory) if file.endswith(".png")])

    if not img_paths:
        raise ValueError("No image files found in the directory.")

    b64_bytes = bytearray()

    for img_path in img_paths:
        try:
            img = Image.open(img_path)
            img_array = np.array(img)
            b64_bytes.extend(img_array.tobytes())
        except Exception as e:
            print(f"Error processing image {img_path}: {e}")
            continue

    # Remove null padding
    b64_bytes = b64_bytes.rstrip(b'\0')

    try:
        decoded_b64_string = b64_bytes.decode('utf-8', errors='ignore')
        file_ext, b64_data = decoded_b64_string.split(':', 1)
    except ValueError as e:
        print(f"Error splitting decoded string: {e}")
        return None

    try:
        decoded_bytes = base64.b64decode(b64_data)
    except base64.binascii.Error as e:
        print(f"Base64 decoding error: {e}")
        return None

    decoded_file_path = f"decoded_file.{file_ext}"
    with open(decoded_file_path, "wb") as f:
        f.write(decoded_bytes)
    
    for img_path in img_paths:
        os.remove(img_path)
        print(f"Removed: {img_path}")


    return decoded_file_path


encode_to_image("Electro Pop 2000  The Best Electro Music 2021  Electro Pop Party  Dj Roll Perú.mp3")
#decode_from_image("encoded_images")