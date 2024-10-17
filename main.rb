require 'base64'
require 'openssl'
require 'chunky_png'
require 'fileutils'

RESOLUTION = [1920, 1080]

iv = File.read("iv.bin")
key = File.read("key.txt")
encrypted_data = File.read("encrypted_data.txt")



def write_file(data, file_path)
    File.open(file_path, 'wb') do |file|
        file.write(data)
    end
end


def data_to_string(file_path)
    file_data = File.binread(file_path)
    Base64.strict_encode64(file_data)
end


def encrypt_string(data, key)
    cipher = OpenSSL::Cipher.new('AES-256-CBC')
    cipher.encrypt
    cipher.key = key
    iv = cipher.random_iv
    cipher.iv = iv
    encrypted_data = cipher.update(data) + cipher.final
    { encrypted_data: Base64.strict_encode64(encrypted_data), iv: Base64.strict_encode64(iv) }
    write_file(Base64.strict_encode64(iv), "iv.bin")
    write_file(Base64.strict_encode64(key), "key.txt")
    write_file(Base64.strict_encode64(encrypted_data), "encrypted_data.txt")
end


def string_to_images(encoded_string, chunk_size=(RESOLUTION[0] * RESOLUTION[1]))
    images = []
    num_chunks = (encoded_string.length / chunk_size.to_f).ceil
    block_size = 6

    num_chunks.times do |i|
        chunk = encoded_string[i * chunk_size, chunk_size] || ""
        image = ChunkyPNG::Image.new(RESOLUTION[0], RESOLUTION[1], ChunkyPNG::Color::WHITE)

        chunk.each_char.with_index do |char, index|
            block_x = (index * block_size) % RESOLUTION[0]
            block_y = (index / (RESOLUTION[0] / block_size)) * block_size
            break if block_y >= RESOLUTION[1]

            color_value = char.ord
            block_color = ChunkyPNG::Color.rgb(color_value, color_value, color_value)

            block_size.times do |dx|
                block_size.times do |dy|
                    x = block_x + dx
                    y = block_y + dy
                    image[x, y] = block_color if x < RESOLUTION[0] && y < RESOLUTION[1]
                end
            end
        end

        images << image
        image.save("chunk_#{i + 1}.png")
    end
end
 

def create_video_from_images(output_video, image_pattern="chunk_%d.png")
    # Step 1: Create the video from the generated images
    system("ffmpeg -framerate 24 -i #{image_pattern} -c:v libx264 -pix_fmt yuv420p temp_#{output_video}.mp4")

    # Step 2: Check the duration of the video using ffprobe (part of FFmpeg)
    duration_cmd = `ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 temp_#{output_video}.mp4`
    duration = duration_cmd.to_f

    # Step 3: If the video is less than 1 second, append a black video
    if duration < 1.0
        frames_needed = (24 - (duration * 24)).ceil  # Calculate how many frames are needed
        seconds_needed = (1.0 - duration).ceil       # Ensure the video is at least 1 second

        # Generate a black video of the required length (in seconds)
        system("ffmpeg -f lavfi -i color=black:s=#{RESOLUTION[0]}x#{RESOLUTION[1]}:d=#{seconds_needed} -c:v libx264 -t #{seconds_needed} -pix_fmt yuv420p black_video.mp4")

        # Concatenate the original video and the black video
        File.open('file_list.txt', 'w') do |f|
            f.puts("file 'temp_#{output_video}.mp4'")
            f.puts("file 'black_video.mp4'")
        end

        # Concatenate using FFmpeg
        system("ffmpeg -f concat -safe 0 -i file_list.txt -c copy #{output_video}.mp4")

        # Cleanup
        File.delete("black_video.mp4")
        File.delete("temp_#{output_video}.mp4")
        File.delete("file_list.txt")
    else
        # If already 1 second or longer, rename the temp file to the final output
        File.rename("temp_#{output_video}.mp4", "#{output_video}.mp4")
    end

    # Step 4: Delete the chunk images
    Dir.glob("chunk_*.png").each { |file| File.delete(file) }
end


def extract_images_from_video(input_video)
    system("ffmpeg -i #{input_video} -vf fps=24 chunk_%d.png")
    File.delete(input_video) if File.exist?(input_video)
end


def images_to_string(images)
    combined_string = ""
    images.each do |image_path|
        image = ChunkyPNG::Image.from_file(image_path)
        image.pixels.each do |pixel|
            combined_string << (pixel >> 16 & 0xFF).chr
        end
    end
    combined_string
end


def decrypt_string(encrypted_data, key, iv)
    decipher = OpenSSL::Cipher.new('AES-256-CBC')
    decipher.decrypt
    decipher.key = Base64.strict_decode64(key)
    decipher.iv = Base64.strict_decode64(iv)
    decrypted_data = decipher.update(Base64.strict_decode64(encrypted_data)) + decipher.final
    binary_file = Base64.strict_decode64(decrypted_data)
end 


def generate_data(file_name)
    b64_string = data_to_string(file_name)
    key = OpenSSL::Cipher.new('AES-256-CBC').random_key
    encoded_string = encrypt_string(b64_string, key)
end



string_to_images(encrypted_data)
create_video_from_images("output")