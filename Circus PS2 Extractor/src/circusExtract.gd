extends Node

@onready var MemUsage:Label = $MemoryUsage
@onready var circus_load_dat = $CircusLoadDAT
@onready var circus_load_folder = $CircusLoadFOLDER


var chose_folder:bool = false
var folder_path:String

var output_png:bool = true
var remove_alpha:bool = true

var chose_dat:bool = false
var dat_files:PackedStringArray

func _ready():
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)

func _process(_delta):
	var MEM = Performance.get_monitor(Performance.MEMORY_STATIC)
	var MEM2 = Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
	MemUsage.text = str(MEM * 0.000001, " MB / ", MEM2 * 0.000001, "MB")
	
	if chose_dat and chose_folder:
		makeFiles()
		dat_files.clear()
		chose_folder = false
		chose_dat = false
	
func _on_load_dat_pressed():
	circus_load_dat.visible = true
	
func _on_decomp_bmp_button_toggled(_toggled_on):
	if output_png:
		output_png = false
	elif output_png == false:
		output_png = true
		
func _on_remove_alpha_button_toggled(_toggled_on):
	if remove_alpha:
		remove_alpha = false
	elif remove_alpha == false:
		remove_alpha = true
		
func _on_circus_load_dat_files_selected(paths):
	circus_load_dat.visible = false
	circus_load_folder.visible = true
	dat_files = paths
	chose_dat = true
	
func _on_circus_load_folder_dir_selected(dir):
	folder_path = dir
	chose_folder = true
	
func makeFiles() -> void:
	var file:FileAccess
	var new_file:FileAccess
	var loaded_array_size:int
	var file_off:int
	var file_size:int
	var file_name:String
	var archive_name:String
	var num_files:int
	var mem_file:PackedByteArray
	var decomp_size:int
	var i:int
	var new_image:Image
	var width:int
	var height:int
	var entry_size:int
	var name_table_off:int
	var name_size:int
	var comp_size:int
	var mem_file_image_data:PackedByteArray
	var unk_flag:int
	var dir:DirAccess
	var k:int
	
	loaded_array_size = dat_files.size()
	dir = DirAccess.open(folder_path)
	entry_size = 0x8
	name_size = 0x40
	i = 0
	while i < loaded_array_size:
		file = FileAccess.open(dat_files[i], FileAccess.READ)
		archive_name = dat_files[i].get_file()
		file.seek(0x0)
		num_files = file.get_32()
		
		name_table_off = (num_files * entry_size) + 4
		
		for j in range(0, num_files):
			file.seek((j * name_size) + name_table_off)
			file_name = file.get_line()
			
			file.seek(((j * name_size) + name_table_off) + 0x38)
			file_off = file.get_32()
			
			file.seek(((j * name_size) + name_table_off) + 0x3C)
			file_size = file.get_32()
			
			file.seek(file_off)
			mem_file.resize(file_size)
			mem_file = file.get_buffer(file_size)
			
			if file_name.ends_with(".GRP") and output_png:
				file.seek(file_off + 4)
				width = file.get_32()
				file.seek(file_off + 8)
				height = file.get_32()
				file.seek(file_off + 0xC)
				unk_flag = file.get_32()
				file.seek(file_off + 0x10)
				comp_size = file.get_32()
				file.seek(file_off + 0x80)
				mem_file_image_data = file.get_buffer(comp_size)
				
				decomp_size = (width * height) << 2
				mem_file_image_data = decompressImage(mem_file_image_data, comp_size, decomp_size)
				
				if remove_alpha:
					k = 0
					while k < decomp_size:
						mem_file_image_data.encode_u8(k + 3, 0xFF)
						k+= 4
				
				dir.make_dir_recursive(file_name.get_base_dir())
				new_file = FileAccess.open(folder_path + "/%s" % file_name, FileAccess.WRITE)
				
				new_image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, mem_file_image_data)
				new_image.save_png(folder_path + "/%s" % file_name + ".PNG")
				
				new_file.store_buffer(mem_file)
				mem_file_image_data.clear()
				new_file.close()
				mem_file.clear()
				print("0x%X " % file_off, "0x%X " % file_size, "%s " % archive_name, "%s" % file_name)
			else:
				dir.make_dir_recursive(file_name.get_base_dir())
				new_file = FileAccess.open(folder_path + "/%s" % file_name, FileAccess.WRITE)
				new_file.store_buffer(mem_file)
				new_file.close()
				mem_file.clear()
				print("0x%X " % file_off, "0x%X " % file_size, "%s " % archive_name, "%s" % file_name)
		
		file.close()
		i += 1
	print_rich("[color=green]Finished![/color]")
	
#func swap32(num) -> int:
	#var swapped:int
	#
	#swapped = ((num>>24)&0xff) | ((num<<8)&0xff0000) | ((num>>8)&0xff00) | ((num<<24)&0xff000000)
	#return swapped
		
func decompressImage(file:PackedByteArray, comp_size:int, decomp_size:int) -> PackedByteArray:
	var v0:int
	var a0:int
	var a1:int
	var a2:int
	var t3:int
	var t4:int
	var t5:int
	var t6:int
	var t7:int
	var new_file:PackedByteArray
	var gp:int #86A0(gp)
	
	#function is lz77 based?
	#a0 = outbuffer
	#a1 = compressed data start
	#a2 = compressed buffer in header
	
	new_file.resize(decomp_size)
	gp = 0
	v0 = 0
	a0 = 0
	a1 = 0 #compressed data start
	a2 = comp_size
	t3 = 0x7F
	t6 = gp
	while a2 > 0:
		t6 >>= 1
		t7 = t6 & 0x100
		gp = t6
		if t7 == 0:
			t7 = file.decode_u8(a1)
			a2 -= 1 #daddiu a2, a2, $ffff
			t6 = t7 | 0xFF00
			a1 += 1
			gp = t6
		t7 = t6 & 1
		if t7 != 0:
			t7 = file.decode_u8(a1)
			v0 += 1
			a2 -= 1 #daddiu a2, a2, $ffff
			new_file.encode_s8(a0, t7)
			a1 += 1
			a0 += 1
			t6 = gp
			continue
			
		if a2 == 0:
			return new_file
	
		t4 = file.decode_u8(a1) #001231AC
		a2 -= 1 #daddiu a2, a2, $ffff
		t7 = t4 < 0xC0
		a1 += 1
		if t7 == 0:
			t6 = t4 & 0x3
			t5 = file.decode_u8(a1)
			t7 = t4 >> 2
			t6 <<= 8
			t4 = t7 & 0xF
			a2 -= 1 #daddiu a2, a2, $ffff
			t6 |= t5 & 0xFFFFFFFF
			a1 += 1
			t4 += 4
			t6 = a0 - t6
			v0 += t4
			while t4 != 0:
				t7 = new_file.decode_u8(t6)
				t4 -= 1
				new_file.encode_s8(a0, t7)
				t6 += 1
				a0 += 1
			if a2 == 0:
				return new_file
			else:
				t6 = gp
				continue
				
		t7 = t4 & 0x80
		if t7 != 0:
			t7 = t4 >> 5
			t6 = t4 & 0x1F
			t4 = t7 & 0x3
			if t6 == 0:
				t6 = file.decode_u8(a1)
				a2 -= 1 #daddiu a2, a2, $ffff
				a1 += 1
				t4 += 2
				#beq      zero, zero, $001231E4
				t6 = a0 - t6
				v0 += t4
				while t4 != 0:
					t7 = new_file.decode_u8(t6)
					t4 -= 1
					new_file.encode_s8(a0, t7)
					t6 += 1
					a0 += 1
				if a2 == 0:
					return new_file
				else:
					t6 = gp
					continue
			
			else:
				#bne      t6, zero, $00123234
				t4 += 2
				t6 = a0 - t6
				v0 += t4
				while t4 != 0:
					t7 = new_file.decode_u8(t6)
					t4 -= 1
					new_file.encode_s8(a0, t7)
					t6 += 1
					a0 += 1
				if a2 == 0:
					return new_file
				else:
					t6 = gp
					continue
				
		#0012323C
		t7 = t4 >> 5
		if t4 == t3:
			t4 = file.decode_u8(a1)
			a2 -= 4 #daddiu a2, a2, $fffc
			a1 += 1
			t7 = file.decode_u8(a1)
			a1 += 1
			t7 <<= 8
			t4 |= t7 & 0xFFFFFFFF
			t6 = file.decode_u8(a1)
			t4 += 2
			a1 += 1
			t7 = file.decode_u8(a1)
			t7 <<= 8
			a1 += 1
			t6 |= t7 & 0xFFFFFFFF
			#beq      zero, zero, $001231E4
			t6 = a0 - t6
			v0 += t4
			while t4 != 0:
				t7 = new_file.decode_u8(t6)
				t4 -= 1
				new_file.encode_s8(a0, t7)
				t6 += 1
				a0 += 1
			if a2 == 0:
				return new_file
			else:
				t6 = gp
				continue
				
		else:
			t6 = file.decode_u8(a1)
			a2 -= 2 #daddiu a2, a2, $fffe
			t4 += 4
			#beq      zero, zero, $00123268
			a1 += 1
			t7 = file.decode_u8(a1)
			t7 <<= 8
			a1 += 1
			t6 |= t7 & 0xFFFFFFFF
			#beq      zero, zero, $001231E4
			t6 = a0 - t6
			v0 += t4
			while t4 != 0:
				t7 = new_file.decode_u8(t6)
				t4 -= 1
				new_file.encode_s8(a0, t7)
				t6 += 1
				a0 += 1
			if a2 == 0:
				return new_file
			else:
				t6 = gp
				continue
			
	return new_file
