extends Node

@onready var MemUsage:Label = $MemoryUsage
@onready var fushigi_load_noah = $FushigiLoadNOAH
@onready var fushigi_load_folder = $FushigiLoadFOLDER
@onready var fushigi_load_g_2d = $FushigiLoadG2D

var chose_file:bool = false
var noah_path:String
var chose_folder:bool = false
var folder_path:String

var output_bmp:bool = false

var chose_g2d:bool = false
var g2d_files:PackedStringArray

var decomp_bmp:bool = true

const bmp_640x448x8bpp_header:PackedByteArray = [
	0x42,
	0x4D,
	0x36,
	0x64,
	0x04,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x36,
	0x04,
	0x00,
	0x00,
	0x28,
	0x00,
	0x00,
	0x00,
	0x80,
	0x02,
	0x00,
	0x00,
	0xC0,
	0x01,
	0x00,
	0x00,
	0x01,
	0x00,
	0x08,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x60,
	0x04,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x01,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00,
	0x00
]

func _process(_delta):
	var MEM = Performance.get_monitor(Performance.MEMORY_STATIC)
	var MEM2 = Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
	MemUsage.text = str(MEM * 0.000001, " MB / ", MEM2 * 0.000001, "MB")
	
	if chose_g2d and chose_folder:
		makeFiles()
		g2d_files.clear()
		chose_folder = false
		chose_g2d = false
	
func _on_load_noah_pressed():
	fushigi_load_noah.visible = true
	
func _on_fushigi_load_noah_file_selected(path):
	fushigi_load_noah.visible = false
	fushigi_load_folder.visible = true
	chose_file = true
	noah_path = path
	
func _on_fushigi_load_folder_dir_selected(dir):
	folder_path = dir
	chose_folder = true
	
func _on_decomp_bmp_button_toggled(_toggled_on):
	if decomp_bmp:
		decomp_bmp = false
	elif decomp_bmp == false:
		decomp_bmp = true
		
func _on_load_g_2d_pressed():
	fushigi_load_g_2d.visible = true
	
func _on_fushigi_load_g_2d_files_selected(paths):
	fushigi_load_g_2d.visible = false
	fushigi_load_folder.visible = true
	g2d_files = paths
	chose_g2d = true
		
func makeFiles() -> void:
	var file:FileAccess
	var new_file:FileAccess
	var loaded_array_size:int
	var file_size:int
	var file_name:String
	var pallete_data:PackedByteArray
	var unk_data:PackedByteArray
	var num_sections:int
	var mem_file:PackedByteArray
	var image:PackedByteArray
	var final_image:PackedByteArray
	var image_start:int
	var image_len:int
	var decomp_size:int
	var sections_start:int
	var i:int
	var byte:int
	var new_image:Image
	
	loaded_array_size = g2d_files.size()
	sections_start = 0x804
	i = 0
	while i < loaded_array_size:
		file = FileAccess.open(g2d_files[i], FileAccess.READ)
		file_name = g2d_files[i].get_file()
		file_size = file.get_length()
		file.seek(0)
		pallete_data = file.get_buffer(0x400) #read pallete data
		file.seek(0x400)
		unk_data = file.get_buffer(0x400) #read unknown mapping data
		#mem_file.append_array(pallete_data)
		file.seek(0x800)
		num_sections = file.get_32() #get number of sections in image
		file.seek(sections_start)
		for j in range(0, num_sections):
			file.seek((j << 2) + sections_start)
			image_start = file.get_32() + 0x800
			file.seek((j << 2) + sections_start + 4)
			image_len = file.get_32() - image_start + 0x800
			if image_len == 0:
				image_len = 0x800
			file.seek(image_start)
			decomp_size = file.get_32()
			file.seek(image_start)
			image.clear()
			image = file.get_buffer(image_len)
			image = decompressImage(image, decomp_size)
			mem_file.append_array(image)
			
		if output_bmp:
			new_file = FileAccess.open(folder_path + "/%s" % file_name + ".00%s.BMP" % num_sections, FileAccess.WRITE)
			#pallete_data.reverse()
			#mem_file.reverse()
			#i = pallete_data.size() - 4
			#var j:int = 0
			#var temp:PackedByteArray
			#temp.resize(i)
			#while i != 0:
				#byte = swap32(pallete_data.decode_u32(i))
				#temp.encode_u32(j, byte)
				#i -= 4
				#j += 4
			#i = 0
			#while i < mem_file.size():
				#byte = swap32(mem_file.decode_u32(i))
				#mem_file.encode_u32(i, byte)
				#i = (i + 1) << 2
			final_image.append_array(bmp_640x448x8bpp_header)
			final_image.append_array(pallete_data)
			final_image.append_array(mem_file)
			new_file.store_buffer(final_image)
			final_image.clear()
		new_file = FileAccess.open(folder_path + "/%s" % file_name + ".00%s.RAW" % num_sections, FileAccess.WRITE)
		new_file.store_buffer(mem_file)
		new_file = FileAccess.open(folder_path + "/%s" % file_name + ".00%s.PAL" % num_sections, FileAccess.WRITE)
		#mem_file = mem_file.slice(0x400)
		new_file.store_buffer(pallete_data)
		new_file = FileAccess.open(folder_path + "/%s" % file_name + ".00%s.UNK" % num_sections, FileAccess.WRITE)
		new_file.store_buffer(unk_data)
		new_image = Image.create_from_data(640, 448, false, Image.FORMAT_L8, mem_file)
		new_image.save_png(folder_path + "/%s" % file_name + ".00%s.PNG" % num_sections)
		#var pal_string:String = str(pallete_data)
		#print(pallete_data.get_string_from_ascii())
		#new_file = FileAccess.open(folder_path + "/%s" % file_name + ".00%s.TEST" % num_sections, FileAccess.WRITE)
		#new_file.store_line(pal_string)
		new_file.close()
		pallete_data.clear()
		unk_data.clear()
		mem_file.clear()
		file.close()
		print("0x%X " % file_size, "%s " % num_sections, "%s" % folder_path + "/%s" % file_name)
		i += 1
	
func swap32(num) -> int:
	var swapped:int
	
	swapped = ((num>>24)&0xff) | ((num<<8)&0xff0000) | ((num>>8)&0xff00) | ((num<<24)&0xff000000)
	return swapped
		
func decompressImage(file:PackedByteArray, decomp_size:int) -> PackedByteArray:
	var at:int
	var v1:int
	var a0:int #image start
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
	var s1:int
	var s2:int
	var s3:int
	var s4:int
	var s5:int
	var s6:int
	#var s7:int
	var t8:int
	var t9:int
	var temp_arrary:PackedByteArray
	var new_file:PackedByteArray
	
	t1 = 0 #temp array location, size is 0x1000
	temp_arrary.resize(0x1000)
	a1 = 0 #new file location
	t3 = 0
	a0 = 0 #image start
	t2 = decomp_size #file seek to image start, decompressed size
	new_file.resize(t2)
	v1 = 1
	s4 = 0x0FEE
	a0 += 4
	while t2 > 0:
		t3 >>= 1
		a2 = t3 & 0x0100
		if a2 == 0:
			a2 = file.decode_u8(a0)
			t3 = a2 | 0xFF00
			a0 += 1
		a2 = t3 & 0x0001
		if a2 == 0:
			t0 = file.decode_u8(a0 + 1)
			t4 = 0
			t5 = file.decode_u8(a0)
			a2 = t0 & 0x00F0
			a3 = a2 << 4
			a2 = t0 & 0x000F
			t0 = t5 | a3
			a3 = a2 + 2
			at = a3 < 0
			a0 += 2
			if at == 0:
				t5 = a3 + 1
				at = t5 < 9
				a2 = a3 - 8
				if at == 0:
					at = a3 < 0
					t5 = 0
					if at == 0:
						at = 0x7FFFFFFF
						a3 &= 0xFFFFFFFF
						at = a3 < at
						if at != 0:
							t5 = v1
					
					if t5 != 0:
						at = 0
						while at == 0:
							t5 = t0 + t4
							t6 = t5 & 0x0FFF
							t7 = s4 + 1
							t6 = t1 + t6
							s1 = t7 & 0x0FFF
							t6 = temp_arrary.decode_u8(t6)
							t7 = t4 + 1
							s0 = t0 + t7
							t5 = t1 + s4
							s0 &= 0x0FFF
							t7 = s1 + 1
							s2 = t7 & 0x0FFF
							s4 = t1 + s0
							t7 = t4 + 2
							s3 = t1 + s1
							s0 = t0 + t7
							temp_arrary.encode_s8(t5, t6)
							t7 = t1 + s2
							new_file.encode_s8(a1, t6)
							t5 = s0 & 0x0FFF
							t8 = temp_arrary.decode_u8(s4)
							s1 = t1 + t5
							t5 = s2 + 1
							s0 = t5 & 0x0FFF
							t5 = t4 + 3
							s2 = t1 + s0
							t5 = t0 + t5
							t6 = t5 & 0x0FFF
							temp_arrary.encode_s8(s3, t8)
							s4 = t4 + 4
							s3 = t0 + s4
							t5 = s0 + 1
							new_file.encode_s8(a1 + 1, t8)
							s4 = s3 & 0x0FFF
							s3 = temp_arrary.decode_u8(s1)
							t5 &= 0x0FFF
							t6 += t1
							s0 = t1 + t5
							s1 = t1 + s4
							temp_arrary.encode_s8(t7, s3)
							s4 = t5 + 1
							new_file.encode_s8(a1 + 2, s3)
							t5 = t4 + 5
							s3 = temp_arrary.decode_u8(t6)
							t5 += t0
							s4 &= 0x0FFF
							t5 &= 0x0FFF
							t8 = t1 + s4
							t9 = t1 + t5
							t5 = s4 + 1
							t5 &= 0x0FFF
							s4 = t4 + 6
							t7 = t0 + s4
							t6 = t1 + t5
							s4 = t4 + 7
							t5 += 1
							t5 &= 0x0FFF
							s4 += t0
							s5 = t1 + t5
							s4 &= 0x0FFF
							temp_arrary.encode_s8(s2, s3)
							t5 += 1
							s6 = t1 + s4
							new_file.encode_s8(a1 + 3, s3)
							s4 = t5 & 0x0FFF
							t7 &= 0x0FFF
							t5 = temp_arrary.decode_u8(s1)
							t4 += 8
							t7 += t1
							at = a2 < t4
							temp_arrary.encode_s8(s0, t5)
							new_file.encode_s8(a1 + 4, t5)
							t5 = temp_arrary.decode_u8(t9)
							temp_arrary.encode_s8(t8, t5)
							new_file.encode_s8(a1 + 5, t5)
							t5 = temp_arrary.decode_u8(t7)
							temp_arrary.encode_s8(t6, t5)
							new_file.encode_s8(a1 + 6, t5)
							t5 = temp_arrary.decode_u8(s6)
							temp_arrary.encode_s8(s5, t5)
							new_file.encode_s8(a1 + 7, t5)
							a1 += 8
				at = a3 < t4
				if at == 0:
					while at == 0:
						a2 = t0 + t4
						a2 &= 0x0FFF
						t4 += 1
						t6 = t1 + a2
						t5 = t1 + s4
						t6 = temp_arrary.decode_u8(t6)
						a2 = s4 + 1
						at = a3 < t4
						s4 = a2 & 0x0FFF
						temp_arrary.encode_s8(t5, t6)
						new_file.encode_s8(a1, t6)
						a1 += 1
				a2 = a3 + 1
				t2 = t2 - a2
				if t2 == 0:
					break
					
			else:
				a2 = a3 + 1
				t2 = t2 - a2
				if t2 == 0:
					break
		else:
			t0 = file.decode_u8(a0)
			a3 = t1 + s4
			a2 = s4 + 1
			t2 -= 1
			s4 = a2 & 0x0FFF
			temp_arrary.encode_s8(a3, t0)
			a0 += 1
			new_file.encode_s8(a1, t0)
			a1 += 1
			if t2 <= 0:
				break
		
	return new_file
