require 'base64'
require 'openssl'
require 'chunky_png'
require 'fileutils'

class VideoDataHandler
  RESOLUTION = [1920, 1080]
  BLOCK_SIZE = 16
  COLORS = [0, 255]

  def initialize
    @chars_per_image = ((RESOLUTION[0] / BLOCK_SIZE) * (RESOLUTION[1] / BLOCK_SIZE)) / 8
  end

  def write_file(data, file_path)
    File.open(file_path, 'wb') { |file| file.write(data) }
  end

  def data_to_string(file_path)
    Base64.strict_encode64(File.binread(file_path))
  end

  def string_to_binary(str)
    str.unpack('B*')[0]
  end

  def binary_to_string(binary)
    while binary.length % 8 != 0
      binary += '0'
    end
    
    bytes = binary.scan(/.{8}/).map { |byte| byte.to_i(2).chr }
    bytes.join
  end

  def string_to_images(encoded_string)
    Dir.mkdir('encoded_images') unless Dir.exist?('encoded_images')
    binary_data = string_to_binary(encoded_string)
    binary_data += '0' until binary_data.length % @chars_per_image == 0
    
    total_images = (binary_data.length.to_f / @chars_per_image).ceil
    
    total_images.times do |i|
      chunk = binary_data[i * @chars_per_image, @chars_per_image] || ''
      image = ChunkyPNG::Image.new(RESOLUTION[0], RESOLUTION[1], ChunkyPNG::Color::WHITE)
      
      chunk.each_char.with_index do |bit, index|
        block_x = (index % (RESOLUTION[0] / BLOCK_SIZE)) * BLOCK_SIZE
        block_y = (index / (RESOLUTION[0] / BLOCK_SIZE)) * BLOCK_SIZE
        
        color = bit == '1' ? COLORS[1] : COLORS[0]
        block_color = ChunkyPNG::Color.rgb(color, color, color)
        
        BLOCK_SIZE.times do |dx|
          BLOCK_SIZE.times do |dy|
            x = block_x + dx
            y = block_y + dy
            image[x, y] = block_color if x < RESOLUTION[0] && y < RESOLUTION[1]
          end
        end
      end
      
      image.save("encoded_images/chunk_#{i + 1}.png")
    end
  end

  def images_to_string
    decoded_binary = ''
    image_files = Dir['encoded_images/*.png'].sort_by { |f| f[/\d+/].to_i }
    
    puts "\nStarting image processing..."
    
    image_files.each do |image_path|
      puts "Processing image: #{image_path}"
      image = ChunkyPNG::Image.from_file(image_path)
      
      binary_chunks = []
      puts "Image dimensions: #{image.width}x#{image.height}"
      
      (0...RESOLUTION[1]).step(BLOCK_SIZE) do |block_y|
        (0...RESOLUTION[0]).step(BLOCK_SIZE) do |block_x|
          center_x = block_x + (BLOCK_SIZE / 2)
          center_y = block_y + (BLOCK_SIZE / 2)
          
          next if center_x >= RESOLUTION[0] || center_y >= RESOLUTION[1]
          
          color_value = ChunkyPNG::Color.r(image[center_x, center_y])
          binary_chunks << (color_value > 127 ? '1' : '0')
        end
      end
      
      decoded_binary = binary_chunks.join
      puts "Binary length before conversion: #{decoded_binary.length}"
    end
    
    result = binary_to_string(decoded_binary)
    puts "String length after conversion: #{result.length}"
    
    result = result.gsub(/[^A-Za-z0-9+\/=]/, '')
    puts "Final string length after cleaning: #{result.length}"
    
    result
  end

  def create_video(output_video)
    system("ffmpeg",
           '-framerate', '1',
           '-i', 'encoded_images/chunk_%d.png',
           '-c:v', 'libx264',
           '-preset', 'veryslow',
           '-crf', '17',
           '-pix_fmt', 'yuv420p',
           '-movflags', '+faststart',
           "#{output_video}.mp4")
    
    FileUtils.rm_rf('encoded_images')
  end

  def extract_images(input_video)
    Dir.mkdir('encoded_images') unless Dir.exist?('encoded_images')
    system("ffmpeg -i #{input_video} encoded_images/chunk_%d.png")
  end

  def encrypt_data(file_path)
    cipher = OpenSSL::Cipher.new('AES-256-CBC')
    key = cipher.random_key
    iv = cipher.random_iv
    
    cipher.encrypt
    cipher.key = key
    cipher.iv = iv
    
    file_data = File.binread(file_path)
    encrypted_data = cipher.update(file_data) + cipher.final
    
    write_file(key, 'key.bin')
    write_file(iv, 'iv.bin')
    write_file(File.extname(file_path), 'format.txt')
    
    string_to_images(Base64.strict_encode64(encrypted_data))
    create_video('encrypted_video')
  end

  def decrypt_data(video_path)
    puts "Starting decryption process..."
    extract_images(video_path)
    
    key = File.binread('key.bin')
    iv = File.binread('iv.bin')
    
    decipher = OpenSSL::Cipher.new('AES-256-CBC')
    decipher.decrypt
    decipher.key = key
    decipher.iv = iv
    
    encrypted_data = Base64.strict_decode64(images_to_string)
    decrypted_data = decipher.update(encrypted_data) + decipher.final
    
    format = File.read('format.txt').strip
    write_file(decrypted_data, "decrypted_file#{format}")
  end
end

video = VideoDataHandler.new
video.encrypt_data('chinook (2).db')
#video.decrypt_data('encrypted_video.mp4')