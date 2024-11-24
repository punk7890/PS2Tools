extends Node

func convert_rgba_5551_to_rgba8(image_data: PackedByteArray, palette_data: PackedByteArray, image_width: int, image_height: int) -> Image:
	var pixel_count: int = image_width * image_height

	# Extract the pixel data and palette
	var pixel_data: PackedByteArray = image_data  # 16 bits per pixel

	# Parse palette
	var palette: PackedColorArray
	for i in range(0, palette_data.size(), 2):
		var color: int = palette_data.decode_u16(i)
		var r: int = ((color >> 11) & 0x1F) * 255 / 31
		var g: int = ((color >> 6) & 0x1F) * 255 / 31
		var b: int = ((color >> 1) & 0x1F) * 255 / 31
		var a: int = (color & 0x1) * 255
		palette.append(Color(r / 255.0, g / 255.0, b / 255.0, a / 255.0))

	# Create the image and set pixels
	var img: Image = Image.create(image_width, image_height, false, Image.FORMAT_RGBA8)

	for y in range(image_height):
		for x in range(image_width):
			var pixel_index: int = (y * image_width + x) * 2
			var color_index: int = pixel_data.decode_u16(pixel_index)
			if color_index < 0 or color_index >= palette.size():
				color_index = 0  # Default to the first color if out of bounds
			img.set_pixel(x, y, palette[color_index])
			
	return img
	
func expand_palette_to_1024(palette_data: PackedByteArray) -> Array:
	var expanded_palette: PackedByteArray
	var palette_size: int = palette_data.size() / 2  # Each color is 16 bits (2 bytes)
	
	for i in range(palette_size):
		 # Read current color
		var color1: int = palette_data.decode_u16(i * 2)
		expanded_palette.append(color1 >> 8)  # Append high byte
		expanded_palette.append(color1 & 0xFF)  # Append low byte
		
		# Get the next color, wrapping to the start if at the end
		var next_index = (i + 1) % palette_size
		var color2 = palette_data.decode_u16(next_index * 2)

		# Interpolate each component in RGBA-5551 format
		var r = ((color1 >> 11) & 0x1F + (color2 >> 11) & 0x1F) / 2
		var g = ((color1 >> 6) & 0x1F + (color2 >> 6) & 0x1F) / 2
		var b = ((color1 >> 1) & 0x1F + (color2 >> 1) & 0x1F) / 2
		var a = ((color1 & 0x1) + (color2 & 0x1)) / 2

		 # Recombine to RGBA-5551 format
		var interpolated_color = (r << 11) | (g << 6) | (b << 1) | a
		expanded_palette.append(interpolated_color >> 8)  # Append high byte
		expanded_palette.append(interpolated_color & 0xFF)  # Append low byte

	return expanded_palette
	
func create_tiled_image(image_data: PackedByteArray, final_width: int, final_height: int, tile_size: int) -> Image:
	# Calculate the number of tiles along width and height
	var tiles_x:int = final_width / tile_size
	var tiles_y:int = final_height / tile_size
	
	# Expected bytes per tile for RGB8 format
	var tile_data_size:int = tile_size * tile_size * 3  # 3 bytes per pixel for RGB8 format
	
	# Create the final image with the specified width and height
	var final_image:Image = Image.create_empty(final_width, final_height, false, Image.FORMAT_RGB8)
	
	# Loop through each tile and place it in the final image
	for y in range(tiles_y):
		for x in range(tiles_x):
			# Calculate the offset in the data for the current tile
			var tile_index:int = (y * tiles_x + x) * tile_data_size
				
			# Ensure we don't exceed the length of the data
			if tile_index + tile_data_size > image_data.size():
				push_error("Data size is smaller than expected for the given tile dimensions.")
				return final_image
				
			var tile_data:PackedByteArray = image_data.slice(tile_index, tile_index + tile_data_size)
			
			# Create an image for the tile and populate it with the raw data
			var tile_image:Image = Image.create_from_data(tile_size, tile_size, false, Image.FORMAT_RGB8, tile_data)
			#tile_image.save_png("F:/Games/Notes/Pia Round Summer/NBG/o/test.png")
			# Copy the tile into the correct position in the final image
			for ty in range(tile_size):
				for tx in range(tile_size):
					if tx < tile_image.get_width() and ty < tile_image.get_height():
						var color:Color = tile_image.get_pixel(tx, ty)
						final_image.set_pixel(x * tile_size + tx, y * tile_size + ty, color)
			
	
	return final_image

func combine_images_horizontally(images: Array[Image]) -> Image:
	# Ensure there is at least one image to combine
	if images.is_empty():
		return null

	# Calculate the final width by summing up all image widths, and get the max height
	var total_width: int = 0
	var max_height: int = 0
	for img in images:
		total_width += img.get_width()
		max_height = max(max_height, img.get_height())

	# Create a new Image with the calculated width and max height
	var combined_image: Image = Image.create_empty(total_width, max_height, false, images[0].get_format())

	# Place each image side by side
	var x_offset: int = 0
	for img in images:
		for y in range(img.get_height()):
			for x in range(img.get_width()):
				combined_image.set_pixel(x + x_offset, y, img.get_pixel(x, y))
		x_offset += img.get_width()

	return combined_image
	
func combine_images_vertically(images: Array[Image]) -> Image:
	# Ensure there is at least one image to combine
	if images.is_empty():
		return null

	# Calculate the final height by summing up all image heights, and get the max width
	var max_width: int = 0
	var total_height: int = 0
	for img in images:
		max_width = max(max_width, img.get_width())
		total_height += img.get_height()

	# Create a new Image with the calculated max width and total height
	var combined_image: Image = Image.create_empty(max_width, total_height, false, images[0].get_format())

	# Place each image one below the other
	var y_offset: int = 0
	for img in images:
		for y in range(img.get_height()):
			for x in range(img.get_width()):
				combined_image.set_pixel(x, y + y_offset, img.get_pixel(x, y))
		y_offset += img.get_height()

	return combined_image
	
func combine_data_horizontally_rgba8(images: Array[PackedByteArray], width: int, height: int) -> PackedByteArray:
	# RGBA8 only
	# Ensure there is at least one image to combine
	if images.is_empty():
		return PackedByteArray()
	
	# Calculate the final width by summing up all image widths
	var total_width: int = width * images.size()
	var combined_data: PackedByteArray 
	combined_data.resize(total_width * height * 4)  # Assuming 4 bytes per pixel (RGBA)

	# Place each image side by side in the combined PackedByteArray
	var x_offset: int = 0
	for img_data in images:
		for y in range(height):
			for x in range(width):
				var src_index: int = (y * width + x) * 4
				var dest_index: int = (y * total_width + x + x_offset) * 4
				
				# Copy pixel data (RGBA - 4 bytes per pixel)
				for i in range(4):
					combined_data[dest_index + i] = img_data[src_index + i]
		
		x_offset += width

	return combined_data
	
func convert_greyscale_4bit_to_rgb8(image_data: PackedByteArray) -> PackedByteArray:
	var output: PackedByteArray = PackedByteArray()
	var palette_data_size: int = 0x20  # 32 bytes for 16 4-bit palette entries

	# Extract palette data (assumed to be at the end of image_data)
	var palette: Array = []
	for i in range(palette_data_size):
		var grey_value: int = image_data[image_data.size() - palette_data_size + i] & 0x0F  # 4 bits for grayscale
		var rgb_value: Color = Color8(grey_value * 17, grey_value * 17, grey_value * 17)  # scale 0-15 to 0-255
		palette.append(rgb_value)

	# Process each 4-bit pixel
	for i in range((image_data.size() - palette_data_size) * 2):  # each byte has two 4-bit pixels
		var byte: int = image_data[i >> 1]  # get the byte containing two pixels
		var pixel_index: int = (byte >> 4) if (i % 2) == 0 else (byte & 0x0F)  # upper or lower nibble
		var color: Color = palette[pixel_index]
		
		# Append RGB8 color to output
		output.append(color.r8)
		output.append(color.g8)
		output.append(color.b8)

	return output

#func combine_greyscale_data_horizontally(images_data: PackedByteArray, width: int, height: int, num_images: int) -> PackedByteArray:
	## Calculate the final width for the combined image and resize the combined data array
	#var total_width: int = width * num_images
	#var combined_data: PackedByteArray = PackedByteArray()
	#combined_data.resize(total_width * height)  # 1 byte per pixel for grayscale
#
	## Loop through each image within images_data
	#for img_index in range(num_images):
		## Horizontal offset for the current image in the combined data
		#var x_offset: int = img_index * width
		#
		#for y in range(height):
			#for x in range(width):
				## Calculate source index based on the current image's position within images_data
				#var src_index: int = img_index * width * height + y * width + x
				## Calculate destination index in the combined array, considering the x_offset
				#var dest_index: int = y * total_width + (x + x_offset)
				#
				## Copy pixel data (1 byte per pixel for grayscale)
				#if src_index < images_data.size() and dest_index < combined_data.size():
					#combined_data[dest_index] = images_data[src_index]
				#else:
					#push_error("Out of bounds at src_index: %d, dest_index: %d" % [src_index, dest_index])
					#return PackedByteArray()
#
	#return combined_data
	
func combine_greyscale_data_vertically_arr(images_data: PackedByteArray, widths: Array[int], heights: Array[int]) -> PackedByteArray:
	var num_images = widths.size()
	var total_width: int = 0
	var total_height: int = 0

	# Calculate total width as the maximum width and total height as the sum of all heights
	for i in range(num_images):
		total_width = max(total_width, widths[i])
		total_height += heights[i]

	# Initialize the combined data array to the exact required size
	var combined_data: PackedByteArray = PackedByteArray()
	combined_data.resize(total_width * total_height)  # 1 byte per pixel for grayscale

	# Offset to place each image at the correct position in combined_data
	var y_offset: int = 0

	for img_index in range(num_images):
		var width = widths[img_index]
		var height = heights[img_index]

		for y in range(height):
			for x in range(width):
				# Calculate source index based on the current image's position within images_data
				var src_index: int = (img_index * width * height) + (y * width) + x
				# Calculate destination index in the combined array, considering the y_offset
				var dest_index: int = (y + y_offset) * total_width + x

				# Copy pixel data (1 byte per pixel for grayscale)
				if src_index < images_data.size() and dest_index < combined_data.size():
					combined_data[dest_index] = images_data[src_index]
				else:
					push_error("Out of bounds at src_index: %d, dest_index: %d" % [src_index, dest_index])
					return PackedByteArray()

		# Update y_offset for the next image
		y_offset += height

	return combined_data
	
func combine_greyscale_data_horizontally_arr(images_data: PackedByteArray, widths: Array[int], heights: Array[int]) -> PackedByteArray:
	var num_images = widths.size()
	var total_width: int = 0
	var max_height: int = 0

	# Calculate total width and maximum height
	for i in range(num_images):
		total_width += widths[i]
		max_height = max(max_height, heights[i])

	# Initialize the combined data array
	var combined_data: PackedByteArray = PackedByteArray()
	combined_data.resize(total_width * max_height)  # 1 byte per pixel for grayscale

	# Offset to place each image at the correct position in combined_data
	var x_offset: int = 0

	for img_index in range(num_images):
		var width = widths[img_index]
		var height = heights[img_index]

		for y in range(height):
			for x in range(width):
				# Calculate source index based on the current image's position within images_data
				var src_index: int = (img_index * width * height) + (y * width) + x
				# Calculate destination index in the combined array, considering the x_offset
				var dest_index: int = y * total_width + (x + x_offset)

				# Copy pixel data (1 byte per pixel for grayscale)
				if src_index < images_data.size() and dest_index < combined_data.size():
					combined_data[dest_index] = images_data[src_index]
				else:
					push_error("Out of bounds at src_index: %d, dest_index: %d" % [src_index, dest_index])
					return PackedByteArray()

		# Update x_offset for the next image
		x_offset += width

	return combined_data

	
func decompLZSS(buffer:PackedByteArray, zsize:int, size:int) -> PackedByteArray:
	var dec:PackedByteArray
	var dict:PackedByteArray
	var in_off:int = 0
	var out_off:int = 0
	var dic_off:int = 0xFEE
	var mask:int = 0
	var cb:int
	var b1:int
	var b2:int
	var len:int
	var loc:int
	var byte:int
	
	dict.resize(0x1000)
	dec.resize(size)
	while out_off < size:
		if mask == 0:
			cb = buffer[in_off]
			in_off += 1
			mask = 1

		if (mask & cb):
			dec[out_off] = buffer[in_off]
			dict[dic_off] = buffer[in_off]

			out_off += 1
			in_off += 1
			dic_off = (dic_off + 1) & 0xfff
		else:
			b1 = buffer[in_off]
			b2 = buffer[in_off + 1]
			len = (b2 & 0x0f) + 3
			loc = b1| ((b2 & 0xf0) << 4)

			for b in range(len):
				byte = dict[(loc+b) & 0xfff]
				if out_off+b >= size:
					return dec
				dec[out_off+b] = byte
				dict[(dic_off + b) & 0xfff] = byte
			dic_off = (dic_off + len) & 0xfff
			in_off += 2
			out_off += len
			
		mask = (mask << 1) & 0xFF

	return dec

func swap32(num) -> int:
	var swapped:int
	
	swapped = ((num>>24)&0xff) | ((num<<8)&0xff0000) | ((num>>8)&0xff00) | ((num<<24)&0xff000000)
	return swapped
	
func processImg(data:PackedByteArray, imgdat_off:int, w:int, h:int, bpp:int, pal_pos:int) -> Image:
	# Original function by Irdkwia from Python script
	
	var imgdat:PackedByteArray = data.slice(imgdat_off, pal_pos)
	imgdat = tobpp(imgdat, bpp)
	
	var paldat:PackedByteArray = data.slice(pal_pos)
	
	for x in range(0, len(paldat), 4):
		paldat[x+3] = min(255, paldat[x+3]*2)
		
	var resdata:PackedByteArray
	for y in range(h):
		for x in range(w):
			var index:int = imgdat[y * w + x] * 4
			var end_index:int = index + 4
			resdata.append_array(paldat.slice(index, end_index))
			
	var png:Image = Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, resdata)
	
	return png
	
func tobpp(data:PackedByteArray, bpp:int) -> PackedByteArray:
	# Original function by Irdkwia from Python script
	
	var out:PackedByteArray
	var p:int
	
	if bpp not in [1, 2, 4, 8]:
		push_error("Unsupported BPP %s " % bpp)
		
	var m:int = (1<<bpp)-1
	for b in data:
		for x in range(8/bpp):
			if bpp==8:
				var swizzle:int = b&m
				p = (swizzle&0xE7)|((swizzle&0x10)>>1)|((swizzle&0x8)<<1)
			else:
				p = b&m
			out.append(p)
			b>>=bpp
			
	return out
	
func unswizzle_palette(palBuffer: PackedByteArray, bpp: int) -> PackedByteArray:
	var newPal:PackedByteArray
	var pos:int
		
	match bpp:
		32:
			# Initialize a new ByteArray with size 1024
			newPal.resize(1024)
			
			# Loop through each of the 256 palette entries
			for p in range(256):
				# Calculate the new position in the palette array
				pos = ((p & 231) + ((p & 8) << 1) + ((p & 16) >> 1))
				
				# Copy the data from palBuffer to newPal at the calculated position
				for i in range(4):
					newPal[pos * 4 + i] = palBuffer[p * 4 + i]
		16:
			# Initialize a new ByteArray with size 512
			newPal.resize(512)
			
			# Loop through each of the 256 palette entries
			for p in range(256):
				# Calculate the new position in the palette array
				pos = ((p & 231) + ((p & 8) << 1) + ((p & 16) >> 1))
				
				# Copy the data from palBuffer to newPal at the calculated position
				for i in range(2):
					newPal[pos * 2 + i] = palBuffer[p * 2 + i]
					
		4:
			# Initialize a new ByteArray with size 32
			newPal.resize(32)
			
			var i:int = 0
			
			# Loop through each of the 256 palette entries
			for p in range(256):
				# Calculate the new position in the palette array
				pos = ((p & 231) + ((p & 8) << 1) + ((p & 16) >> 1))
				
				# Copy the data from palBuffer to newPal at the calculated position
				while i < palBuffer.size():
					newPal[pos + i] = palBuffer[p + i]
					i += 1
	
	return newPal
	
func convert_palette16_bgr_to_rgb(pal_data: PackedByteArray) -> PackedByteArray:
	var new_pal: PackedByteArray
	new_pal.resize(pal_data.size())
	
	for j in range(0, pal_data.size(), 2):
		# Decode 16-bit BGR value
		var bgr: int = pal_data.decode_u16(j)
		
		# Extract BGR components (assuming 5-5-5 RGB format)
		var blue: int = (bgr & 0x1F)         # Last 5 bits for blue
		var green: int = (bgr >> 5) & 0x1F   # Middle 5 bits for green
		var red: int = (bgr >> 10) & 0x1F    # Top 5 bits for red
		
		# Rearrange to RGB order and re-encode
		var rgb: int = (red) | (green << 5) | (blue << 10)
		new_pal.encode_u16(j, rgb)
	
	return new_pal
	
func makeTGAHeader(has_palette:bool, image_type:int, bits_per_color:int, bpp:int, width:int, height:int) -> PackedByteArray:
	var header:PackedByteArray
	var num_palette_entries:int = 1
	
	header.resize(0x12)
	
	if has_palette:
		header.encode_u8(1, 1)
		header.encode_u8(6, num_palette_entries)
	
	header.encode_u8(2, image_type)
	header.encode_u8(7, bits_per_color)
	header.encode_u16(0xC, width)
	header.encode_u16(0xE, height)
	header.encode_u8(0x10, bpp)
	header.encode_u8(0x11, 0x28) #figure out later
	
	return header
	
func apply_palette_to_image(image_data: PackedByteArray, width: int, height: int, palette_data: PackedByteArray) -> Image:
	var image: Image = Image.create_empty(width, height, false, Image.FORMAT_RGB8)

	# Read palette from the end of the file
	var palette: PackedColorArray
	for i in range(0, palette_data.size(), 3):
	#for i in range(palette_start, palette_start + palette_size, 3): # assuming 3 bytes per palette entry (RGB)
		var r: int = image_data.decode_u8(i)
		var g: int = image_data.decode_u8(i + 1)
		var b: int = image_data.decode_u8(i + 2)
		palette.append(Color(r / 255.0, g / 255.0, b / 255.0))

	# Fill the image with colors from the palette
	var data_pos: int = 0
	for y in range(height):
		for x in range(width):
			var color_index: int = image_data[data_pos]  # Get index from the image data
			if color_index < palette.size():
				var color: Color = palette[color_index]
				image.set_pixel(x, y, color)
			data_pos += 1
			
	return image
	
func convert_rgb_to_bgr(input: PackedByteArray) -> PackedByteArray:
	var output = PackedByteArray()
	
	# Assuming 16-bit color is packed as 5 bits red, 6 bits green, 5 bits blue
	for i in range(input.size() / 2):
		var color16 = input[i * 2] | (input[i * 2 + 1] << 8)
		
		# Extract RGB components from 16-bit color
		var red = (color16 >> 11) & 0x1F
		var green = (color16 >> 5) & 0x3F
		var blue = color16 & 0x1F
		
		# Convert to BGR (keeping the same bit distribution)
		var bgr16 = (blue << 11) | (green << 5) | red
		
		# Append to output as bytes
		output.append(bgr16 & 0xFF)     # Low byte
		output.append((bgr16 >> 8) & 0xFF) # High byte
	
	return output
	
func convert_rgb565_to_rgb555(input: PackedByteArray) -> PackedByteArray:
	var output = PackedByteArray()
	
	# Iterate over input data assuming each color is packed in 2 bytes (16 bits)
	for i in range(input.size() / 2):
		# Read the 16-bit RGB565 value from input
		var color16 = input[i * 2] | (input[i * 2 + 1] << 8)
		
		# Extract RGB components from RGB565
		var red = (color16 >> 11) & 0x1F
		var green = (color16 >> 5) & 0x3F
		var blue = color16 & 0x1F
		
		# Convert RGB components to RGB555 format (5 bits per component)
		var red555 = red
		var green555 = green >> 1  # RGB565 green has 6 bits, RGB555 green has 5 bits
		var blue555 = blue
		
		# Pack RGB555 into 16 bits (no alpha channel used here)
		var color555 = (red555 << 10) | (green555 << 5) | blue555
		
		# Append to output as bytes
		output.append(color555 & 0xFF)     # Low byte
		output.append((color555 >> 8) & 0xFF) # High byte
	
	return output
	
func rgb555_to_rgb24(rgb555_data: PackedByteArray) -> PackedByteArray:
	var rgb24_data = PackedByteArray()
	var num_pixels = rgb555_data.size() # Number of 16-bit pixels
	
	for i in range(num_pixels):
		# Extract the 16-bit pixel value
		var pixel = rgb555_data[i]
		
		# Extract RGB555 components
		var red_555 = (pixel >> 11) & 0x1F
		var green_555 = (pixel >> 6) & 0x1F
		var blue_555 = pixel & 0x1F
		
		# Convert 5-bit components to 8-bit components
		var red_24 = int((red_555 * 255) / 31)
		var green_24 = int((green_555 * 255) / 31)
		var blue_24 = int((blue_555 * 255) / 31)
		
		# Append the 24-bit RGB values to the new data array
		rgb24_data.append(red_24)
		rgb24_data.append(green_24)
		rgb24_data.append(blue_24)
	
	return rgb24_data
	
func rgb555_to_rgba32(rgb555_data: PackedByteArray) -> PackedByteArray:
	var rgba32_data = PackedByteArray()
	var num_pixels = rgb555_data.size() # Number of 16-bit pixels
	
	for i in range(num_pixels):
		# Extract the 16-bit pixel value
		var pixel = rgb555_data[i]
		
		# Extract RGB555 components
		var red_555 = (pixel >> 11) & 0x1F
		var green_555 = (pixel >> 6) & 0x1F
		var blue_555 = pixel & 0x1F
		
		# Convert 5-bit components to 8-bit components
		var red_32 = int((red_555 * 255) / 31)
		var green_32 = int((green_555 * 255) / 31)
		var blue_32 = int((blue_555 * 255) / 31)
		var alpha_32 = 255  # Full opacity
		
		# Append the 32-bit RGBA values to the new data array
		rgba32_data.append(red_32)
		rgba32_data.append(green_32)
		rgba32_data.append(blue_32)
		rgba32_data.append(alpha_32)
	
	return rgba32_data

func rgb565_to_bgr565(rgb565_data: PackedByteArray) -> PackedByteArray:
	var bgr565_data = PackedByteArray()
	var num_pixels = rgb565_data.size() # Number of 16-bit pixels

	for i in range(num_pixels):
		# Extract the 16-bit pixel value
		var pixel = rgb565_data[i]
		
		# Extract RGB565 components
		var red = (pixel >> 11) & 0x1F
		var green = (pixel >> 5) & 0x3F
		var blue = pixel & 0x1F
		
		# Reconstruct the 16-bit BGR565 pixel value
		var bgr565_pixel = (blue << 11) | (green << 5) | red
		
		# Append the 16-bit BGR565 value to the new data array
		bgr565_data.append(bgr565_pixel)
	
	return bgr565_data

func rgb_to_bgr(rgb_data: PackedByteArray) -> PackedByteArray:
	var bgr_data = PackedByteArray()
	var num_pixels = rgb_data.size() # Number of bytes in the input data

	# Each pixel has 3 bytes (RGB), so we iterate over the data in steps of 3
	for i in range(0, num_pixels, 3):
		# Extract RGB components
		var red = rgb_data[i]
		var green = rgb_data[i + 1]
		var blue = rgb_data[i + 2]
		
		# Append BGR components to the new array
		bgr_data.append(blue)
		bgr_data.append(green)
		bgr_data.append(red)
	
	return bgr_data
	
func rgba_to_bgra(rgba_data: PackedByteArray) -> PackedByteArray:
	var bgra_data = PackedByteArray()
	var num_pixels = rgba_data.size() # Number of bytes in the input data

	# Each pixel has 4 bytes (RGBA), so we iterate over the data in steps of 4
	for i in range(0, num_pixels, 4):
		# Extract RGBA components
		var red = rgba_data[i]
		var green = rgba_data[i + 1]
		var blue = rgba_data[i + 2]
		var alpha = rgba_data[i + 3]
		
		# Append BGRA components to the new array
		bgra_data.append(blue)
		bgra_data.append(green)
		bgra_data.append(red)
		bgra_data.append(alpha)
	
	return bgra_data

func colorBGRAToRGBA(image_data:PackedByteArray, has_alpha:bool) -> PackedByteArray:
	var r:int
	var g:int
	var b:int
	var four_bytes:PackedByteArray
	var new_image_data:PackedByteArray
	var i:int
	
	match has_alpha:
		true:
			i = 0
			four_bytes.resize(4)
			while i < image_data.size():
				four_bytes.encode_u32(0, image_data.decode_u32(i))
				image_data.encode_u8(i, four_bytes[2]) #r
				image_data.encode_u8(i + 1, four_bytes[1]) #g
				image_data.encode_u8(i + 2, four_bytes[0]) #b
				i += 4
				
			return image_data
		false: #test
			i = 0
			four_bytes.resize(4)
			while i < image_data.size():
				four_bytes.encode_u32(0, image_data.decode_u32(i))
				image_data.encode_u8(i, four_bytes[2]) #r
				image_data.encode_u8(i + 1, four_bytes[1]) #g
				image_data.encode_u8(i + 2, four_bytes[0]) #b
				image_data.encode_u8(i + 3, four_bytes[3]) #a
				i += 4
				
			return image_data
			#i = 0
			#two_bytes.resize(2)
			#while i < image_data.size():
				#two_bytes.encode_u16(0, image_data.decode_u16(i))
				#image_data.encode_u8(i + 1, two_bytes[0]) #r
				#image_data.encode_u8(i, two_bytes[1]) #b
				#i += 2
	return image_data
	
func swapNumber(num:int, bit_swap:String) -> int:
	var swapped:int
	
	if bit_swap == "32":
		swapped = ((num>>24)&0xff) | ((num<<8)&0xff0000) | ((num>>8)&0xff00) | ((num<<24)&0xff000000)
		return swapped
	elif bit_swap == "32k":
		swapped =  ((num >> 24) & 0xFF) | ((num >> 8) & 0xFF00) | ((num << 8) & 0xFF0000) | ((num << 24) & 0xFF000000)
	elif bit_swap == "24":
		swapped = ((num>>16)&0xFF) | (num&0xFF00) | ((num<<16)&0xFF0000)
		return swapped
	elif bit_swap == "24k": #keep lowest bit
		swapped = ((num >> 16) & 0xFF) | (num & 0x00FF00) | ((num & 0xFF) << 16)
		return swapped
	elif bit_swap == "16":
		swapped = ((num>>8)&0xFF) | ((num<<8)&0xFF00)
		return swapped
	return num
