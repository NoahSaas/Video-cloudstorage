require 'base64'
require 'openssl'
require 'chunky_png'


def save_key_to_file(key, file_name)
    File.open(file_name, 'wb') do |file|
        file.write(key)
    end
end


def data_to_string(file_path)
    file_data = File.binread(file_path)
    Base64.encode64(file_data)
end


encoded_data = data_to_string("ball.jpg")


def encrypt_string(data, key)
    cipher = OpenSSL::Cipher.new('AES-256-CBC')
    cipher.encrypt
    cipher.key = key
    iv = cipher.random_iv
    cipher.iv = iv
    encrypted_data = cipher.update(data) + cipher.final
    { encrypted_data: Base64.encode64(encrypted_data), iv: Base64.encode64(iv) }
end


key = OpenSSL::Cipher.new('AES-256-CBC').random_key
encrypted_result = encrypt_string(encoded_data, key)

save_key_to_file(key, "key")


def string_to_images(encoded_string, chunk_size)
    images = []
    num_chunks = (encoded_string.length / chunk_size.to_f).ceil
    num_chunks.times do |i|
        chunk = encoded_string[i * chunk_size, chunk_size] || "" 
        image = ChunkyPNG::Image.new(1920, 1080, ChunkyPNG::Color::WHITE)
        chunk.each_char.with_index do |char, index|
            x = index % 1920
            y = index.div(1920)
            break if y >= 1080
            image[x, y] = ChunkyPNG::Color.rgb(char.ord, char.ord, char.ord)
        end
        images << image 
    end

    images.each_with_index do |image, index|
        image.save("chunk_#{index}.png")
    end
end


#string_to_images(encrypted_result[:encrypted_data], 1920 * 1080)  


def create_video_from_images(image_pattern, output_video)
    system("ffmpeg -framerate 24 -i #{image_pattern} -c:v libx264 -pix_fmt yuv420p #{output_video}")
end
 

#create_video_from_images("chunk_%d.png", "output_video.mp4")


def extract_images_from_video(input_video)
    system("ffmpeg -i #{input_video} -vf fps=24 frame_%d.png")
end


def images_to_string(images)
    combined_string = ""
    images.each do |image_path|
        image = ChunkyPNG::Image.from_file(image_path)
        image.pixels.each do |pixel|
            combined_string << (pixel >> 16 & 0xFF).chr  # Assuming pixel values are stored in RGB format
        end
    end
    combined_string
end


def decrypt_string(encrypted_data, key, iv)
    decipher = OpenSSL::Cipher.new('AES-256-CBC')
    decipher.decrypt
    decipher.key = key
    decipher.iv = Base64.decode64(iv)
    decrypted_data = decipher.update(Base64.decode64(encrypted_data)) + decipher.final
    decrypted_data
end


