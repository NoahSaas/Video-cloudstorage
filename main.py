import base64
from PIL import Image
import numpy as np
import math

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



#with open("BRUH.png", "rb") as f:
    #b64_string = base64.b64encode(f.read()).decode('utf-8')
    

with Image.open("encoded_image.png") as img:
    decodedb64_string = decode_from_image(img)
    decoded_bytes = base64.b64decode(decodedb64_string)

with open("decoded_BRUH.png", "wb") as f:
    f.write(decoded_bytes)