extends Node

@onready var MemUsage:Label = $MemoryUsage
@onready var load_pfw = $LoadPFW
@onready var load_folder = $LoadFOLDER
@onready var load_char_files = $LoadCHARFiles
@onready var tile_only_toggle = $Control/TileOnlyToggle


var chose_folder:bool = false
var folder_path:String
var pfw_files:PackedStringArray

var decomp_file:bool = true
var make_tga:bool = true

var width:int
var height:int

var char_files:PackedStringArray
var tile_only:bool = false

func _ready():
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	
func _process(_delta):
	var MEM = Performance.get_monitor(Performance.MEMORY_STATIC)
	var MEM2 = Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
	MemUsage.text = str(MEM * 0.000001, " MB / ", MEM2 * 0.000001, "MB")
	
	if pfw_files and chose_folder:
		tonkinMakeFiles()
		chose_folder = false
		pfw_files.clear()
		char_files.clear()
	elif char_files and chose_folder:
		charMakeFiles()
		chose_folder = false
		pfw_files.clear()
		char_files.clear()
	
func _on_load_folder_dir_selected(dir):
	folder_path = dir
	chose_folder = true
	
func _on_load_pfw_file_pressed():
	load_pfw.visible = true
	
func _on_load_pfw_files_selected(paths):
	load_pfw.visible = false
	load_folder.visible = true
	pfw_files = paths
	
func _on_load_char_files_files_selected(paths):
	load_char_files.visible = false
	load_folder.visible = true
	char_files = paths
	
func _on_make_character_image_pressed():
	load_char_files.visible = true
	
func _on_decompress_files_pressed():
	if decomp_file:
		decomp_file = false
	elif !decomp_file:
		decomp_file = true
		
func _on_tga_toggle_pressed():
	if make_tga:
		make_tga = false
	elif !make_tga:
		make_tga = true
		
func _on_tile_only_toggle_pressed():
	if tile_only:
		tile_only = false
	elif !tile_only:
		tile_only = true
	
func tonkinMakeFiles() -> void:
	var loaded_array_size:int
	var archive_id:String
	var archive_size:int
	var file:FileAccess
	var out_file:FileAccess
	var start_off:int
	var file_off:int
	var file_size:int
	var num_files:int
	var files:int
	var out_extension:String
	var mem_file:PackedByteArray
	var tga_image:PackedByteArray
	var tga_header:PackedByteArray
	var final_image:PackedByteArray
	var swap:PackedByteArray
	
	loaded_array_size = pfw_files.size()
	files = 0
	while files < loaded_array_size:
		file = FileAccess.open(pfw_files[files], FileAccess.READ)
		file.seek(0)
		if file.get_32() != 0x33574650:
			OS.alert("%s isn't a valid PFW3 archive!" % pfw_files[files])
			if file:
				file.close()
			files += 1
			continue
			
		archive_id = pfw_files[files].get_file()
		if archive_id == "AQBACK.PFW" or archive_id == "DABACK.PFW" or archive_id == "DACHR.PFW":
			out_extension = ".TM2"
		elif archive_id == "AQPCM.PFW" or archive_id == "DAPCM.PFW": #DAPCM contains some raw PCM tracks, look at this later
			out_extension = ".ADPCM"
		elif archive_id == "AQMVP.PFW":
			out_extension = ".PSS"
		else:
			out_extension = ".BIN"
			
		file.seek(6)
		num_files = file.get_32()
		file.seek(0xC)
		archive_size = file.get_32() * 0x800
		
		start_off = 0x10
		for j in range(0, num_files):
			file.seek((j << 3) + start_off)
			file_size = file.get_32()
			file.seek(((j << 3) + start_off) + 4)
			file_off = file.get_32() * 0x800
			
			file.seek(file_off)
			mem_file = file.get_buffer(file_size)
			
			if decomp_file and archive_id != "AQPCM.PFW" and archive_id != "AQMVP.PFW" and archive_id != "AQBGM.PFW" and archive_id != "DAADP.PFW"  and archive_id != "DAMVP.PFW" and archive_id != "DAPCM.PFW" and archive_id != "DABGM.PFW":
				mem_file = decompressImage(mem_file, file_size)
				if make_tga:
					if archive_id == "AQCHAR.PFW":
						getImageDimensions(mem_file)
						var image_type:int = 2
						var has_palette:bool = false
						var bits_per_color:int = 32
						var bpp:int = 32
						var bit_depth:int = 8
						tga_header = makeTGAHeader(has_palette, image_type, bits_per_color, bpp)
						final_image.append_array(tga_header)
						tga_header.clear()
						tga_image = makeCharacterImage(mem_file, false)
						
						swap.resize(4)
						# swap BGR to RGB and leave alpha channel
						for k in range(0, tga_image.size(), 4):
							swap[0] = tga_image.decode_u8(k)
							swap[1] = tga_image.decode_u8(k + 1)
							swap[2] = tga_image.decode_u8(k + 2)
							tga_image.encode_u8(k, swap[2])
							tga_image.encode_u8(k + 1, swap[1])
							tga_image.encode_u8(k + 2, swap[0])
						swap.clear()
						
						final_image.append_array(tga_image)
						tga_image.clear()
						out_file = FileAccess.open(folder_path + "/%s" % j + ".TGA", FileAccess.WRITE)
						out_file.store_buffer(final_image)
						out_file.close()
						final_image.clear()
					elif archive_id == "AQDATA.PFW": #check for greyscale images
						if j in range(4, 19): # 4 to 19 are greyscale headerless images
							width = 640
							height = 448
							var image_type:int = 3
							var has_palette:bool = false
							var bits_per_color:int = 32
							var bpp:int = 8
							var bit_depth:int = 8
							tga_header = makeTGAHeader(has_palette, image_type, bits_per_color, bpp)
							final_image.append_array(tga_header)
							final_image.append_array(mem_file)
							
							out_file = FileAccess.open(folder_path + "/%s" % j + ".TGA", FileAccess.WRITE)
							out_file.store_buffer(final_image)
							out_file.close()
							final_image.clear()
				
			out_file = FileAccess.open(folder_path + "/%s" % j + "%s" % out_extension, FileAccess.WRITE)
			out_file.store_buffer(mem_file)
			out_file.close()
			mem_file.clear()
			
			print("0x%X " % file_off, "0x%X " % file_size, "%s " % archive_id, "%s " % j)
		file.close()
		files += 1
	print_rich("[color=green]Finished![/color]")
	return
	
func charMakeFiles() -> void:
	var loaded_array_size:int
	var file_name:String
	var file_size:int
	var archive_id:String
	var archive_size:int
	var file:FileAccess
	var out_file:FileAccess
	var files:int
	var out_extension:String
	var mem_file:PackedByteArray
	var tga_image:PackedByteArray
	var tga_header:PackedByteArray
	var final_image:PackedByteArray
	var swap:PackedByteArray
	
	loaded_array_size = char_files.size()
	files = 0
	while files < loaded_array_size:
		file = FileAccess.open(char_files[files], FileAccess.READ)
		file_size = file.get_length()
		file_name = char_files[files].get_file()
		
		file.seek(0)
		mem_file = file.get_buffer(file_size)
		file.close()
		
		var image_type:int = 2
		var has_palette:bool = false
		var bits_per_color:int = 32
		var bpp:int = 32
		var bit_depth:int = 8
		if !tile_only:
			getImageDimensions(mem_file)
			tga_image = makeCharacterImage(mem_file, false)
		else:
			tga_image = makeCharacterImage(mem_file, true)
		
		tga_header = makeTGAHeader(has_palette, image_type, bits_per_color, bpp)
		final_image.append_array(tga_header)
		tga_header.clear()
		swap.resize(4)
		# swap BGR to RGB and leave alpha channel
		for i in range(0, tga_image.size(), 4):
			swap[0] = tga_image.decode_u8(i)
			swap[1] = tga_image.decode_u8(i + 1)
			swap[2] = tga_image.decode_u8(i + 2)
			tga_image.encode_u8(i, swap[2])
			tga_image.encode_u8(i + 1, swap[1])
			tga_image.encode_u8(i + 2, swap[0])
		swap.clear()
		
		final_image.append_array(tga_image)
		tga_image.clear()
		out_file = FileAccess.open(folder_path + "/%s" % file_name + ".TGA", FileAccess.WRITE)
		out_file.store_buffer(final_image)
		out_file.close()
		
		print("%s " % width, "%s " % height, "0x%X " % final_image.size(), "%s" % file_name, ".TGA")
		final_image.clear()
		
		files += 1
		
	print_rich("[color=green]Finished![/color]")
	return
func decompressImage(buffer:PackedByteArray, comp_size:int) -> PackedByteArray:
	var at:int
	var v0:int
	var v1:int
	var a0:int
	var a1:int
	var a2:int
	var a3:int
	var t0:int 
	var t1:int
	var t2:int
	var t3:int
	var t4:int
	var t5:int
	var t6:int
	var t7:int
	var s0:int
	var t8:int
	var t9:int
	var temp_arrary:PackedByteArray
	var out_buffer:PackedByteArray
	
	#s0 = temp_array location?
	t1 = 0 #temp array location
	t9 = 0
	#t9 / a0 = buffer
	a1 = 0
	a2 = comp_size #comp size?
	a3 = 0 #temp_array loc
	s0 = 0 #out buffer loc
	t6 = 0
	temp_arrary.resize(0x1000) #v1 location?
	t7 = 0x3EE
	t8 = 1
	t0 = buffer.decode_u8(0)
	v1 = t0 << 5
	v0 = t0 >> 3
	v0 = v0 | v1
	t0 = v0 & 0xFF
	if a2 == 0:
		return buffer
		
	while true:
		t5 = t0 | 0xFF00
		t3 = t8 #buffer offset
		t1 = t8 + 1
		v0 = t5 & 1
		a0 = t8
		while true:
			if v0 != 0: #loop from #0016BF48 bne      v0, zero, $0016BE38
				t0 = buffer.decode_u8(t3)
				a0 = a0 < a2
				t8 = t1
				v1 = t0 << 5
				v0 = t0 >> 3
				v0 = v0 | v1
				t0 = v0 & 0xFF
				if a0 != 0:
					v0 = a1
					v1 = a3 + t7
					out_buffer.append(t0)
					#out_buffer.encode_s8(v0, t0)
					t7 += 1
					t3 = t9 + t1
					temp_arrary.encode_s8(v1, t0)
					t5 >>= 1
					a1 += 1
					t7 &= 0x3FF
					t1 += 1
					#beq      zero, zero, $0016BF44
					v0 = t5 & 0x100
					if v0 != 0:
						v0 = t5 & 1
						continue
					v0 = t5 & 1
					if t3 >= comp_size:
						return out_buffer
					t0 = buffer.decode_u8(t3)
					a0 = t8
					t8 = t1
					a0 = a0 < a2
					v1 = t0 << 5
					v0 = t0 >> 3
					v0 = v0 | v1
					t0 = v0 & 0xFF
					if a0 != 0:
						break
					return out_buffer
					
				else:
					return out_buffer
			
			#0016BE8C
			if t3 >= comp_size:
				return out_buffer
				
			t6 = buffer.decode_u8(t3)
			a0 = t8 < a2
			v1 = t6 << 5
			v0 = t6 >> 3
			v0 = v0 | v1
			t6 = v0 & 0xFF
			if a0 !=0:
				v0 = t9 + t1
				t8 = t1 + 1
				t2 = buffer.decode_u8(v0)
				a0 = t1 < a2
				v1 = t2 << 5
				v0 = t2 >> 3
				v1 = v0 | v1
				if a0 !=0:
					v0 = v1 & 0xF
					t4 = 0
					v1 &= 0xF0
					t2 = v0 + 2
					v1 <<= 4
					v0 = t2 < 0
					t6 = t6 | v1
					if v0 == 0:
						t5 >>= 1
						t3 = t9 + t8
						t1 += 2
						
						v0 = 0
						while v0 == 0:
							v0 = t6 + t4
							v1 = s0 + a1
							v0 &= 0x3FF
							a0 = a3 + t7
							v0 = a3 + v0
							t7 += 1
							t0 = temp_arrary.decode_u8(v0)
							t4 += 1
							a1 += 1
							t7 &= 0x3FF
							out_buffer.append(t0)
							#out_buffer.encode_s8(v1, t0)
							v0 = t2 < t4
							temp_arrary.encode_s8(a0, t0)
							
						if t3 >= comp_size:
							return out_buffer
						v0 = t5 & 0x100
						if v0 != 0:
							v0 = t5 & 1
							continue
						v0 = t5 & 1
						t0 = buffer.decode_u8(t3)
						a0 = t8
						t8 = t1
						a0 = a0 < a2
						v1 = t0 << 5
						v0 = t0 >> 3
						v0 = v0 | v1
						t0 = v0 & 0xFF
						if a0 != 0:
							break
						
						return out_buffer
						
					#0016BF38
					t5 >>= 1
					t3 = t9 + t8
					if t3 >= comp_size:
						return out_buffer
					t1 += 2
					v0 = t5 & 0x100
					if v0 != 0:
						v0 = t5 & 1
						continue
					v0 = t5 & 1
					t0 = buffer.decode_u8(t3)
					a0 = t8
					t8 = t1
					a0 = a0 < a2
					v1 = t0 << 5
					v0 = t0 >> 3
					v0 = v0 | v1
					t0 = v0 & 0xFF
					if a0 != 0:
						break
					return out_buffer
					
				else:
					return out_buffer
			else:
				return out_buffer
		
	return out_buffer
	
func makeCharacterImage(data:PackedByteArray, generate_tiles:bool) -> PackedByteArray:
	var tw:int = data[4]
	var th:int = data[5]
	var offmap:int = bytes_to_int(data.slice(6, 10))
	var nbtw:int = bytes_to_int(data.slice(10, 12))
	var nbth:int = bytes_to_int(data.slice(12, 14))
	var offtile:int = bytes_to_int(data.slice(14, 18))
	var fw:int = bytes_to_int(data.slice(18, 20))
	var sizetile:int = fw * bytes_to_int(data.slice(20, 22))
	var offpal:int = bytes_to_int(data.slice(22, 26))
	var nbpal:int = bytes_to_int(data.slice(26, 28))
	var tpl:int = fw / tw
	var BPP:int = 4
	var pal = PackedByteArray(data.slice(offpal, offpal + nbpal * 4))
	
	# Original function by Irdkwia. Converted from Python.
	var iminfo = PackedByteArray()
	
	if !generate_tiles:
		for n in range(0, pal.size(), 4):
			pal[n + 3] = min(pal[n + 3] * 2, 255)

		iminfo.resize(tw * nbtw * th * nbth * BPP)
		for y in range(nbth):
			for x in range(nbtw):
				var v:int = bytes_to_int(data.slice(offmap + (y * nbtw + x) * 2, offmap + (y * nbtw + x) * 2 + 2))
				for j in range(th):
					for i in range(tw):
						var c:int = (y * th + j) * tw * nbtw + x * tw + i
						var d:int = ((v / tpl) * th + j) * fw + (v % tpl) * tw + i
						var e:int = data[offtile + d]
						e = (e & 0xE7) | ((e & 0x10) >> 1) | ((e & 0x08) << 1)
						for b in range(BPP):
							iminfo[c * BPP + b] = pal[e * BPP + b]
		width = tw * nbtw
		height = th * nbth
		return iminfo
		
	#tile generate only
	else:
		iminfo.resize(sizetile * 4)
		for i in range(sizetile):
			var e = data[offtile + i]
			e = (e & 0xE7) | ((e & 0x10) >> 1) | ((e & 0x08) << 1)
			for b in range(BPP):
				iminfo[i * BPP + b] = pal[e * BPP + b]
		width = fw
		height = sizetile / fw
		return iminfo
	
func getImageDimensions(data:PackedByteArray) -> void:
	var tw:int = data[4]
	var th:int = data[5]
	var nbtw:int = bytes_to_int(data.slice(10, 12))
	var nbth:int = bytes_to_int(data.slice(12, 14))
	
	width = tw * nbtw
	height = th * nbth
	return
	
func bytes_to_int(bytes:PackedByteArray):
	var result:int = 0
	for i in range(bytes.size()):
		result |= bytes[i] << (i * 8)
	return result
	
func makeTGAHeader(has_palette:bool, image_type:int, bits_per_color:int, bpp:int) -> PackedByteArray:
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

