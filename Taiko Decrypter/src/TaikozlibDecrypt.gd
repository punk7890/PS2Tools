extends Node

@onready var MemUsage:Label = $MemoryUsage
@onready var taikozlib_load = $TaikozlibLoad
@onready var taikozlib_save = $TaikozlibSave

var loaded_file:PackedByteArray
var loaded_file_len:int
	
func _process(_delta):
	var MEM = Performance.get_monitor(Performance.MEMORY_STATIC)
	var MEM2 = Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
	MemUsage.text = str(MEM * 0.000001, " MB / ", MEM2 * 0.000001, "MB")

func _on_taikozlib_pressed():
	taikozlib_load.visible = true

func _on_taikozlib_load_files_selected(paths):
	var fileIndex:int 
	var filePath:String
	var length:int
	var t4:int
	var t2:int
	var t5:int
	var t6:int #always zero?
	var t7:int
	var startOffset:int #a1
	
	startOffset = 0
	fileIndex = 0
	t2 = 0xFFA5 #decrypt key
	filePath = paths[fileIndex]
	while filePath.is_empty() == false:
		var file:FileAccess = FileAccess.open(filePath, FileAccess.READ)
		loaded_file_len = file.get_length()
		loaded_file = file.get_buffer(loaded_file_len)
		length = loaded_file_len #t7
		if loaded_file.decode_u16(0) != 0xDA87:
			OS.alert("'%s' isn't an encrypted zlib file. Ending." % filePath)
			print("'%s' isn't an encrypted zlib file. Ending." % filePath)
			loaded_file.clear()
			loaded_file_len = 0
			break
			
		t4 = 0
		t7 = length
		for i in range(0, length):
			t6 = 0 #lw       t6, $0010(t3) always zero?
			t5 = 0 #slti     t5, t4, $0000
			t7 = t4 + 0xF #addiu    t7, t4, $000F
			t6 <<= 11 #sll      t6, t6, 11
			if t5 == 0:  #movz t7, t4, t5
				t7 = t4
			t6 += t6 + t4 #addu     t6, t6, t4
			t7 >>= 4 #sra      t7, t7, 4
			t6 = startOffset + t6 #addu     t6, a1, t6
			t7 = t7 & t2 #and      t7, t7, t2
			t5 = loaded_file.decode_u8(i << 4)
			t7 = ~(t7 | 0)
			t7 &= 0xFFFFFFFF #working with 64bits, align to 32bit
			t4 += 0x10
			t5 = t5 ^ t7
			loaded_file.encode_u8(i << 4, t5)
			if t4 <= length:
				t7 = 1
			else:
				t7 = 0
				
			if t7 == 0:
				break
				
		var save_file:FileAccess = FileAccess.open(filePath.insert(filePath.length(), ".zlib"), FileAccess.WRITE)
		save_file.store_buffer(loaded_file)
		loaded_file.clear()
		loaded_file_len = 0
		fileIndex += 1
		if paths[fileIndex].is_empty():
			break
		filePath = paths[fileIndex]
	return
