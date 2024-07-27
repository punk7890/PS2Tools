extends Node

@onready var MemUsage:Label = $MemoryUsage
@onready var interlude_load_pak = $InterludeLoadPAK
@onready var interlude_load_folder = $InterludeLoadFOLDER

var chose_folder:bool = false
var folder_path:String

var interlude_files:PackedStringArray
var out_png:bool = true

#XOR keys for width and height of images

const width_key:int = 0x4355
const height_key:int = 0x5441

func _process(_delta):
	var MEM = Performance.get_monitor(Performance.MEMORY_STATIC)
	var MEM2 = Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
	MemUsage.text = str(MEM * 0.000001, " MB / ", MEM2 * 0.000001, "MB")
	
	if interlude_files and chose_folder:
		interludeMakeFiles()
		chose_folder = false
		interlude_files.clear()
	
func _on_fushigi_load_folder_dir_selected(dir):
	folder_path = dir
	chose_folder = true
	
func _on_load_interlude_file_pressed():
	interlude_load_pak.visible = true
	
func _on_interlude_load_pak_files_selected(paths):
	interlude_load_pak.visible = false
	interlude_load_folder.visible = true
	interlude_files = paths
	
func _on_png_out_toggle_toggled(_toggled_on):
	if out_png:
		out_png = false
	elif out_png == false:
		out_png = true
	
func interludeMakeFiles() -> void:
	var file:FileAccess
	var file_data001:FileAccess
	var file_data002:FileAccess
	var new_file:FileAccess
	var header_file:FileAccess
	var loaded_array_size:int
	var file_name:String
	var start_off:int
	var file_size:int
	var mem_file:PackedByteArray
	var mem_file_len:int
	var i:int
	var k:int
	var byte:int
	var initial_key:int
	var key_1_lower:int
	var key_1:int
	var key_2:int
	var key_3:int
	var max_size:int
	var png_out:Image
	var ogg_bytes:int
	var archive_id:String
	var png_buffer:PackedByteArray
	var width:int
	var height:int
	var unk_bytes:int
	var mem_file_off:int
	
	loaded_array_size = interlude_files.size()
	max_size = 0x3CA00
	i = 0
	while i < loaded_array_size:
		file = FileAccess.open(interlude_files[i], FileAccess.READ)
		file_name = interlude_files[i].get_file()
		if file_name == "DATA.IMG":
			file_data001 = FileAccess.open(interlude_files[i].get_basename() + ".001", FileAccess.READ)
			file_data002 = FileAccess.open(interlude_files[i].get_basename() + ".002", FileAccess.READ)
			if (file_data001 == null) or (file_data002 == null):
				OS.alert("DATA.001 and DATA.002 must be in the same directory as DATA.IMG")
				return
		
		initial_key = 0x6E86CC2E
		key_1 = initial_key
		mem_file.resize(max_size) #assume header size
		
		for j in range(0, max_size):
			file.seek(j)
			byte = file.get_8()
			key_1_lower = key_1 & 0xFF
			key_2 = (key_1 << 1) & 0xFFFFFFFF
			key_3 = (key_1 >> 31) & 0xFFFFFFFF
			key_1 = key_2 | key_3
			byte = byte + key_1_lower
			mem_file.encode_s8(j, byte)
			if j & 0x5 != 0:
				#Unsure how to determine header end
				if (file.get_32()) == 0:
					mem_file_len = file.get_position() - 4
					mem_file.resize(mem_file_len)
					break
				key_2 = key_1 << 1
				key_3 = key_1 >> 31
				key_1 = key_2 | key_3
		
		header_file = FileAccess.open(folder_path + "/%s" % file_name + ".HED", FileAccess.WRITE_READ)
		header_file.store_buffer(mem_file)
		mem_file.clear()
		
		k = 0
		while k < mem_file_len:
			header_file.seek(k)
			file_name = header_file.get_line()
			if file_name == "":
				print("Assumed header ending at 0x%X" % header_file.get_position())
				break
			header_file.seek(k + 0xC)
			start_off = header_file.get_32()
			header_file.seek(k + 0x10)
			file_size = header_file.get_32()
			
			mem_file.resize(file_size)
			
			#DATA.IMG
			if (file_size & 0xFF000000) == 0x00000000:
				archive_id = interlude_files[i]
				file_size &= 0x00FFFFFF
				file.seek(start_off)
				mem_file = file.get_buffer(file_size)
			#DATA.001
			elif (file_size & 0xFF000000) == 0x01000000:
				archive_id = "DATA.001"
				file_size &= 0x00FFFFFF
				file_data001.seek(start_off)
				mem_file = file_data001.get_buffer(file_size)
			#DATA.002
			elif (file_size & 0xFF000000) == 0x02000000:
				archive_id = "DATA.002"
				file_size &= 0x00FFFFFF
				file_data002.seek(start_off)
				mem_file = file_data002.get_buffer(file_size)
			
			if file_name.ends_with(".VTV") and out_png: #check for type 1 image formats with vorbis headers
				ogg_bytes = mem_file.decode_u32(0)
				if ogg_bytes == 0x5367674F: #OggS
					#begin checks for multiple images
					mem_file_off = 0xA8 #always start of first image
					width = mem_file.decode_u16(mem_file_off) ^ width_key
					height = mem_file.decode_u16(mem_file_off + 2) ^ height_key
					unk_bytes = mem_file.decode_u32(mem_file_off + 4)
					png_buffer = interludeDecodeImage(mem_file, width, height, unk_bytes, mem_file_off)
					
					png_out = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, png_buffer)
					png_out.save_png(folder_path + "/%s" % file_name + ".0" + ".PNG")
					png_buffer.clear()
					
					#check for second file
					if mem_file.decode_u32(0x9C) != 0:
						mem_file_off = mem_file.decode_u32(0x98) + 0xA8 #get first image ending
						width = mem_file.decode_u16(mem_file_off) ^ width_key
						height = mem_file.decode_u16(mem_file_off + 2) ^ height_key
						unk_bytes = mem_file.decode_u32(mem_file_off + 4)
						png_buffer = interludeDecodeImage(mem_file, width, height, unk_bytes, mem_file_off)
					
						png_out = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, png_buffer)
						png_out.save_png(folder_path + "/%s" % file_name + ".1" + ".PNG")
						png_buffer.clear()
						
					#check for third file
					if mem_file.decode_u32(0xA0) != 0:
						mem_file_off = (mem_file.decode_u32(0x98) + 0xA8) + mem_file.decode_u32(0x9C)
						width = mem_file.decode_u16(mem_file_off) ^ width_key
						height = mem_file.decode_u16(mem_file_off + 2) ^ height_key
						unk_bytes = mem_file.decode_u32(mem_file_off + 4)
						png_buffer = interludeDecodeImage(mem_file, width, height, unk_bytes, mem_file_off)
					
						png_out = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, png_buffer)
						png_out.save_png(folder_path + "/%s" % file_name + ".2" + ".PNG")
						png_buffer.clear()
						
					#check for forth file
					if mem_file.decode_u32(0xA4) != 0:
						mem_file_off = ((mem_file.decode_u32(0x98) + 0xA8) + mem_file.decode_u32(0x9C)) + mem_file.decode_u32(0xA0)
						width = mem_file.decode_u16(mem_file_off) ^ width_key
						height = mem_file.decode_u16(mem_file_off + 2) ^ height_key
						unk_bytes = mem_file.decode_u32(mem_file_off + 4)
						png_buffer = interludeDecodeImage(mem_file, width, height, unk_bytes, mem_file_off)
					
						png_out = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, png_buffer)
						png_out.save_png(folder_path + "/%s" % file_name + ".3" + ".PNG")
						png_buffer.clear()
						
				elif mem_file.decode_u32(0) == mem_file.size() - 0x10: #type 2 format where 0x0 is file size
					mem_file_off = 0x10
					width = mem_file.decode_u16(mem_file_off)
					height = mem_file.decode_u16(mem_file_off + 2)
					unk_bytes = mem_file.decode_u32(mem_file_off + 4)
					png_buffer = interludeDecodeImage(mem_file, width, height, unk_bytes, mem_file_off)
					
					png_out = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, png_buffer)
					png_out.save_png(folder_path + "/%s" % file_name + ".PNG")
					png_buffer.clear()
					
							
			elif file_name.ends_with(".GCD") and out_png:
				if file_name == "REGION.GCD":
					printerr("Skipping REGION.GCD as it causes the decompresser to screw up for some reason")
				else:
					mem_file_off = 0
					width = mem_file.decode_u16(0x0)
					height = mem_file.decode_u16(0x2)
					unk_bytes = mem_file.decode_u32(0x4)
					
					png_buffer = interludeDecodeImage(mem_file, width, height, unk_bytes, mem_file_off)
							
					png_out = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, png_buffer)
					png_out.save_png(folder_path + "/%s" % file_name + ".PNG")
					png_buffer.clear()
					
			elif file_name.ends_with(".AVT") and out_png: #for Sentimental Prelude
					mem_file_off = 0xA8
					width = mem_file.decode_u16(mem_file_off) ^ width_key
					height = mem_file.decode_u16(mem_file_off + 2) ^ height_key
					unk_bytes = mem_file.decode_u32(mem_file_off + 4)
					png_buffer = interludeDecodeImage(mem_file, width, height, unk_bytes, mem_file_off)
					
					png_out = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, png_buffer)
					png_out.save_png(folder_path + "/%s" % file_name + ".PNG")
					png_buffer.clear()
				
			print("0x%X " % start_off, "0x%X " % file_size, "%s " % archive_id, "%s " % file_name)
			
					
			new_file = FileAccess.open(folder_path + "/%s" % file_name, FileAccess.WRITE)
			new_file.store_buffer(mem_file)
			mem_file.clear()
			new_file.close()
			k += 0x14
			
		header_file.close()
		file.close()
		i += 1
		
func interludeDecodeImage(buffer:PackedByteArray, dimension_x:int, dimension_y:int, unk_bytes:int, off:int) -> PackedByteArray:
	var out_buffer:PackedByteArray
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
	var size:int
	var width:int
	var height:int
	var unk:int
	var start_off:int
	
	start_off = off
	
	width = dimension_x
	height = dimension_y
	unk = unk_bytes #not needed for anything?
	size = (width * height) << 2
	
	out_buffer.resize(size)
	
	a0 = start_off + 0x8 #buffer off
	a1 = 0 #out buffer offset
	a2 = size
	t3 = buffer.decode_s32(a0)
	v0 = buffer.decode_s8(a0 - 4) & 0xFF
	a3 = v0 & 0x0F
	t2 = v0 & 0x80
	v0 = 1
	t1 = a0 + 4
	v0 <<= a3
	t0 = 0xFFFF
	v1 = v0 - 1
	v0 = a0 + t3
	if t2 > 0:
		t6 = v1
	else:
		t6 = 0xFFFFFFFF
		
	if a2 <= 0:
		return out_buffer
		
	t2 = 0xFFFF0000
	t3 = 0xFFFF
	while a2 > 0:
		if t0 == t3:
			a0 = buffer.decode_s16(t1) & 0xFFFFFFFF
			t0 = a0 | t2 & 0xFFFFFFFF
			t1 += 2
		a0 = t0 & 1
		if a0 != 0:
			a0 = buffer.decode_u8(v0)
			a2 -= 1
			out_buffer.encode_s8(a1, a0)
			a1 += 1
			v0 += 1
			t0 >>= 1
			continue
		
		a0 = buffer.decode_u16(t1)
		t5 = a0 & v1
		a0 >>= a3
		t1 += 2
		if a0 == 0:
			a0 = buffer.decode_u16(t1)
			t1 += 2
		t4 = a1 - a0 & 0xFFFFFFFF
		if t5 == t6:
			a0 = buffer.decode_u8(v0)
			t5 = a0 + t6
			v0 += 1
		t5 += 3
		a0 = t5 & 1
		a2 -= t5
		if a0 != 0:
			a0 = out_buffer.decode_u8(t4)
			t5 -= 1
			out_buffer.encode_s8(a1, a0)
			t4 += 1
			a1 += 1
		t5 >>= 1
		if t5 <= 0:
			t0 >>= 1
			continue
		while t5 > 0:
			a0 = out_buffer.decode_u8(t4)
			t5 -= 1
			out_buffer.encode_s8(a1, a0)
			a0 = out_buffer.decode_u8(t4 + 1)
			out_buffer.encode_s8(a1 + 1, a0)
			t4 += 2
			a1 += 2
		t0 >>= 1
			
	#null transparent byte for png output
	if out_png:
		a0 = 0
		while a0 < size:
			out_buffer.encode_u8(a0 + 3, 0xFF)
			a0 += 4
			
	return out_buffer
