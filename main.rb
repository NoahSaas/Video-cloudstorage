require 'base64'
require 'chunky_png'
require 'fileutils'

class OptimizedVideoDataHandler
  RESOLUTION = [1920, 1080]  # Restore high resolution
  BLOCK_SIZE = 4  # Larger blocks to make pixels more visible
  MAX_BLOCKS_X = RESOLUTION[0] / BLOCK_SIZE
  MAX_BLOCKS_Y = RESOLUTION[1] / BLOCK_SIZE
  MAX_PIXELS = MAX_BLOCKS_X * MAX_BLOCKS_Y

  def write_file(data, file_path)
    File.open(file_path, 'wb') { |file| file.write(data) }
  end

  def data_to_binary(file_path)
    File.binread(file_path).unpack('B*')[0]
  end

  def binary_to_data(binary)
    [binary].pack('B*')
  end

  def binary_to_images(binary_data)
    Dir.mkdir('optimized_images') unless Dir.exist?('optimized_images')
    binary_data += '0' * ((24 - (binary_data.length % 24)) % 24)  # Pad to fit RGB pixels
    total_pixels = binary_data.length / 24
    total_images = (total_pixels.to_f / MAX_PIXELS).ceil

    puts "Expected number of images to be generated: #{total_images}"

    total_images.times do |i|
      image = ChunkyPNG::Image.new(RESOLUTION[0], RESOLUTION[1], ChunkyPNG::Color::WHITE)
      chunk = binary_data[i * MAX_PIXELS * 24, MAX_PIXELS * 24] || ''
      
      chunk.scan(/.{24}/).each_with_index do |pixel_bits, index|
        break if index >= MAX_PIXELS
        block_x = (index % MAX_BLOCKS_X) * BLOCK_SIZE
        block_y = (index / MAX_BLOCKS_X) * BLOCK_SIZE
        r, g, b = pixel_bits[0..7].to_i(2), pixel_bits[8..15].to_i(2), pixel_bits[16..23].to_i(2)
        color = ChunkyPNG::Color.rgb(r, g, b)
        
        BLOCK_SIZE.times do |dx|
          BLOCK_SIZE.times do |dy|
            image[block_x + dx, block_y + dy] = color if (block_x + dx) < RESOLUTION[0] && (block_y + dy) < RESOLUTION[1]
          end
        end
      end
      
      image.save("optimized_images/frame_#{i + 1}.png")
    end
  end

  def images_to_binary
    binary_data = ''
    image_files = Dir['optimized_images/*.png'].sort_by { |f| f[/\d+/].to_i }
    
    image_files.each do |image_path|
      image = ChunkyPNG::Image.from_file(image_path)
      
      (0...MAX_BLOCKS_Y).each do |by|
        (0...MAX_BLOCKS_X).each do |bx|
          sample_x = bx * BLOCK_SIZE + (BLOCK_SIZE / 2)
          sample_y = by * BLOCK_SIZE + (BLOCK_SIZE / 2)
          r, g, b = ChunkyPNG::Color.r(image[sample_x, sample_y]), ChunkyPNG::Color.g(image[sample_x, sample_y]), ChunkyPNG::Color.b(image[sample_x, sample_y])
          binary_data << r.to_s(2).rjust(8, '0')
          binary_data << g.to_s(2).rjust(8, '0')
          binary_data << b.to_s(2).rjust(8, '0')
        end
      end
    end
    binary_data
  end

  def encode_to_video(output_video)
    system("ffmpeg", "-framerate", "1", "-i", "optimized_images/frame_%d.png", "-c:v", "libx264", "-crf", "17", "-pix_fmt", "yuv420p", "#{output_video}.mp4")
    FileUtils.rm_rf('optimized_images')
  end

  def decode_from_video(input_video)
    Dir.mkdir('optimized_images') unless Dir.exist?('optimized_images')
    system("ffmpeg -i #{input_video} optimized_images/frame_%d.png")
  end

  def encrypt_data(file_path)
    binary_data = data_to_binary(file_path)
    binary_to_images(binary_data)
    encode_to_video('encrypted_video')
  end

  def decrypt_data(video_path)
    decode_from_video(video_path)
    binary_data = images_to_binary
    write_file(binary_to_data(binary_data), "decrypted_file")
  end
end

video_handler = OptimizedVideoDataHandler.new
video_handler.encrypt_data('video.mp4')
#video_handler.decrypt_data('encrypted_video.mp4')
