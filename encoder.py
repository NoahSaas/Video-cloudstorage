import base64
import os

selected_file = r"C:\Users\Noah\Documents\GitHub\Video-cloudstorage\pic.png"
output_file = r"C:\Users\Noah\Documents\GitHub\Video-cloudstorage\encoded_pic.txt"


def encodeb64(input_path, file2write2):
    with open(input_path, "rb") as image_file:
        encoded_string = base64.b64encode(image_file.read())

    with open(file2write2, "wb") as output:
        output.write(encoded_string)


encodeb64(selected_file, output_file)




def decode_base64_to_image(base64_string, output_path):
    """
    Decodes a base64-encoded string and saves the resulting image to the specified output path.
    
    Args:
        base64_string (bytes): The base64-encoded data.
        output_path (str): The path to the output image file.
    """
    with open(output_path, "wb") as image_file:
        image_file.write(base64.b64decode(base64_string))
    print(f"Image decoded and saved to: {output_path}")

