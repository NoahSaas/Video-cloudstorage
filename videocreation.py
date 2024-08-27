import cv2
import os
from PIL import Image

def create_video_from_images(image_folder, output_video, fps=30):
    images = [img for img in os.listdir(image_folder) if img.endswith(".png") or img.endswith(".jpg")]
    images.sort()  # Sort images by name

    # Get the dimensions of the images
    frame = cv2.imread(os.path.join(image_folder, images[0]))
    height, width, layers = frame.shape

    # Define the codec and create a VideoWriter object
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')  # Codec for .mp4 files
    video = cv2.VideoWriter(output_video, fourcc, fps, (width, height))

    for image in images:
        img_path = os.path.join(image_folder, image)
        img = cv2.imread(img_path)
        video.write(img)

    video.release()
    cv2.destroyAllWindows()
    print(f"Video saved as {output_video}")

# Example usage
image_folder = 'encoded_images'
output_video = 'output_video.mp4'
create_video_from_images(image_folder, output_video, fps=30)
