import base64
import os

selected_file = r"C:\Users\Noah\Documents\GitHub\Video-cloudstorage\pic.png"
output_file = r"C:\Users\Noah\Documents\GitHub\Video-cloudstorage\encoded_pic.txt"



def encodeb64(input_path, file2write2):
    with open(input_path, "rb") as image_file:
        encoded_string = base64.b64encode(image_file.read())

    with open(file2write2, "wb") as output:
        output.write(encoded_string)


def decodeb64(base64_string, output_path):
    with open(output_path, "wb") as image_file:
        image_file.write(base64.b64decode(base64_string))
    


with open(output_file, "r") as encoded_file:
    encoded_string = encoded_file.read().strip()

decodeb64(encoded_string, r"C:\Users\Noah\Documents\GitHub\Video-cloudstorage\decoded_pics\decoded_pic.png")