extends Node

@onready var MemUsage:Label = $MemoryUsage
@onready var load_bin: FileDialog = $LoadBIN
@onready var load_folder: FileDialog = $LoadFOLDER
@onready var load_exe: FileDialog = $LoadExe


var chose_folder:bool = false
var folder_path:String

var bin_files:PackedStringArray
var elf_file:String

var decomp_file:bool = true
var make_tga:bool = true
var debug_output:bool = false

var offset:int #used for image output in processImg

func _ready():
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	
func _process(_delta):
	var MEM = Performance.get_monitor(Performance.MEMORY_STATIC)
	var MEM2 = Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
	MemUsage.text = str(MEM * 0.000001, " MB / ", MEM2 * 0.000001, "MB")
	
	if bin_files and chose_folder:
		hunexMakeFiles()
		chose_folder = false
		bin_files.clear()
	
func _on_load_folder_dir_selected(dir):
	folder_path = dir
	chose_folder = true
	
func _on_load_cd_bin_file_pressed():
	if elf_file == "":
		OS.alert("EXE must be selected first.")
		return
		
	load_bin.visible = true
	
func _on_load_exe_pressed() -> void:
	load_exe.visible = true
	
func _on_load_bin_files_selected(paths):
	load_bin.visible = false
	load_folder.visible = true
	bin_files = paths
	
func _on_load_exe_file_selected(path: String) -> void:
	elf_file = path
	
func _on_decompress_files_pressed():
	decomp_file = !decomp_file
		
func _on_convert_tga_pressed() -> void:
	make_tga = !make_tga
	
func _on_debug_output_pressed() -> void:
	debug_output = !debug_output

func hunexMakeFiles() -> void:
	var loaded_array_size:int
	var file:FileAccess
	var file_hed:FileAccess
	var out_file:FileAccess
	var mem_file:PackedByteArray
	var mem_new_file:PackedByteArray
	var final_image:PackedByteArray
	var start_off:int
	var file_off:int
	var file_size:int
	var files:int
	var test_name:int
	var file_extension:String
	var elf_name:String
	var i:int
	var png:Image
	
	elf_name = elf_file.get_file()
	loaded_array_size = bin_files.size()
	
	files = 0
	while files < loaded_array_size:
		file_hed = FileAccess.open(elf_file, FileAccess.READ)
		if file_hed == null:
			OS.alert("Can't load elf!")
			break
			
		match elf_name:
			#Tsuki wa Higashi ni Hi wa Nishi ni - Operation Sanctuary
			"SLPM_657.17":
				file = FileAccess.open(bin_files[files], FileAccess.READ)
				
				start_off = 0x4A780
				file_hed.seek(start_off)
				while !start_off == 0x76188:
					file_off = file_hed.get_32() * 0x800
					start_off += 4
					
					file_hed.seek(start_off)
					file_size = file_hed.get_32()
					file_size = (((file_size + 0x7FF) & 0xFFFFF800) + 0x3FF) & 0xFFFFFC00
					
					file.seek(file_off)
					mem_file = file.get_buffer(file_size)
					test_name = mem_file.decode_u32(0)
					if test_name == 0x6E696231: #lbin
						file_extension = ".scr"
						if decomp_file:
							mem_file = gplDataSgi(mem_file)
							
							out_file = FileAccess.open(folder_path + "/%s" % files + "%s" % file_extension, FileAccess.WRITE)
							out_file.store_buffer(mem_file)
							out_file.close()
						else:
							out_file = FileAccess.open(folder_path + "/%s" % files + "%s" % file_extension, FileAccess.WRITE)
							out_file.store_buffer(mem_file)
							out_file.close()
						
					elif test_name == 0x78657431: #ltex
						file_extension = ".ltex"
						if decomp_file:
							mem_new_file = gplDataSgi(mem_file)
							if debug_output:
								out_file = FileAccess.open(folder_path + "/%s" % files + "%s" % file_extension, FileAccess.WRITE)
								out_file.store_buffer(mem_new_file)
								out_file.close()
								
							mem_file.clear()
							
							var image_type:int = 1
							var has_palette:bool = true
							var bits_per_color:int = 32
							var bpp:int = 8
							var width:int = mem_new_file.decode_u16(2)
							var height:int = mem_new_file.decode_u16(4)
							var tga_header:PackedByteArray = makeTGAHeader(has_palette, image_type, bits_per_color, bpp, width, height)
							
							final_image.append_array(tga_header)
							tga_header.clear()
							
							var image:PackedByteArray = mem_new_file.slice(mem_new_file.size() - 0x410, - 0x10) #pallete first
							image = unswizzle_palette(image)
							
							var swap:PackedByteArray
							swap.resize(4)
							# swap BGR to RGB and leave alpha channel
							for k in range(0, image.size(), 4):
								swap[0] = image.decode_u8(k)
								swap[1] = image.decode_u8(k + 1)
								swap[2] = image.decode_u8(k + 2)
								image.encode_u8(k, swap[2])
								image.encode_u8(k + 1, swap[1])
								image.encode_u8(k + 2, swap[0])
							swap.clear()
							
							final_image.append_array(image)
							image.clear()
							
							image = mem_new_file.slice(0x20, mem_new_file.size() - 0x430) #image data
							final_image.append_array(image)
							image.clear()
							
							out_file = FileAccess.open(folder_path + "/%s" % files + "%s" % file_extension + ".TGA", FileAccess.WRITE)
							out_file.store_buffer(final_image)
							out_file.close()
							final_image.clear()
							mem_new_file.clear()
						else:
							out_file = FileAccess.open(folder_path + "/%s" % files + "%s" % file_extension, FileAccess.WRITE)
							out_file.store_buffer(mem_file)
							out_file.close()
					else:
						if files in range(34, 19797):
							file_extension = ".adpcm"
						elif files in range(22289, 22332):
							file_extension = ".adpcm"
						elif files in range(22333, 22336):
							file_extension = ".pss"
						else:
							file_extension = ".bin"
							
						out_file = FileAccess.open(folder_path + "/%s" % files + "%s" % file_extension, FileAccess.WRITE)
						out_file.store_buffer(mem_file)
						out_file.close()
						mem_file.clear()
						
					files += 1
					start_off += 4
					print("0x%X " % file_off, "0x%X " % file_size, "%s" % files, "%s" % file_extension)
					
			#Princess Holiday - Korogaru Ringo Tei Sen'ya Ichiya
			"SLPM_655.85":
				file = FileAccess.open(bin_files[files], FileAccess.READ)
				
				start_off = 0x51A00
				file_hed.seek(start_off)
				while !start_off == 0x65DC8:
					file_off = file_hed.get_32() * 0x800
					start_off += 4
					
					file_hed.seek(start_off)
					file_size = file_hed.get_32()
					file_size = (((file_size + 0x7FF) & 0xFFFFF800) + 0x3FF) & 0xFFFFFC00
					
					file.seek(file_off)
					mem_file = file.get_buffer(file_size)
					test_name = mem_file.decode_u32(0)
					if test_name == 0x6E696231: #lbin
						file_extension = ".scr"
						if decomp_file:
							mem_file = gplDataSgi(mem_file)
							
							out_file = FileAccess.open(folder_path + "/%s" % files + "%s" % file_extension, FileAccess.WRITE)
							out_file.store_buffer(mem_file)
							out_file.close()
						else:
							out_file = FileAccess.open(folder_path + "/%s" % files + "%s" % file_extension, FileAccess.WRITE)
							out_file.store_buffer(mem_file)
							out_file.close()
						
					elif test_name == 0x78657431: #ltex
						file_extension = ".ltex"
						if decomp_file:
							mem_new_file = gplDataSgi(mem_file)
							if debug_output:
								out_file = FileAccess.open(folder_path + "/%s" % files + "%s" % file_extension, FileAccess.WRITE)
								out_file.store_buffer(mem_new_file)
								out_file.close()
								
								files += 1
								start_off += 4
								print("0x%X " % file_off, "0x%X " % file_size, "%s" % files, "%s" % file_extension)
								continue
								
							mem_file.clear()
							
							offset = 0
							i = 0
							while offset < mem_new_file.size():
								if mem_new_file.decode_u16(offset) == 0:
									break
								png = processImg(mem_new_file)
								png.save_png(folder_path + "/%s" % files + "%s" % file_extension + "_" + str(i) + ".png")
								i += 1
							i = 0
							offset = 0
						else:
							out_file = FileAccess.open(folder_path + "/%s" % files + "%s" % file_extension, FileAccess.WRITE)
							out_file.store_buffer(mem_file)
							out_file.close()
					else:
						if files in range(1190, 10361):
							file_extension = ".adpcm"
						elif files == 8:
							file_extension = ".scr"
						elif files in range(0, 4):
							file_extension = ".pss"
						elif files == 4 or files in range(1147, 1187):
							file_extension = ".ltex"
							
							offset = 0
							i = 0
							while offset < mem_file.size():
								if mem_file.decode_u16(offset) == 0:
									break
								png = processImg(mem_file)
								png.save_png(folder_path + "/%s" % files + "%s" % file_extension + "_" + str(i) + ".png")
								i += 1
							i = 0
							offset = 0
						else:
							file_extension = ".bin"
							
						out_file = FileAccess.open(folder_path + "/%s" % files + "%s" % file_extension, FileAccess.WRITE)
						out_file.store_buffer(mem_file)
						out_file.close()
						mem_file.clear()
						
					files += 1
					start_off += 4
					print("0x%X " % file_off, "0x%X " % file_size, "%s" % files, "%s" % file_extension)
					
		file.close()
		file_hed.close()
	print_rich("[color=green]Finished![/color]")
		
func gplDataSgi(input_data: PackedByteArray) -> PackedByteArray:
	var a0:int = 8  # Starting offset
	var a1:int = 0  # Out buffer offset
	var t0:int
	var t1:int
	var t2:int
	var output_data:PackedByteArray
	var v0:int
	
	#gplDataSgiSize
	v0 = input_data.decode_u8(4)
	t0 = input_data.decode_u8(5)
	t1 = input_data.decode_u8(6)
	t2 = input_data.decode_u8(7)
	v0 <<= 24
	t0 <<= 16
	t1 <<= 8
	v0 |= t0
	v0 |= t1
	v0 |= t2
	output_data.resize(v0)
	
	t1 = 2
	v0 = input_data.decode_s8(a0)
	while a0 < input_data.size():
		a0 += 1
		if a0 > input_data.size():
			break
		var v1:int = input_data.decode_s8(a0)
		if v0 > 0:
			while v0 != 0:
				a0 += 1
				output_data.encode_s8(a1, v1)
				a1 += 1
				v0 -= 1
				v1 = input_data.decode_s8(a0)
			
			v0 = input_data.decode_s8(a0)
			
		else:
			if v0 == 0:
				break
			
			var a2:int = input_data.decode_u8(a0)
			a0 += 1
			v0 = t1 - v0
			a2 = a1 - a2
			a2 -= 1
			while v0 != 0:
				v1 = output_data.decode_s8(a2)
				a2 += 1
				output_data.encode_s8(a1, v1)
				v0 -= 1
				a1 += 1
			v0 = input_data.decode_s8(a0)
			
	return output_data
	
func processImg(data:PackedByteArray) -> Image:
	# Original function by Irdkwia from Python script
	var image:PackedByteArray
	
	assert(data.decode_u16(offset) == 0x3254)
	var w:int = data.decode_u16(offset + 2)
	var h:int = data.decode_u16(offset + 4)
	var bpp:int = data.decode_u16(offset + 6)
	var imgdat:PackedByteArray = data.slice(offset + 0x20, offset + 0x20 + (w * h * bpp / 8))
	imgdat = tobpp(imgdat, bpp)
	offset += 0x20+w*h*bpp/8
	
	assert(data.decode_u16(offset) == 0x3254)
	
	var c:int = 4*data.decode_u16(offset + 2)*data.decode_u16(offset + 4)
	var paldat:PackedByteArray = data.slice(offset + 0x20, offset + 0x20 + (w * h * bpp / 8))
	
	for x in range(0, len(paldat), 4):
		paldat[x+3] = min(255, paldat[x+3]*2)
		
	offset += 0x20+c
	var resdata:PackedByteArray
	for y in range(h):
		for x in range(w):
			var index:int = imgdat[y * w + x] * 4
			var end_index:int = index + 4
			resdata.append_array(paldat.slice(index, end_index))
	#image.append_array(imgdat)
	#image.append_array(paldat)
	#image.append_array(resdata)
	var png:Image = Image.create_from_data(w, h, false, 5, resdata)
	#png.save_png("C:/Users/punk_/Desktop/test/1159.png")
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
	header.encode_u8(0x11, 0x28)
	
	return header
	
func unswizzle_palette(palBuffer: PackedByteArray) -> PackedByteArray:
	var newPal:PackedByteArray
	var pos:int
	
	# Initialize a new ByteArray with size 1024
	newPal.resize(1024)
	
	# Loop through each of the 256 palette entries
	for p in range(256):
		# Calculate the new position in the palette array
		pos = ((p & 231) + ((p & 8) << 1) + ((p & 16) >> 1))
		
		# Copy the data from palBuffer to newPal at the calculated position
		for i in range(4):
			newPal[pos * 4 + i] = palBuffer[p * 4 + i]
	
	return newPal
