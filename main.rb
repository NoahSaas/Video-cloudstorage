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
    image_count = Dir.glob(image_pattern.gsub('%d', '*')).length
    frames_needed = 24 - image_count

    if frames_needed > 0
        frames_needed.times do |i|
            system("ffmpeg -f lavfi -i color=black:s=#{RESOLUTION[0]}x#{RESOLUTION[1]} -frames:v 1 black_frame_#{i + 1}.png")
            FileUtils.mv("black_frame_#{i + 1}.png", "chunk_#{image_count + i + 1}.png")
        end
    end

    system("ffmpeg -framerate 24 -i #{image_pattern} -c:v libx264 -pix_fmt yuv420p #{output_video}.mp4")
    Dir.glob("chunk_*.png").each { |file| File.delete(file) }
end


def extract_images_from_video(input_video)
    # Extract frames from the video as PNG images
    system("ffmpeg -i #{input_video} -vf fps=24 chunk_%d.png")
    File.delete(input_video) if File.exist?(input_video)

    # Iterate over the extracted images and remove black frames
    Dir.glob("chunk_*.png").each do |image_path|
        image = ChunkyPNG::Image.from_file(image_path)
        
        # Check if all pixels are black
        is_black = image.pixels.all? { |pixel| ChunkyPNG::Color.r(pixel) == 0 && ChunkyPNG::Color.g(pixel) == 0 && ChunkyPNG::Color.b(pixel) == 0 }

        # If the frame is black, delete the file
        File.delete(image_path) if is_black
    end
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


files = ["chunk_1.png", "chunk_2.png", "chunk_3.png", "chunk_4.png", 
    "chunk_5.png", "chunk_6.png", "chunk_7.png"]

saved = images_to_string(files)


