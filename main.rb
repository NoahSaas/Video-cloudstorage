require 'base64'
require 'openssl'
require 'fileutils'
require 'parallel'

class VideoDataHandler
  RESOLUTION = [1920, 1080]
  BLOCK_SIZE = 16
  BLOCKS_PER_ROW = RESOLUTION[0] / BLOCK_SIZE
  BLOCKS_PER_COL = RESOLUTION[1] / BLOCK_SIZE
  BITS_PER_IMAGE = BLOCKS_PER_ROW * BLOCKS_PER_COL

  def write_file(data, file_path)
    File.open(file_path, 'wb') { |file| file.write(data) }
  end

  def data_to_string(file_path)
    Base64.strict_encode64(File.binread(file_path))
  end

  def string_to_binary(str)
    str.unpack1('B*')
  end

  def binary_to_string(binary)
    binary.ljust((binary.length + 7) / 8 * 8, '0')
        .scan(/.{8}/).map { |byte| byte.to_i(2).chr }.join
  end

  def string_to_images(encoded_string)
    Dir.mkdir('encoded_images') unless Dir.exist?('encoded_images')
    binary_data = string_to_binary(encoded_string)

    binary_data = [binary_data.length].pack('N').unpack1('B*') + binary_data
    total_images = (binary_data.length / BITS_PER_IMAGE.to_f).ceil

    Parallel.each(0...total_images, in_threads: Parallel.processor_count) do |i|
      chunk = binary_data[i * BITS_PER_IMAGE, BITS_PER_IMAGE].ljust(BITS_PER_IMAGE, '0')
      generate_image(chunk, "encoded_images/chunk_#{i + 1}.png")
    end
  end

  def generate_image(binary_chunk, filename)
    commands = ["magick -size #{RESOLUTION[0]}x#{RESOLUTION[1]} xc:white"]

    black_rectangles = []
    white_rectangles = []

    binary_chunk.chars.each_with_index do |bit, idx|
      x1 = (idx % BLOCKS_PER_ROW) * BLOCK_SIZE
      y1 = (idx / BLOCKS_PER_ROW) * BLOCK_SIZE
      x2 = x1 + BLOCK_SIZE - 1
      y2 = y1 + BLOCK_SIZE - 1

      if bit == '1'
        black_rectangles << "rectangle #{x1},#{y1} #{x2},#{y2}"
      else
        white_rectangles << "rectangle #{x1},#{y1} #{x2},#{y2}"
      end
    end

    commands << "-fill black -draw \"#{black_rectangles.join(' ')}\"" unless black_rectangles.empty?
    commands << "-fill white -draw \"#{white_rectangles.join(' ')}\"" unless white_rectangles.empty?

    commands << filename
    system(commands.join(' '))
  end

  def images_to_string
    image_files = Dir['encoded_images/*.png'].sort_by { |f| f[/\d+/].to_i }
    binary_data = ''

    Parallel.each_with_index(image_files, in_threads: Parallel.processor_count) do |image_path, _index|
      binary_data += decode_image(image_path)
    end

    metadata = binary_data[0, 32].to_i(2)
    binary_data[32, metadata]
  end

  def decode_image(image_path)
    binary_chunk = ''
    rows = BLOCKS_PER_COL
    cols = BLOCKS_PER_ROW

    rows.times do |row|
      cols.times do |col|
        x = col * BLOCK_SIZE + BLOCK_SIZE / 2
        y = row * BLOCK_SIZE + BLOCK_SIZE / 2
        color = `magick #{image_path} -crop 1x1+#{x}+#{y} txt:-`
        binary_chunk << (color.include?('black') ? '1' : '0')
      end
    end

    binary_chunk
  end

  def create_video(output_video)
    system("ffmpeg",
           '-framerate', '1',
           '-i', 'encoded_images/chunk_%d.png',
           '-c:v', 'libx264',
           '-preset', 'ultrafast',
           '-crf', '0',
           '-pix_fmt', 'yuv420p',
           "#{output_video}.mp4")
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

# Example usage
video = VideoDataHandler.new
video.encrypt_data('data.txt')
# video.decrypt_data('encrypted_video.mp4')
