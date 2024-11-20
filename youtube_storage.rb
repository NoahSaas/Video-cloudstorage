require 'parallel'
require 'base64'
require 'openssl'
require 'chunky_png'
require 'fileutils'
require 'securerandom'
require 'optparse'

class YouTubeDataStorage
  RESOLUTION = [1920, 1080]
  BLOCK_SIZE = 16
  COLOR_LEVELS = 3
  MARGIN = 32
  
  def initialize
    @cipher = OpenSSL::Cipher.new('AES-256-GCM')
    FileUtils.mkdir_p('encoded_images')
    FileUtils.mkdir_p('encryption_data')
  end

  # Main public methods for encoding and decoding
  def encode_and_encrypt_file(input_file, output_video_name)
    puts "Starting encoding process..."
    raw_data = File.binread(input_file)
    b64_data = Base64.strict_encode64(raw_data)
    
    puts "Encrypting data..."
    encrypted_data = encrypt_data(b64_data)
    
    puts "Converting to images..."
    string_to_images(encrypted_data)
    
    puts "Creating video..."
    create_video_from_images(output_video_name)
    puts "Process complete! Video saved as #{output_video_name}.mp4"
  end

  def decrypt_and_decode_file(youtube_url, output_file)
    puts "Downloading video from YouTube..."
    download_youtube_video(youtube_url)
    
    puts "Extracting images from video..."
    extract_images_from_video("downloaded_video.mp4")
    
    puts "Converting images to data..."
    encrypted_data = images_to_string
    
    puts "Decrypting data..."
    encryption_package = {
      encrypted_data: encrypted_data
    }.merge(read_encryption_data)
    
    decrypted_data = decrypt_data(encryption_package)
    raw_data = Base64.strict_decode64(decrypted_data)
    
    puts "Writing decoded file..."
    write_file(raw_data, output_file)
    puts "Process complete! File saved as #{output_file}"
  end

  private

  # Encryption methods
  def encrypt_data(data)
    @cipher.encrypt
    key = @cipher.random_key
    iv = @cipher.random_iv
    auth_data = SecureRandom.hex(16)
    
    @cipher.auth_data = auth_data
    encrypted = @cipher.update(data) + @cipher.final
    auth_tag = @cipher.auth_tag
    
    encrypted_package = {
      encrypted_data: Base64.strict_encode64(encrypted),
      iv: Base64.strict_encode64(iv),
      auth_tag: Base64.strict_encode64(auth_tag),
      auth_data: Base64.strict_encode64(auth_data)
    }
    
    write_encryption_data(encrypted_package, key)
    encrypted_package[:encrypted_data]
  end

  def decrypt_data(encrypted_package)
    begin
      decipher = OpenSSL::Cipher.new('AES-256-GCM')
      decipher.decrypt
      
      key = File.read("encryption_data/key.bin")
      decipher.key = Base64.strict_decode64(key)
      
      iv = Base64.strict_decode64(encrypted_package[:iv])
      decipher.iv = iv
      
      auth_data = Base64.strict_decode64(encrypted_package[:auth_data])
      auth_tag = Base64.strict_decode64(encrypted_package[:auth_tag])
      decipher.auth_data = auth_data
      decipher.auth_tag = auth_tag
      
      encrypted_data = Base64.strict_decode64(encrypted_package[:encrypted_data])
      decipher.update(encrypted_data) + decipher.final
    rescue OpenSSL::Cipher::CipherError => e
      raise "Decryption failed: Data may be corrupted or tampered with - #{e.message}"
    end
  end

  # Image processing methods
  def string_to_images(encoded_string)
    usable_width = RESOLUTION[0] - (2 * MARGIN)
    usable_height = RESOLUTION[1] - (2 * MARGIN)
    blocks_per_row = usable_width / BLOCK_SIZE
    blocks_per_col = usable_height / BLOCK_SIZE
    blocks_per_frame = blocks_per_row * blocks_per_col
  
    chunk_size = blocks_per_frame / 8  # 8 bits per byte
    chunks = encoded_string.scan(/.{1,#{chunk_size}}/m)
  
    # Pre-render blocks
    block_black = ChunkyPNG::Image.new(BLOCK_SIZE, BLOCK_SIZE, ChunkyPNG::Color::BLACK)
    block_white = ChunkyPNG::Image.new(BLOCK_SIZE, BLOCK_SIZE, ChunkyPNG::Color::WHITE)
  
    Parallel.each_with_index(chunks, in_threads: 8) do |chunk, frame_index|
      image = ChunkyPNG::Image.new(RESOLUTION[0], RESOLUTION[1], ChunkyPNG::Color::WHITE)
      binary_data = chunk.bytes.map { |b| b.to_s(2).rjust(8, '0') }.join
  
      binary_data.each_char.with_index do |bit, index|
        break if index >= blocks_per_frame
        row = index / blocks_per_row
        col = index % blocks_per_row
        x = (col * BLOCK_SIZE) + MARGIN
        y = (row * BLOCK_SIZE) + MARGIN
  
        image.compose!(bit == '1' ? block_black : block_white, x, y)
      end
  
      image.save("encoded_images/chunk_#{frame_index + 1}.png")
    end
  end  

  def images_to_string
    calibrate_colors
    combined_string = ""
    
    Dir["encoded_images/chunk_*.png"].sort_by { |f| f.scan(/\d+/).first.to_i }.each do |image_path|
      next if image_path.include?('calibration')
      
      image = ChunkyPNG::Image.from_file(image_path)
      blocks = extract_blocks(image)
      
      blocks.each do |block|
        avg_color = calculate_block_average(block)
        # Convert average color to binary (0 or 1)
        bit = avg_color < 128 ? '1' : '0'
        combined_string << bit
      end
      
      # Convert binary string to bytes
      combined_string = [combined_string].pack('B*')
    end
    
    combined_string.strip
  end

  def draw_calibration_pattern(image)
    # Draw large, high-contrast calibration patterns in corners
    pattern_size = BLOCK_SIZE * 2
    corners = [
      [MARGIN, MARGIN],
      [RESOLUTION[0] - MARGIN - pattern_size, MARGIN],
      [MARGIN, RESOLUTION[1] - MARGIN - pattern_size],
      [RESOLUTION[0] - MARGIN - pattern_size, RESOLUTION[1] - MARGIN - pattern_size]
    ]
    
    corners.each do |x, y|
      # Draw checker pattern
      2.times do |i|
        2.times do |j|
          color = (i + j) % 2 == 0 ? ChunkyPNG::Color::BLACK : ChunkyPNG::Color::WHITE
          BLOCK_SIZE.times do |dx|
            BLOCK_SIZE.times do |dy|
              image[x + (i * BLOCK_SIZE) + dx, y + (j * BLOCK_SIZE) + dy] = color
            end
          end
        end
      end
    end
  end

  # Video processing methods
  def create_video_from_images(output_video)
    system("ffmpeg",
           "-framerate", "1",
           "-i", "encoded_images/chunk_%d.png",
           "-c:v", "libx264",
           "-preset", "veryslow",
           "-crf", "18",           # Slightly higher quality
           "-pix_fmt", "yuv420p",
           "-movflags", "+faststart",
           "-tune", "grain",       # Better for high-contrast content
           "-x264opts", "keyint=1:min-keyint=1",
           "-vf", "pad=width=#{RESOLUTION[0]}:height=#{RESOLUTION[1]}:x=0:y=0:color=white",  # Ensure no black bars
           "#{output_video}.mp4")
  end

  def extract_images_from_video(input_video)
    system("ffmpeg -i #{input_video} -vf fps=1 encoded_images/chunk_%d.png")
    File.delete(input_video) if File.exist?(input_video)
  end

  def download_youtube_video(url)
    system("yt-dlp",
           "-f", "bestvideo[height=1080][ext=mp4]",
           "--merge-output-format", "mp4",
           "--recode-video", "mp4",
           "--format-sort", "res:1080,fps:1",
           url,
           "-o", "downloaded_video.%(ext)s")
  end

  # Helper methods
  def write_file(data, file_path)
    File.open(file_path, 'wb') { |file| file.write(data) }
  end

  def write_encryption_data(encrypted_package, key)
    write_file(Base64.strict_encode64(key), "encryption_data/key.bin")
    write_file(encrypted_package[:iv], "encryption_data/iv.bin")
    write_file(encrypted_package[:auth_tag], "encryption_data/auth_tag.bin")
    write_file(encrypted_package[:auth_data], "encryption_data/auth_data.bin")
  end

  def read_encryption_data
    {
      iv: File.read("encryption_data/iv.bin"),
      auth_tag: File.read("encryption_data/auth_tag.bin"),
      auth_data: File.read("encryption_data/auth_data.bin")
    }
  end

  def extract_blocks(image)
    blocks = []
    usable_width = RESOLUTION[0] - (2 * MARGIN)
    usable_height = RESOLUTION[1] - (2 * MARGIN)
    
    (MARGIN...MARGIN + usable_height).step(BLOCK_SIZE) do |y|
      (MARGIN...MARGIN + usable_width).step(BLOCK_SIZE) do |x|
        block = []
        (BLOCK_SIZE - 8..BLOCK_SIZE - 4).each do |dy|
          (BLOCK_SIZE - 8..BLOCK_SIZE - 4).each do |dx|
            if x + dx < RESOLUTION[0] && y + dy < RESOLUTION[1]
              block << ChunkyPNG::Color.r(image[x + dx, y + dy])
            end
          end
        end
        blocks << block unless block.empty?
      end
    end
    blocks
  end

  def calculate_block_average(block)
    block.sum / block.size
  end
end

# Command line interface
if __FILE__ == $0
  begin
    options = {}
    OptionParser.new do |opts|
      opts.banner = "Usage: youtube_storage.rb [encode|decode] [input] [output]"
      
      opts.on("-h", "--help", "Show this help message") do
        puts opts
        exit
      end
    end.parse!

    command = ARGV[0]
    input = ARGV[1]
    output = ARGV[2]

    unless command && input && output
      puts "Error: Missing required arguments"
      puts "Usage: youtube_storage.rb [encode|decode] [input] [output]"
      exit 1
    end

    storage = YouTubeDataStorage.new
    
    case command
    when "encode"
      storage.encode_and_encrypt_file(input, output)
    when "decode"
      storage.decrypt_and_decode_file(input, output)
    else
      puts "Unknown command: #{command}"
      puts "Valid commands are: encode, decode"
      exit 1
    end
  rescue => e
    puts "Error: #{e.message}"
    puts e.backtrace if ENV['DEBUG']
    exit 1
  end
end



