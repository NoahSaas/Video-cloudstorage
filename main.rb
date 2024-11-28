require 'base64'
require 'openssl'
require 'chunky_png'
require 'fileutils'

class VideoDataHandler
  RESOLUTION = [1920, 1080]

  def initialize(video_url = nil)
    @video_url = video_url
  end

  def write_file(data, file_path)
    File.open(file_path, 'wb') { |file| file.write(data) }
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

    {
      encrypted_data: Base64.strict_encode64(encrypted_data),
      iv: Base64.strict_encode64(iv),
      key: Base64.strict_encode64(key)
    }
  end

  def decrypt_string(encrypted_data, key, iv)
    decipher = OpenSSL::Cipher.new('AES-256-CBC')
    decipher.decrypt
    decipher.key = Base64.strict_decode64(key)
    decipher.iv = Base64.strict_decode64(iv)

    decoded_data = Base64.strict_decode64(encrypted_data.strip)
    decrypted_data = decipher.update(decoded_data) + decipher.final

    Base64.strict_decode64(decrypted_data)
  end

  def string_to_images(encoded_string, block_size = 4)
    # Ensure the output directory exists
    Dir.mkdir('encoded_images') unless Dir.exist?('encoded_images')
  
    # Calculate the number of characters that can be stored per image
    chars_per_image = (RESOLUTION[0] / block_size) * (RESOLUTION[1] / block_size)
  
    # Pad the string with a special delimiter to mark the end
    encoded_string += "~"  # "~" is the delimiter
  
    # Calculate the number of images needed
    total_images = (encoded_string.length.to_f / chars_per_image).ceil
  
    total_images.times do |i|
      # Get the chunk of data for this image
      chunk = encoded_string[i * chars_per_image, chars_per_image] || ''
  
      # Create a blank image
      image = ChunkyPNG::Image.new(RESOLUTION[0], RESOLUTION[1], ChunkyPNG::Color::WHITE)
  
      # Encode each character into the image
      chunk.each_char.with_index do |char, index|
        # Calculate the block position
        block_x = (index % (RESOLUTION[0] / block_size)) * block_size
        block_y = (index / (RESOLUTION[0] / block_size)) * block_size
  
        # Convert the character to its ASCII value
        color_value = char.ord
        block_color = ChunkyPNG::Color.rgb(color_value, color_value, color_value)
  
        # Fill the block with the grayscale color
        block_size.times do |dx|
          block_size.times do |dy|
            x = block_x + dx
            y = block_y + dy
            image[x, y] = block_color if x < RESOLUTION[0] && y < RESOLUTION[1]
          end
        end
      end
  
      # Save the image
      image.save("encoded_images/chunk_#{i + 1}.png")
    end
  end   

  def create_video_from_images(output_video, image_pattern = 'encoded_images/chunk_%d.png')
    system("ffmpeg",
           '-framerate', '24',
           '-i', image_pattern,
           '-c:v', 'libx264',
           '-preset', 'slow',
           '-crf', '18',
           '-pix_fmt', 'yuv420p',
           '-movflags', '+faststart',
           "#{output_video}.mp4")

    FileUtils.rm_rf('encoded_images')
  end

  def extract_images_from_video(input_video)
    Dir.mkdir('encoded_images') unless Dir.exist?('encoded_images')
    system("ffmpeg -i #{input_video} -vf fps=24 encoded_images/chunk_%d.png")
  end

  def images_to_string(block_size = 4)
    decoded_string = ''
  
    # Get the list of images in order
    image_files = Dir['encoded_images/*.png'].sort_by { |f| f[/\d+/].to_i }
  
    image_files.each_with_index do |image_path, image_index|
      # Load the image
      image = ChunkyPNG::Image.from_file(image_path)
  
      # Decode each block into characters
      (0...RESOLUTION[1]).step(block_size) do |block_y|
        (0...RESOLUTION[0]).step(block_size) do |block_x|
          # Read the color of the top-left pixel in the block
          color_value = ChunkyPNG::Color.r(image[block_x, block_y])
          char = color_value.chr
  
          # Stop decoding when the delimiter is found
          if char == "~"
            return decoded_string
          end
  
          # Append the character to the string
          decoded_string << char
        end
      end
    end
  
    decoded_string
  end  

  def encrypt_data(file_name)
    b64_string = data_to_string(file_name)

    key = OpenSSL::Cipher.new('AES-256-CBC').random_key
    encryption_result = encrypt_string(b64_string, key)

    write_file(encryption_result[:iv], 'iv.bin')
    write_file(encryption_result[:key], 'key.txt')
    write_file(encryption_result[:encrypted_data], 'encrypted_data.txt')

    file_format = File.extname(file_name)
    write_file(file_format, 'format.txt')

    string_to_images(encryption_result[:encrypted_data])

    create_video_from_images('encrypted_video')

    puts "Encryption complete. Video saved as 'encrypted_video.mp4'."
  end

  def decrypt_data(video_file)
    extract_images_from_video(video_file)

    encrypted_data = images_to_string

    key = File.read('key.txt')
    iv = File.read('iv.bin')

    original_data = decrypt_string(encrypted_data, key, iv)

    write_file(original_data, "decrypted_file#{File.read('format.txt').strip}")

    puts "Decryption complete. File saved as 'decrypted_file'."
  end


end


video = VideoDataHandler.new
#video.encrypt_data('data.txt')
#video.decrypt_data('encrypted_video.mp4')