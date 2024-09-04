import cv2
import os
import re

def create_video_from_images(image_folder, output_video, fps=30):
    images = [img for img in os.listdir(image_folder) if img.endswith(".png")]

    # Sort images numerically by extracting the numeric part of the filename
    images = sorted(images, key=lambda x: int(''.join(filter(str.isdigit, os.path.splitext(x)[0]))))

    if not images:
        print("No images found in the folder.")
        return

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

    # Remove all images from the folder
    for image in images:
        os.remove(os.path.join(image_folder, image))
    

def extract_frames_from_video(video_path, output_folder, image_format="png"):
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)

    # Open the video file
    cap = cv2.VideoCapture(video_path)
    img_index = 0

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        # Save the frame as an image
        frame_filename = os.path.join(output_folder, f"{img_index:030}.{image_format}")
        cv2.imwrite(frame_filename, frame)
        img_index += 1

    cap.release()
    cv2.destroyAllWindows()
    print(f"{img_index} frames have been extracted to {output_folder}.")

    # Remove the video file after frames have been extracted
    os.remove(video_path)


# Example usage
image_folder = "encoded_images"
output_video = 'output_video.mp4'
output_frame_folder = image_folder


create_video_from_images(image_folder, output_video, fps=30)
#extract_frames_from_video(output_video, output_frame_folder, image_format="png")