import cv2
import os
import subprocess

def create_video_from_images(image_folder, output_video, fps=30):
    images = [img for img in os.listdir(image_folder) if img.endswith(".png")]
    images = sorted(images, key=lambda x: int(''.join(filter(str.isdigit, os.path.splitext(x)[0]))))

    if not images:
        print("No images found in the folder.")
        return

    frame = cv2.imread(os.path.join(image_folder, images[0]))
    height, width, _ = frame.shape

    # Create a temporary raw video file
    temp_video = 'temp_output.avi'
    fourcc = cv2.VideoWriter_fourcc(*'HFYU')  # HuffYUV codec (lossless)
    video = cv2.VideoWriter(temp_video, fourcc, fps, (width, height))

    for image in images:
        img_path = os.path.join(image_folder, image)
        img = cv2.imread(img_path)
        video.write(img)

    video.release()
    cv2.destroyAllWindows()

    # Convert the temporary video to MP4 using FFmpeg
    ffmpeg_cmd = [
        'ffmpeg',
        '-i', temp_video,
        '-c:v', 'libx264',
        '-preset', 'veryslow',
        '-crf', '0',  # Lossless
        '-c:a', 'copy',
        output_video
    ]
    subprocess.run(ffmpeg_cmd, check=True)

    # Remove the temporary video
    os.remove(temp_video)

    print(f"Video saved as {output_video}")

    # Remove all images from the folder
    for image in images:
        os.remove(os.path.join(image_folder, image))

def extract_frames_from_video(video_path, output_folder, image_format="png"):
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)

    # Use FFmpeg to extract frames
    ffmpeg_cmd = [
        'ffmpeg',
        '-i', video_path,
        '-qscale:v', '1',  # Highest quality for images
        f'{output_folder}/%030d.{image_format}'
    ]
    subprocess.run(ffmpeg_cmd, check=True)

    print(f"Frames have been extracted to {output_folder}.")

    # Remove the video file after frames have been extracted
    os.remove(video_path)

# Example usage
image_folder = "encoded_images"
output_video = 'output_video.mp4'
output_frame_folder = image_folder


create_video_from_images(image_folder, output_video, fps=30)
# extract_frames_from_video(output_video, output_frame_folder, image_format="png")