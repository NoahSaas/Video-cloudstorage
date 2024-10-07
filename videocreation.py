import cv2
import os
import subprocess

def create_video_from_images(image_folder, output_video, fps=60):
    images = [img for img in os.listdir(image_folder) if img.endswith(".png")]
    images = sorted(images, key=lambda x: int(''.join(filter(str.isdigit, os.path.splitext(x)[0]))))

    if not images:
        print("No images found in the folder.")
        return

    print(f"Number of images to process: {len(images)}")

    # Create a temporary file with the list of image files
    temp_file = 'temp_file_list.txt'
    with open(temp_file, 'w') as file:
        for image in images:
            file.write(f"file '{os.path.join(image_folder, image)}'\n")

    # Use FFmpeg with the file list to create the video
    ffmpeg_cmd = [
        'ffmpeg',
        '-r', str(fps),
        '-f', 'concat',
        '-safe', '0',
        '-i', temp_file,
        '-c:v', 'libx264',
        '-preset', 'veryslow',
        '-crf', '17',  # Very high quality, visually lossless
        '-pix_fmt', 'yuv420p',  # More compatible color space
        '-movflags', '+faststart',  # Optimize for web streaming
        output_video
    ]
    
    try:
        subprocess.run(ffmpeg_cmd, check=True)
        print(f"High quality video saved as {output_video}")
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

#create_video_from_images(image_folder, output_video, fps=60)
extract_frames_from_video(output_video, image_folder, image_format="png")

# Print contents of the folder after extraction
print("\nContents of the folder after extraction:")
for file in sorted(os.listdir(image_folder)):
    print(file)