extends Node

@onready var MemUsage:Label = $MemoryUsage
@onready var box_load_bin = $BoxLoadBIN
@onready var load_folder = $LoadFOLDER
@onready var box_load_elf = $BoxLoadELF

var elf_path:String
var archive_path:String
var folder_path:String

func _process(_delta):
	var MEM = Performance.get_monitor(Performance.MEMORY_STATIC)
	var MEM2 = Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
	MemUsage.text = str(MEM * 0.000001, " MB / ", MEM2 * 0.000001, "MB")
	
	if archive_path and folder_path:
		decodeTenshou()
		archive_path = ""
		folder_path = ""
	
func _on_load_bin_pressed():
	if !elf_path:
		OS.alert("SLPM_665.66 must be loaded first.")
		return
		
	box_load_bin.visible = true
	
func _on_load_elf_pressed():
	box_load_elf.visible = true
	
func _on_box_load_elf_file_selected(path):
	box_load_elf.visible = false
	elf_path = path
	
func _on_box_load_bin_file_selected(path):
	box_load_bin.visible = false
	load_folder.visible = true
	archive_path = path
	
func _on_load_folder_dir_selected(dir):
	folder_path = dir
	
func decodeTenshou() -> void:
	var file:FileAccess
	var archive_file:FileAccess
	var archive_name:String
	var in_xor_byte:int
	const out_xor_key:int = 0x494F28EA
	var xor_key:int
	var jmp_tbl:PackedByteArray
	var tbl_xor_byte:int
	var i:int
	var header_size:int
	var off:int
	var out_file:PackedByteArray
	var out_file_size:int
	var out_file_sector_size:int
	var base_off:int
	var dir:DirAccess
	var file_name:String
	var file_name_off:int
	var new_file:FileAccess
	var name_table_off:int
	
	# load jump table from EXE
	
	file = FileAccess.open(elf_path, FileAccess.READ)
	file.seek(0xCC188)
	jmp_tbl = file.get_buffer(0x800)
	file.close()
	
	archive_file = FileAccess.open(archive_path, FileAccess.READ)
	archive_name = archive_path.get_file()
	
	# check user loaded archive name
	
	if archive_name == "OUT.BIN":		#at 0x0 * 0x800 in header.
		header_size = 0x47800
	elif archive_name == "MOVIE.BIN":
		header_size = 0x1000
	elif archive_name == "VOICE.BIN":
		header_size = 0xB2800
		
	out_file.resize(header_size)
	
	# decrypt header of archive
	
	base_off = 0
	while base_off < header_size:
		xor_key = out_xor_key
		i = 0
		while i < 0x200:
			off = i << 2
			tbl_xor_byte = jmp_tbl.decode_s32(off) << 2
			archive_file.seek(tbl_xor_byte + base_off)
			in_xor_byte = archive_file.get_32()
			out_file.encode_u32(off + base_off, in_xor_byte)
			i += 1
		i = 0x200
		off = base_off
		while i > 0:
			in_xor_byte = out_file.decode_s32(off)
			in_xor_byte = in_xor_byte ^ xor_key
			out_file.encode_u32(off, in_xor_byte)
			off += 4
			i -= 1
			xor_key += 1
		base_off += 0x800
		
	# output decrypted archive header
	dir = DirAccess.open(folder_path)
	file_name = archive_name + ".HED"
	dir.make_dir_recursive(file_name.get_base_dir())
	file = FileAccess.open(folder_path + "/%s" % file_name, FileAccess.WRITE_READ)
	print("Output folder: %s" % folder_path)
	file.store_buffer(out_file)
	out_file.clear()
	
	file.seek(0x4)
	name_table_off = file.get_32()
	
	# decrypt and save files
	
	i = 0xC						# starting of file table
	while i < name_table_off:
		file.seek(i)
		file_name_off = file.get_32() + name_table_off
		file.seek(file_name_off)
		file_name = file.get_line()
		
		file.seek(i + 0x4)
		off = file.get_32()
		
		file.seek(i + 0x8)
		out_file_size = file.get_32()
		out_file_sector_size = ((out_file_size + 0x800) / 0x800) * 0x800
		
		file.seek(i + 0xC)
		xor_key = file.get_32()
		
		archive_file.seek(off)
		out_file = archive_file.get_buffer(out_file_sector_size)
		
		out_file = decodeFileTenshou(out_file, xor_key, jmp_tbl, out_file_size, out_file_sector_size)
		
		dir.make_dir_recursive(file_name.get_base_dir())
		new_file = FileAccess.open(folder_path + "/%s" % file_name, FileAccess.WRITE)
		print("0x%X " % off, "0x%X " % out_file_size, "0x%X " % xor_key, folder_path + "/%s" % file_name)
		
		new_file.store_buffer(out_file)
		new_file.close()
		out_file.clear()
		i += 0x10
	file.close()
	archive_file.close()
	print("Finished")
	
func decodeFileTenshou(file:PackedByteArray, file_xor_key:int, jmp_tbl:PackedByteArray, size:int, sector_size:int) -> PackedByteArray:
	var new_file:PackedByteArray
	var i:int
	var off:int
	var base_off:int
	var tbl_xor_byte:int
	var in_xor_byte:int
	var xor_key:int
	
	file.resize(sector_size)
	new_file.resize(sector_size)
	base_off = 0
	while base_off < sector_size:
		xor_key = file_xor_key
		i = 0
		while i < 0x200:
			off = i << 2
			tbl_xor_byte = jmp_tbl.decode_s32(off) << 2
			in_xor_byte = file.decode_s32(tbl_xor_byte + base_off)
			new_file.encode_u32(off + base_off, in_xor_byte)
			i += 1
		i = 0x200
		off = base_off
		while i > 0:
			in_xor_byte = new_file.decode_s32(off)
			in_xor_byte = in_xor_byte ^ xor_key
			new_file.encode_u32(off, in_xor_byte)
			off += 4
			i -= 1
			xor_key += 1
		base_off += 0x800
	new_file.resize(size)			#actual file size, as sector padding has needed xor bytes but unneeded for decrypted file.
	return new_file
