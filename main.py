import base64
from PIL import Image
import numpy as np
import math
import magic

def encode_to_image(b64_string):
    # Calculate image dimensions
    width = 1000
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
    img = Image.fromarray(img_array)
    img.save('encoded_image.png')
    return img

def decode_from_image(img):
    # Convert image to numpy array
    img_array = np.array(img)
    
    # Extract base64 characters from the array
    b64_chars = []
    for y in range(img_array.shape[0]):
        for x in range(img_array.shape[1]):
            for c in range(3):
                if img_array[y, x, c] != 0:
                    b64_chars.append(chr(img_array[y, x, c]))
    
    # Join characters and return the base64 string
    return ''.join(b64_chars)


with open('decoded_image.png', 'rb') as f:
    file_content = f.read()

file_type = magic.from_buffer(file_content, mime=True)
print(f"The file type appears to be: {file_type}")