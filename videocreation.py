import os
import subprocess

def create_video_from_images(image_folder, output_video, fps=60, delete_images=False):
    images = [img for img in os.listdir(image_folder) if img.endswith(".png")]
    images = sorted(images, key=lambda x: int(''.join(filter(str.isdigit, os.path.splitext(x)[0]))))

    if not images:
        print("No images found in the folder.")
        return

    # Create a temporary file with the list of image files
    temp_file = 'temp_file_list.txt'
    with open(temp_file, 'w') as file:
        for image in images:
            file.write(f"file '{os.path.join(image_folder, image)}'\n")

    # Use FFmpeg with the file list to create the video
    ffmpeg_cmd = [
        'ffmpeg',
        '-r', str(fps),                # Frame rate (e.g., 60 FPS)
        '-f', 'concat',                # Concatenate images
        '-safe', '0',                  # Safe mode off for reading files outside directory
        '-i', temp_file,               # Input file list
        '-c:v', 'libx264',             # Video codec (H.264 for YouTube)
        '-preset', 'medium',           # Medium speed preset (balance of quality and speed)
        '-crf', '23',                  # Slightly lower quality (adjustable to 17 for higher quality)
        '-pix_fmt', 'yuv420p',         # Use YUV420p for compatibility
        '-movflags', '+faststart',     # Optimizes for web streaming (important for YouTube)
        '-vf', 'scale=1920:1080',      # Set to 1080p resolution (adjust based on image size)
        '-an',                         # Disable audio (since there is none)
        output_video
    ]

    try:
        subprocess.run(ffmpeg_cmd, check=True)
        print(f"High quality video saved as {output_video}")
        
        # If video is created successfully, delete original images if delete_images is True
        if delete_images:
            for image in images:
                image_path = os.path.join(image_folder, image)
                os.remove(image_path)
            print(f"Deleted {len(images)} original PNG images.")
    except subprocess.CalledProcessError as e:
        print(f"Error creating video: {e}")
    finally:
        # Clean up the temporary file
        os.remove(temp_file)


def extract_frames_from_video(video_path, output_folder, image_format="png"):
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)

    # Get video information
    ffprobe_cmd = [
        'ffprobe',
        '-v', 'error',
        '-select_streams', 'v:0',
        '-count_packets',
        '-show_entries', 'stream=nb_read_packets',
        '-of', 'csv=p=0',
        video_path
    ]
    try:
        result = subprocess.run(ffprobe_cmd, capture_output=True, text=True, check=True)
        frame_count = int(result.stdout.strip())
        print(f"Video frame count: {frame_count}")
    except subprocess.CalledProcessError as e:
        print(f"Error getting video information: {e}")
        return

    # Use FFmpeg to extract all frames with high quality
    ffmpeg_cmd = [
        'ffmpeg',
        '-i', video_path,
        '-vsync', '0',  # Prevent frame dropping
        '-q:v', '1',  # Highest quality for images
        f'{output_folder}/%030d.{image_format}'
    ]
    try:
        subprocess.run(ffmpeg_cmd, check=True)
        print(f"Frames have been extracted to {output_folder}.")
        
        # Verify the number of extracted frames
        extracted_frames = [f for f in os.listdir(output_folder) if f.endswith(f'.{image_format}')]
        print(f"Number of extracted frames: {len(extracted_frames)}")
        
        if len(extracted_frames) != frame_count:
            print("Warning: Number of extracted frames does not match video frame count.")
    except subprocess.CalledProcessError as e:
        print(f"Error extracting frames: {e}")

# Example usage
image_folder = "encoded_images"
output_video = 'output_video.mp4'

create_video_from_images(image_folder, output_video, fps=60, delete_images=True)
#extract_frames_from_video(output_video, image_folder, image_format="png")