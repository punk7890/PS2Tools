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
var loaded_movie_name:String
var loaded_movie_id:int

func _ready():
	var file:FileAccess = FileAccess.open("keys/keys.tbl", FileAccess.READ)
	if file == null or 0:
		print("Can't open keys.tbl from keys/keys.tbl")
		return
		
	loaded_file_len = file.get_length()
	loaded_file = file.get_buffer(loaded_file_len)
	print("Key size 0x%X" % loaded_file_len)
	
func _process(_delta):
	var MEM = Performance.get_monitor(Performance.MEMORY_STATIC)
	var MEM2 = Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
	MemUsage.text = str(MEM, " / ", MEM2)
	if loaded_file_len != 0:
		$Control/Writetest.text = "Load keys (already loaded)"

func _on_writetest_pressed():
	WriteLoad.visible = true
	
func _on_movies_pressed():
	if loaded_file_len == 0 or null:
		print("keys.tbl not loaded!")
		Error.visible = true
		return
	LoadMovie.visible = true

func _on_file_dialog_write_load_file_selected(path):
	var file:FileAccess = FileAccess.open(path, FileAccess.READ)
	loaded_file_len = file.get_length()
	loaded_file = file.get_buffer(loaded_file_len)
	print("File size 0x%X" % loaded_file_len)
	file.close()
	WriteLoad.visible = false

func _on_file_dialog_load_movie_file_selected(path):
	var temp_file:FileAccess = FileAccess.open(path, FileAccess.READ)
	var length:int = temp_file.get_length()
	
	loaded_movie = temp_file.get_buffer(length)
	loaded_movie_len = length
	loaded_movie_name = path
	print("File size 0x%X" % loaded_movie_len)
	loaded_movie_id = path.to_int() / 10
	print("MovieID is now %s" % loaded_movie_id)
	temp_file.close()
	LoadMovie.visible = false
	SaveMovie.visible = true

func _on_file_dialog_save_movie_file_selected(path):
	var key_table:PackedByteArray = loaded_file
	var key_offset:int
	var key_byte:int
	var file:FileAccess = FileAccess.open(path, FileAccess.WRITE)
	var file_mem:PackedByteArray = loaded_movie
	var file_offset:int
	var file_size:int
	var byte:int
	var byte2:int
	var v1:int
	var a2:int
	var t0:int
	var s0:int
	var remainder:int
	var movieID:int
	var neg_counter:int
	
	#movieID = getMovieID(loaded_movie_name)
	print("Saving to %s" % path)
	movieID = loaded_movie_id
	if movieID == -1 or 0:
		file_mem.clear()
		file.close()
		loaded_movie.clear()
		return
		
	movieID = (movieID << 32) << 24 #dsll32   a0, a0, 24
	movieID = (movieID >> 32) >> 24 #dsra32   a0, a0, 24
	key_offset = 0x304
	file_offset = 0x4000
	file_size =  file_mem.decode_u32(0x1C) / 0x2000
	for j in range(0, file_size):
		if Performance.get_monitor(Performance.MEMORY_STATIC) == 0x3B9ACA00:
			print("Memory exceeding 1GB, stopping (shouldn't happen).")
			break
			
		v1 = 3
		for i in range(0, 0x1F8):
			remainder = i % v1
			s0 = i + 1
			byte = file_mem.decode_u8(file_offset + i)
			s0 = remainder << 8
			s0 = key_offset + s0
			s0 = byte + s0
			key_byte = key_table.decode_u8((key_offset + s0) - key_offset)
			file_mem.encode_s8(file_offset + i, key_byte)
			
		file_offset += 0x1F8
		for i in range(0, 8):
			remainder = i % v1
			byte = file_mem.decode_u8(file_offset + i)
			remainder = remainder << 8
			remainder = remainder + byte
			s0 = key_offset + remainder
			key_byte = key_table.decode_u8((key_offset + s0) - key_offset)
			file_mem.encode_s8(file_offset + i, key_byte)
		
		file_offset += 0x8
		neg_counter = 1
		t0 = -1
		for i in range(0, 0x1FF):
			byte2 = file_mem.decode_u8((file_offset - neg_counter) - 1)
			a2 = (t0 << 32) << 24 #dsll32   a2, t0, 24
			a2 = (a2 >> 32) >> 24 #dsra32   a2, a2, 24
			byte = file_mem.decode_u8(file_offset - neg_counter)
			v1 = byte2 + a2
			v1 = movieID + v1
			v1 = v1 & 0x00FF
			byte = byte - v1
			file_mem.encode_s8(file_offset - neg_counter, byte)
			neg_counter += 1
			t0 -= 1
		file_offset += 0x1E00
		movieID += 1
		
	file.store_buffer(file_mem)
	file_mem.clear()
	file.close()
	loaded_movie.clear()
	print("Saved movie")
	return
	
#func getMovieID(path:String) -> int:
	#if path.ends_with("S10001_0.MOV"):
		#return 0x2711
	#if path.ends_with("S10002_0.MOV"):
		#return 0x2712
	#else:
		#print("Unknown movie name, skipping")
		#return -1
