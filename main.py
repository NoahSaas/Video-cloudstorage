import base64
from PIL import Image
import numpy as np
import math
import os

def encode_to_image(file_path, max_width=1280, max_height=720):
    # Extract file extension
    file_ext = os.path.splitext(file_path)[1][1:]  # Get the file extension without the dot
    
    with open(file_path, "rb") as f:
        b64_string = base64.b64encode(f.read()).decode('utf-8')
    
    # Add file extension to the beginning of the base64 string
    b64_string = f'{file_ext}:{b64_string}'

    # Calculate image dimensions
    width = max_width
    total_pixels = len(b64_string) // 3
    height = math.ceil(total_pixels / width)
    
    # Create a directory to save encoded images
    output_dir = 'encoded_images'
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    img_index = 0

    while height > max_height:
        # Split data into chunks that fit within the max dimensions
        chunk_size = max_width * max_height * 3
        b64_chunk = b64_string[:chunk_size]
        b64_string = b64_string[chunk_size:]

        # Create a numpy array to hold the image data
        img_array = np.zeros((max_height, max_width, 3), dtype=np.uint8)

        # Fill the array with base64 data
        for i, char in enumerate(b64_chunk):
            y = i // (width * 3)
            x = (i // 3) % width
            c = i % 3
            img_array[y, x, c] = ord(char)
        
        # Create and save the image
        encoded_img = Image.fromarray(img_array)
        img_path = os.path.join(output_dir, f'encoded_img_{img_index}.png')
        encoded_img.save(img_path)

        img_index += 1
        height = math.ceil(len(b64_string) / (width * 3))
    
    # Process any remaining data
    if b64_string:
        height = math.ceil(len(b64_string) / (width * 3))
        img_array = np.zeros((max_height, max_width, 3), dtype=np.uint8)
        
        for i, char in enumerate(b64_string):
            y = i // (width * 3)
            x = (i // 3) % width
            c = i % 3
            img_array[y, x, c] = ord(char)

        # Save the last image with padding
        encoded_img = Image.fromarray(img_array)
        img_path = os.path.join(output_dir, f'encoded_img_{img_index}.png')
        encoded_img.save(img_path)

def decode_from_image(directory):
    b64_chars = []

    # Check if the directory exists
    if not os.path.exists(directory):
        raise FileNotFoundError(f"The directory '{directory}' does not exist.")

    # Get a list of image files in the directory and sort them
    img_paths = sorted([os.path.join(directory, file) for file in os.listdir(directory) if file.endswith(".png")])

    if not img_paths:
        raise ValueError("No image files found in the directory.")

    for img_path in img_paths:
        img = Image.open(img_path)
        img_array = np.array(img)

        for y in range(img_array.shape[0]):
            for x in range(img_array.shape[1]):
                for c in range(3):
                    if img_array[y, x, c] != 0:
                        b64_chars.append(chr(img_array[y, x, c]))

    # Join characters and separate the file extension from the base64 string
    decoded_b64_string = ''.join(b64_chars)
    file_ext, b64_data = decoded_b64_string.split(':', 1)

    # Decode the base64 data
    decoded_bytes = base64.b64decode(b64_data)

    # Save the decoded data in the correct format
    decoded_file_path = f"decoded_file.{file_ext}"
    with open(decoded_file_path, "wb") as f:
        f.write(decoded_bytes)

    # Delete the encoded images after decoding
    for img_path in img_paths:
        os.remove(img_path)
    
    return decoded_file_path


#encode_to_image("d.mp4")
decode_from_image("encoded_images")
