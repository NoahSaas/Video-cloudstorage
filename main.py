import base64
from PIL import Image
import numpy as np
import math
import os


def encode_to_image(file_path):
    # Extract file extension
    file_ext = os.path.splitext(file_path)[1][1:]  # Get the file extension without the dot
    
    with open(file_path, "rb") as f:
        b64_string = base64.b64encode(f.read()).decode('utf-8')
    
    # Add file extension to the beginning of the base64 string
    b64_string = f'{file_ext}:{b64_string}'

    # Calculate image dimensions
    width = 720
    height = math.ceil(len(b64_string) / (width * 3))
    
    # Create a numpy array to hold the image data
    img_array = np.zeros((height, width, 3), dtype=np.uint8)
    
    # Fill the array with base64 data
    for i, char in enumerate(b64_string):
        y = i // (width * 3)
        x = (i // 3) % width
        c = i % 3
        img_array[y, x, c] = ord(char)
    
    # Create and save the image
    encoded_img = Image.fromarray(img_array)
    encoded_img.save('encoded_img.png')
    return encoded_img


def decode_from_image(img_path):
    # Convert image to numpy array
    img = Image.open(img_path)
    img_array = np.array(img)
    
    # Extract base64 characters from the array
    b64_chars = []
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
    
    return decoded_file_path


#encode_to_image("cat sad song #meow #meow.mp4")
#decode_from_image("encoded_img.png")


