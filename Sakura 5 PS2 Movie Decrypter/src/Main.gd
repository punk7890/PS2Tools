extends Node

@onready var MemUsage:Label = $MemoryUsage
@onready var WriteLoad = $FileDialogWriteLoad
@onready var WriteSave = $FileDialogWriteSave
@onready var LoadMovie = $FileDialogLoadMovie
@onready var SaveMovie = $FileDialogSaveMovie
@onready var Error = $Error

var loaded_file:PackedByteArray
var loaded_file_len:int
var loaded_movie:PackedByteArray
var loaded_movie_len:int

func _process(_delta):
	var MEM = Performance.get_monitor(Performance.MEMORY_STATIC)
	var MEM2 = Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
	MemUsage.text = str(MEM, " / ", MEM2)

func _on_writetest_pressed():
	WriteLoad.visible = true
	
func _on_movies_pressed():
	if loaded_file_len == 0:
		print("PRIMES.TBL not loaded!")
		Error.visible = true
		return
	LoadMovie.visible = true

func _on_file_dialog_write_load_file_selected(path):
	var temp_file:FileAccess = FileAccess.open(path, FileAccess.READ)
	var length:int = temp_file.get_length()
	
	loaded_file = temp_file.get_buffer(length)
	loaded_file_len = length
	print("File size 0x%X" % loaded_file_len)
	temp_file.close()
	WriteLoad.visible = false
	WriteSave.visible = true

func _on_file_dialog_write_save_file_selected(path):
	var keystring:String = "hantosikurai"
	var keystring_hex:PackedByteArray = keystring.to_utf8_buffer()
	var keystring_len:int = keystring.length()
	var decoded_loc:PackedByteArray
	var decoded_key:int
	var decoded_loc_offset:int
	var stack_keys:PackedByteArray
	var magic_table:PackedByteArray = loaded_file
	#if no keystring, assume keys from these offsets. In function 0x003A9070(jp) was an old unused password routine with "CRI-MW" as the keystring
	var magic_table_key1_s16:int = magic_table.decode_s16(0x200)
	var magic_table_key2_s16:int = magic_table.decode_s16(0x400)
	var magic_table_key3_s16:int = magic_table.decode_s16(0x600)
	
	var num_passes:int = 0x20
	
	var key1:int = get_keys_from_string(magic_table_key1_s16, keystring_len, keystring_hex, magic_table)
	var key2:int = get_keys_from_string(magic_table_key2_s16, keystring_len, keystring_hex, magic_table)
	var key3:int = get_keys_from_string(magic_table_key3_s16, keystring_len, keystring_hex, magic_table)
	
	decoded_loc.resize(0x86)
	decoded_loc.encode_s16(0x0, key1)
	decoded_loc.encode_s16(0x2, key2)
	decoded_loc.encode_s16(0x4, key3)
	stack_keys.resize(0x6)
	stack_keys.encode_s16(0x0, key1)
	stack_keys.encode_s16(0x2, key2)
	stack_keys.encode_s16(0x4, key3)
	
	
	decoded_loc_offset = 0x6
	decoded_key = key1
	for i in range(0, num_passes):
		decoded_loc.encode_s16(decoded_loc_offset, decoded_key)
		decoded_loc_offset += 0x2
		decoded_key = make_keys(stack_keys)
		stack_keys.encode_s16(0x0, decoded_key)
		decoded_loc.encode_s16(0, decoded_key)
		
	decoded_loc_offset = 0x46
	for i in range(0, num_passes):
		decoded_loc.encode_s16(decoded_loc_offset, decoded_key)
		decoded_loc_offset += 0x2
		decoded_key = make_keys(stack_keys)
		stack_keys.encode_s16(0x0, decoded_key)
		decoded_loc.encode_s16(0, decoded_key)
		
	print("Current decoded table is: 0x%s" % decoded_loc.hex_encode())
	loaded_file = decoded_loc.duplicate()
	var save_file:FileAccess = FileAccess.open(path, FileAccess.WRITE)
	save_file.store_buffer(decoded_loc)
	decoded_loc.clear()
	stack_keys.clear()
	
func _on_file_dialog_load_movie_file_selected(path):
	var temp_file:FileAccess = FileAccess.open(path, FileAccess.READ)
	var length:int = temp_file.get_length()
	
	loaded_movie = temp_file.get_buffer(length)
	loaded_movie_len = length
	print("File size 0x%X" % loaded_movie_len)
	temp_file.close()
	LoadMovie.visible = false
	SaveMovie.visible = true

func _on_file_dialog_save_movie_file_selected(path):
	var byte_flag:bool
	var movie_offset:int
	var file_size_sectors:int
	
	print("Decrypting movie...")
	movie_offset = 0
	file_size_sectors = loaded_movie_len / 0x800
	for i in range(0, file_size_sectors):
		decrypt_movie(loaded_movie, loaded_file, movie_offset)
		byte_flag = byte_check(loaded_movie, movie_offset)
		if byte_flag == false:
			decrypt_movie_header(loaded_movie, loaded_file, movie_offset)
			movie_offset += 0x800
		else:
			movie_offset += 0x800
	
	var save_file:FileAccess = FileAccess.open(path, FileAccess.WRITE)
	save_file.store_buffer(loaded_movie)
	loaded_movie.clear()
	loaded_movie_len = 0
	print("Finished")
	
func byte_check(loaded_movie:PackedByteArray, movie_offset:int) -> bool:
	var byte:int
	
	byte = loaded_movie.decode_u8(movie_offset + 0)
	if byte != 0:
		return false
	byte = loaded_movie.decode_u8(movie_offset + 1)
	if byte != 0:
		return false
	byte = loaded_movie.decode_u8(movie_offset + 2)
	if byte != 1:
		return false
	byte = loaded_movie.decode_u8(movie_offset + 3)
	byte += 0x47
	byte &= 0xFF
	if byte < 2:
		return true
	else:
		return false
	
func decrypt_movie_header(movie_loc:PackedByteArray, keys_loc:PackedByteArray, movie_offset:int):
	var temp_key1:int
	var temp_key2:int
	var temp_key3:int
	var v0:int
	var v1:int
	var a0:int
	var a1:int
	var a2:int
	var a3:int #i?
	
	a3 = 0
	v1 = 0
	for i in range(0, 0x400):
		a1 = a3 + 0x10
		a0 = a3 + 0x2F
		v1 = 0
		#if a1 == 0: #slti     v1, a1, $0000 (v1 always 0)
		#	v1 = 0
		#if a1 == 0:
		#	v1 = 1
		v0 = a1
		#if v1 != 0: #movn     v0, a0, v1 (v1 always 0)
		#	v0 = a0
		a0 = 0
		#if a3 == 0: #slti     a0, a3, $0000 (a0 always 0)
		#	a0 = 0
		#if a3 == 0:
		#	a0 = 1
		a2 = a3 + 0x1F
		v1 = a3
		v0 = v0 >> 5
		#if a0 != 0: #movn     v1, a2, a0 (a0 always 0)
		#	v1 = a2
		v0 = v0 << 5
		v1 = v1 >> 5
		v0 = a1 - v0
		v1 = v1 << 1
		v0 = v0 << 1
		temp_key1 = keys_loc.decode_u16((v1 + 0x40) + 6) #addu     v1, v1, t1, lhu      a1, $0040(v1)
		temp_key2 = keys_loc.decode_u16((v0 + 0x40) + 6) #addu     v0, v0, t1, lhu      a0, $0040(v0)
		temp_key3 = movie_loc.decode_u16(movie_offset)
		a3 += 1
		temp_key1 = temp_key2 ^ temp_key1
		temp_key3 = temp_key3 ^ temp_key1
		movie_loc.encode_s16(movie_offset, temp_key3)
		movie_offset += 2
	
func decrypt_movie(movie_loc:PackedByteArray, keys_loc:PackedByteArray, movie_offset:int):
	var temp_key1:int
	var temp_key2:int
	var temp_key3:int
	var t0:int = 0
	var a0:int
	var keys_offset:int = 0
	
	for i in range(0, 0x20):
		keys_offset = i << 1
		temp_key1 = keys_loc.decode_u16(keys_offset + 6)
		temp_key2 = movie_loc.decode_u16(movie_offset + 0x40)
		temp_key3 = movie_loc.decode_u16(movie_offset)
		temp_key1 = temp_key2 ^ temp_key1
		temp_key3 = temp_key3 ^ temp_key1
		movie_loc.encode_s16(movie_offset, temp_key3)
		movie_offset += 2
		keys_offset += 1
		
func make_keys(stack_keys:PackedByteArray) -> int:
	var temp_key1:int
	var temp_key2:int
	var temp_key3:int
	
	temp_key1 = stack_keys.decode_u16(0) #lhu      a1, $0000(a0)
	temp_key2 = stack_keys.decode_u16(2) #lhu      a3, $0000(a1)
	temp_key3 = stack_keys.decode_u16(4) #lhu      v1, $0000(a2)
	temp_key1 = temp_key2 * temp_key1 #mult     a1, a3
	temp_key3 = temp_key3 + temp_key1 #addu     v1, v1, a1
	return temp_key3
	
func get_keys_from_string(key:int, keystring_len:int, keystring_hex:PackedByteArray, magic_table:PackedByteArray) -> int:
	var magic_table_hex_s16:int
	var v0:int
	var a0:int = 0
	var a1:int
	var string_hex_byte:int
	
	print("Getting key from magic number '0x%X'" % key)
	for i in range(0, keystring_len):
		string_hex_byte = keystring_hex.decode_s8(i) #lb       v0, $0000(v1)
		string_hex_byte = string_hex_byte << 1 #sll      v0, v0, 1
		magic_table_hex_s16 = magic_table.decode_s16(string_hex_byte + 0x100) #addu     v0, v0, t0, lh       v1, $0100(v0)
		magic_table_hex_s16 = magic_table_hex_s16 * key #mult     t2, v1
		a1 = magic_table_hex_s16 + 0x03FF #addiu    a1, v1, $03FF
		if magic_table_hex_s16 < 0: #slti     a0, v1, $0000
			a0 = 1
		v0 = magic_table_hex_s16 #daddu    v0, v1, zero
		if a0 != 0: #movn     v0, a1, a0
			v0 = a1
		v0 = v0 >> 10 #sra      v0, v0, 10
		v0 = v0 << 10 #sll      v0, v0, 10
		magic_table_hex_s16 = magic_table_hex_s16 - v0 #subu     v1, v1, v0
		magic_table_hex_s16 = magic_table_hex_s16 << 1 #sll      v1, v1, 1
		key = magic_table.decode_s16(magic_table_hex_s16) #addu     v1, v1, t0, lh       t2, $0000(v1)
		
	print("Returning decrypted key '0x%X'" % key)
	return key
