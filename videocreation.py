import cv2
import os
import numpy as np

def create_video_from_images(image_folder, output_video, fps=30):
    images = [img for img in os.listdir(image_folder) if img.endswith(".png")]
    images.sort(key=lambda x: int(''.join(filter(str.isdigit, os.path.splitext(x)[0]))))

    if not images:
        print("No images found in the folder.")
        return

    img = cv2.imread(os.path.join(image_folder, images[0]))
    height, width = img.shape[:2]

    # Use MPEG-4 codec (works on most systems without additional libraries)
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    video = cv2.VideoWriter(output_video, fourcc, fps, (width, height))

    for image in images:
        img_path = os.path.join(image_folder, image)
        img = cv2.imread(img_path, cv2.IMREAD_UNCHANGED)
        if img.shape[2] == 4:  # If image has an alpha channel
            img = cv2.cvtColor(img, cv2.COLOR_RGBA2RGB)
        video.write(img)

    video.release()
    
    if os.path.exists(output_video) and os.path.getsize(output_video) > 0:
        print(f"Video saved as {output_video}")
        # Only remove images if video creation is successful
        for image in images:
            os.remove(os.path.join(image_folder, image))
    else:
        print("Video creation failed. Images were not removed.")

def extract_frames_from_video(video_path, output_folder, image_format="png"):
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)

    cap = cv2.VideoCapture(video_path)
    img_index = 0

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        frame_filename = os.path.join(output_folder, f"{img_index:030}.{image_format}")
        cv2.imwrite(frame_filename, frame, [cv2.IMWRITE_PNG_COMPRESSION, 0])  # Lossless PNG
        img_index += 1

    cap.release()
    print(f"{img_index} frames have been extracted to {output_folder}.")

    # Only remove the video if frame extraction is successful
    if img_index > 0:
        os.remove(video_path)
    else:
        print("Frame extraction failed. Video was not removed.")

# Example usage
image_folder = "encoded_images"
output_video = 'output_video.mp4'
output_frame_folder = image_folder

# Uncomment these lines to use the functions
create_video_from_images(image_folder, output_video, fps=30)
# extract_frames_from_video(output_<video, output_frame_folder, image_format="png")