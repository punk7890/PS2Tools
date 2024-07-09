extends Node

@onready var MemUsage:Label = $MemoryUsage
@onready var fushigi_load_noah = $FushigiLoadNOAH
@onready var fushigi_load_folder = $FushigiLoadFOLDER
@onready var fushigi_load_g_2d = $FushigiLoadG2D

var chose_file:bool = false
var noah_path:String
var chose_folder:bool = false
var folder_path:String

var chose_g2d:bool = false
var g2d_files:PackedStringArray

var decomp_bmp:bool = true

const com_types:PackedByteArray = [
	0x0C,
	0x03,
	0x0B,
	0x03,
	0x0A,
	0x03,
	0x09,
	0x03,
	0x06,
	0x03,
	0x05,
	0x03,
	0x00,
	0x00,
	0x00,
	0x00,
	0x06,
	0x02,
	0x05,
	0x02,
	0x00,
	0x00,
	0x00,
	0x00,
	0x08,
	0x04,
	0x07,
	0x04,
	0x00,
	0x00,
	0x00,
	0x00,
	0x80,
	0x40,
	0x20,
	0x10,
	0x08,
	0x04,
	0x02,
	0x01,
	0xF0,
	0x0F,
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
	0x00,
	0x00,
	0x00,
	0x00
]

func _process(_delta):
	var MEM = Performance.get_monitor(Performance.MEMORY_STATIC)
	var MEM2 = Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
	MemUsage.text = str(MEM * 0.000001, " MB / ", MEM2 * 0.000001, "MB")
	
	if chose_file and chose_folder:
		makeFiles()
		chose_folder = false
		chose_file = false
		chose_g2d = false
	elif chose_g2d and chose_folder:
		splitG2D()
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
		
#This function semi assumes offsets as it isn't fully clear how the file system determines offsets
#This also appears to add extra zeros at the end of the images when decompressed for some reason but the sizes appear correct
func splitG2D() -> void:
	var file:FileAccess
	var new_file:FileAccess
	var loaded_array_size:int
	var start_off:int
	var num_files:int
	var file_size:int
	var mem_file_size:int
	var file_name:String
	var len:int
	var mem_file:PackedByteArray
	var i:int
	var j:int
	
	loaded_array_size = g2d_files.size()
	i = 0
	while i < loaded_array_size:
		file = FileAccess.open(g2d_files[i], FileAccess.READ)
		#first file doesn't seem to follow second file header
		file_size = file.get_length()
		file.seek(0x8)
		num_files = file.get_32() #?
		file.seek(0x10)
		start_off = file.get_32()
		file.seek(0x14)
		len = file.get_32()
		len -= 9 + start_off
		file.seek(start_off + 4)
		mem_file = file.get_buffer(len)
		mem_file_size = mem_file.size()
		file_name = g2d_files[i]
		file_name = file_name.get_file()
		if decomp_bmp:
			mem_file = fushigiDecompLZ(mem_file, swap32(mem_file.decode_u32(0x4)))
			
		print("0x%X " % start_off, "0x%X " % file_size, "%s" % folder_path + "/%s" % file_name)
		new_file = FileAccess.open(folder_path + "/%s" % file_name + ".0000.BMP", FileAccess.WRITE)
		new_file.store_buffer(mem_file)
		new_file.close()
		mem_file.clear()
		i += 1
		j = 1
		while j < num_files:
			len = (mem_file_size + start_off) + 5 #wont work if there's more than 2 files
			start_off = len + 0x28
			file.seek(len + 0x10)
			len = file.get_32() 
			len -= start_off + 7 #wont work if there's more than 2 files
			file.seek(start_off)
			mem_file = file.get_buffer(len)
			if decomp_bmp:
				mem_file = fushigiDecompLZ(mem_file, swap32(mem_file.decode_u32(0x4)))
				
			new_file = FileAccess.open(folder_path + "/%s" % file_name + ".00%s.BMP" % j, FileAccess.WRITE)
			new_file.store_buffer(mem_file)
			new_file.close()
			mem_file.clear()
			j += 1
	file.close()
		
	
func makeFiles() -> void:
	var file:FileAccess = FileAccess.open(noah_path, FileAccess.READ)
	var new_file:FileAccess
	var bytes:int
	var noah:int
	var start_off:int
	var num_files:int
	var name_table_off:int
	var file_table_off:int
	var file_name:String
	var file_name_len:int
	var off:int
	var len:int
	var mem_file:PackedByteArray
	
	file.seek(0)
	bytes = file.get_32()
	noah = 0x48414F4E #NOAH
	if bytes == noah:
		file.seek(0x10)
		start_off = file.get_32()
		file.seek(0x18)
		num_files = file.get_32()
		file.seek(0x30)
		file_table_off = file.get_32()
		file.seek(0x50)
		name_table_off = file.get_32()
		file_name_len = 0
		for i in range(0, num_files):
			off = (i * 0x18) + file_table_off
			len = off + 0x8
			file.seek(off)
			off = file.get_32() + start_off
			file.seek(len)
			len = file.get_32()
			file.seek(off)
			mem_file = file.get_buffer(len)
			file.seek(name_table_off + file_name_len)
			file_name = file.get_line()
			file_name_len += file_name.length() + 1
			if file_name.ends_with(".BMP") or file_name.ends_with(".CMP"):
				if mem_file.decode_u16(0x0) != 0x4D42: #not regular BMP
					if decomp_bmp:
						mem_file = fushigiDecompLZ(mem_file, swap32(mem_file.decode_u32(0x4)))
			
			file_name = file_name.replace("\\", ".") #for Seikai no Senki.
			print("0x%X " % off, "0x%X " % len, "%s " % file_name, "%s" % folder_path + "/%s" % file_name)
			new_file = FileAccess.open(folder_path + "/%s" % file_name, FileAccess.WRITE)
			new_file.store_buffer(mem_file)
			new_file.close()
			mem_file.clear()
			
		file.close()
			
			
	else:
		OS.alert("'%s' isn't a NOAH archive. Ending." % noah_path)
		file.close()
		
func swap32(num) -> int:
	var swapped:int
	
	swapped = ((num>>24)&0xff) | ((num<<8)&0xff0000) | ((num>>8)&0xff00) | ((num<<24)&0xff000000)
	return swapped
		
func fushigiDecompLZ(file:PackedByteArray, decomp_size:int) -> PackedByteArray:
	#var at:int
	var v0:int
	var v1:int
	var a0:int
	var a1:int
	var a2:int
	var a3:int
	var t0:int #stack offset
	var t1:int
	var t4:int #file size
	var t2:int
	var t3:int
	var t5:int
	var t6:int
	var t7:int
	#var s0:int
	#var s1:int
	#var s2:int
	#var s3:int
#	var s4:int
	#var s5:int
	var s6:int
	#var s7:int
	#var t8:int
	#var t9:int
	var temp_i:int
	var temp_i_2:int
	var loop_1_i:int
	var loop_2_i:int
	var do_loop:bool = true
	var new_arrary:PackedByteArray
	var new_file:PackedByteArray
	var comp_size:int
	var magic_byte_1:int
	var magic_byte_2:int
	var magic_byte_3:int
	
	temp_i = 0
	temp_i_2 = 0
	loop_1_i = 1
	loop_2_i = 1
	s6 = 0
	magic_byte_1 = file.decode_u8(0)
	magic_byte_2 = com_types[(magic_byte_1 << 1) + 1]
	magic_byte_1 = com_types[magic_byte_1 << 1]
	magic_byte_3 = (1 << magic_byte_1) - 1
	comp_size = file.size()
	new_arrary = file.slice(0x8)
	t0 = 0 #stack offset
	t4 = decomp_size #size
	new_file.resize(t4)
	t1 = 0
	t5 = 0
	a0 = decomp_size #size
	if a0 <= t1:
		return file
			
	t4 = t4 + t1
	t3 = 0
	t7 = t0 + 0x14
	t6 = t0 + 0x1C
	t3 >>= 1
	t2 = t0 + 0x14
	v0 = 0
	while s6 < decomp_size:
		s6 += 1
		loop_1_i = 1
		loop_2_i = 1
		while do_loop:
			if t3 == 0:
				v0 = t4 < t1
				if v0 != 0:
					do_loop = false
					s6 = decomp_size
					break
					
				v0 = a0 < t1
				t2 = t7 #t2 = temp_loc
				v1 = 0 #loaded file loc lw       v1, $0010(t0)
				v0 = temp_i #lw       v0, $0000(t2)
				t3 = 0x80
				v1 = v1 + v0
				if v1 >= comp_size - 8:
					do_loop = false
					s6 = decomp_size
					break
				v0 += 1
				t5 = new_arrary.decode_u8(v1)
				temp_i = v0
				
			v0 = t3 & t5 #001A037C
			if v0 != 0:
				a1 = temp_i
				v1 = 0 #loaded file loc
				a0 = temp_i_2
				if a1 >= comp_size - 8:
					do_loop = false
					s6 = decomp_size
					break
				v0 = 0 #new file lw       v0, $0018(t0)
				v1 = v1 + a1
				a2 = new_arrary.decode_u8(v1)
				a1 += 1
				v0 += a0
				a0 += 1
				new_file.encode_s8(v0, a2)
				temp_i = a1
				temp_i_2 = a0
				t1 = temp_i_2
				a0 = decomp_size
				v0 = t1 < a0
				t3 >>= 1
				if v0 != 0:
					break
			
			v1 = temp_i
			v0 = 0 #loaded file loc
			v0 = v0 + v1
			if v0 >= comp_size - 8:
				do_loop = false
				s6 = decomp_size
				break
			v1 += 1
			a1 = new_arrary.decode_u8(v0)
			a2 = v1 + 1
			temp_i = v1
			a1 <<= 8
			v0 = 0
			v0 = v0 + v1
			if v0 >= comp_size - 8:
				do_loop = false
				s6 = decomp_size
				break
			a0 = new_arrary.decode_u8(v0)
			temp_i = a2
			a0 |= a1
			v0 = magic_byte_1
			v1 = magic_byte_3
			t1 = temp_i_2
			v0 = a0 >> v0
			v1 &= a0
			a1 = magic_byte_2
			v0 &= 0xFFFF
			a3 = t1 - v1
			a2 = v0 + a1
			a0 = decomp_size
			if a3 <= 0:
				if a2 >= 0:
					a0 = t0 + 0x1C
					v1 = temp_i_2
				else:
					a0 = decomp_size
					v0 = t1 < a0
					t3 >>= 1
					break
					
				while loop_1_i > 0:
					a3 += 1
					v0 = 0 #001A0434 newfile offset
					a2 -= 1
					loop_1_i = a2
					v0 += v1
					v1 += 1
					new_file.encode_s8(v0, 0)
					temp_i_2 = v1
					if a3 >= 0:
						break
						
				t1 = temp_i_2
				if a2 >= 1: #blezl    a2, $001A0498
					t1 = t0 + 0x1C
					while loop_2_i > 0:
						a0 = 0 #newfile
						a2 -= 1
						v0 = temp_i_2
						v1 = a0 + a3
						a3 += 1
						a1 = new_file.decode_u8(v1)
						a0 += v0
						v0 += 1
						new_file.encode_s8(a0, a1)
						temp_i_2 = v0
						loop_2_i = a2
					#t1 = temp_i
			else:
				if a2 >= 0:
					t1 = t0 + 0x1C
					loop_2_i = a2
					while loop_2_i > 0:
						a0 = 0 #newfile
						a2 -= 1
						v0 = temp_i_2
						v1 = a0 + a3
						a3 += 1
						a1 = new_file.decode_u8(v1)
						a0 += v0
						v0 += 1
						new_file.encode_s8(a0, a1)
						temp_i_2 = v0
						loop_2_i = a2
					t1 = temp_i_2
					
			a0 = decomp_size
			v0 = t1 < a0
			t3 >>= 1
			if v0 == 0:
				do_loop = false
				s6 = decomp_size
				t3 >>= 1
				break
	return new_file
	
#	Original function from Fushigi no Umi no Nadia - Dennou Battle - Miss Nautilus Contest 
#	TAB=8
#
#__001a0308:					# 
	#daddu		t0, a0, zero		# 001a0308:0080402d	
	#daddu		t4, a2, zero		# 001a030c:00c0602d	
	#lw		t1, $001c(t0)		# 001a0310:8d09001c	
	#daddu		t5, zero, zero		# 001a0314:0000682d	
	#lw		a0, $0000(t0)		# 001a0318:8d040000	
	#sltu		v1, t1, a0		# 001a031c:0124182b	
	#beq		v1, zero, $001a04b0	# 001a0320:10600063	v __001a04b0
	#addiu		v0, zero, $fffe		# 001a0324:2402fffe	v0=$fffffffe
	#bnel		a1, zero, $001a0330	# 001a0328:54a00001	v __001a0330
	#sw		a1, $0018(t0)		# 001a032c:ad050018	
#__001a0330:					# 
	#addu		t4, t4, t1		# 001a0330:01896021	
	#daddu		t3, zero, zero		# 001a0334:0000582d	
	#addiu		t7, t0, $0014		# 001a0338:250f0014	
	#addiu		t6, t0, $001c		# 001a033c:250e001c	
	#srl		t3, t3, 1		# 001a0340:000b5842	
	#nop					# 001a0344:00000000	
#__001a0348:					# 
	#bne		t3, zero, $001a037c	# 001a0348:1560000c	v __001a037c
	#addiu		t2, t0, $0014		# 001a034c:250a0014	
	#sltu		v0, t1, t4		# 001a0350:012c102b	
	#beq		v0, zero, $001a04ac	# 001a0354:10400055	v __001a04ac
	#sltu		v0, t1, a0		# 001a0358:0124102b	
	#daddu		t2, t7, zero		# 001a035c:01e0502d	
	#lw		v1, $0010(t0)		# 001a0360:8d030010	
	#lw		v0, $0000(t2)		# 001a0364:8d420000	
	#addiu		t3, zero, $0080		# 001a0368:240b0080	t3=$00000080
	#addu		v1, v1, v0		# 001a036c:00621821	
	#addiu		v0, v0, $0001		# 001a0370:24420001	
	#lbu		t5, $0000(v1)		# 001a0374:906d0000	
	#sw		v0, $0000(t2)		# 001a0378:ad420000	
#__001a037c:					# 
	#and		v0, t5, t3		# 001a037c:01ab1024	
	#beq		v0, zero, $001a03c0	# 001a0380:1040000f	v __001a03c0
	#daddu		a3, t6, zero		# 001a0384:01c0382d	
	#lw		a1, $0000(t2)		# 001a0388:8d450000	
	#lw		v1, $0010(t0)		# 001a038c:8d030010	
	#lw		a0, $0000(a3)		# 001a0390:8ce40000	
	#lw		v0, $0018(t0)		# 001a0394:8d020018	
	#addu		v1, v1, a1		# 001a0398:00651821	
	#lbu		a2, $0000(v1)		# 001a039c:90660000	
	#addiu		a1, a1, $0001		# 001a03a0:24a50001	
	#addu		v0, v0, a0		# 001a03a4:00441021	
	#addiu		a0, a0, $0001		# 001a03a8:24840001	
	#sb		a2, $0000(v0)		# 001a03ac:a0460000	
	#sw		a1, $0000(t2)		# 001a03b0:ad450000	
	#beq		zero, zero, $001a0494	# 001a03b4:10000037	v __001a0494
	#sw		a0, $0000(a3)		# 001a03b8:ace40000	
	#nop					# 001a03bc:00000000	
#__001a03c0:					# 
	#lw		v1, $0000(t2)		# 001a03c0:8d430000	
	#lw		v0, $0010(t0)		# 001a03c4:8d020010	
	#addu		v0, v0, v1		# 001a03c8:00431021	
	#addiu		v1, v1, $0001		# 001a03cc:24630001	
	#lbu		a1, $0000(v0)		# 001a03d0:90450000	
	#addiu		a2, v1, $0001		# 001a03d4:24660001	
	#sw		v1, $0000(t2)		# 001a03d8:ad430000	
	#sll		a1, a1, 8		# 001a03dc:00052a00	
	#lw		v0, $0010(t0)		# 001a03e0:8d020010	
	#addu		v0, v0, v1		# 001a03e4:00431021	
	#lbu		a0, $0000(v0)		# 001a03e8:90440000	
	#sw		a2, $0000(t2)		# 001a03ec:ad460000	
	#or		a0, a0, a1		# 001a03f0:00852025	
	#lw		v0, $0008(t0)		# 001a03f4:8d020008	
	#lhu		v1, $0006(t0)		# 001a03f8:95030006	
	#lw		t1, $001c(t0)		# 001a03fc:8d09001c	
	#srav		v0, a0, v0		# 001a0400:00441007	
	#and		v1, v1, a0		# 001a0404:00641824	
	#lw		a1, $000c(t0)		# 001a0408:8d05000c	
	#andi		v0, v0, $ffff		# 001a040c:3042ffff	
	#subu		a3, t1, v1		# 001a0410:01233823	
	#bgez		a3, $001a0458		# 001a0414:04e10010	v __001a0458
	#addu		a2, v0, a1		# 001a0418:00453021	
	#blezl		a2, $001a049c		# 001a041c:58c0001f	v __001a049c
	#lw		a0, $0000(t0)		# 001a0420:8d040000	
	#addiu		a0, t0, $001c		# 001a0424:2504001c	
	#lw		v1, $0000(a0)		# 001a0428:8c830000	
	#nop					# 001a042c:00000000	
#__001a0430:					# 
	#addiu		a3, a3, $0001		# 001a0430:24e70001	
	#lw		v0, $0018(t0)		# 001a0434:8d020018	
	#addiu		a2, a2, $ffff		# 001a0438:24c6ffff	
	#addu		v0, v0, v1		# 001a043c:00431021	
	#addiu		v1, v1, $0001		# 001a0440:24630001	
	#sb		zero, $0000(v0)		# 001a0444:a0400000	
	#bgez		a3, $001a0458		# 001a0448:04e10003	v __001a0458
	#sw		v1, $0000(a0)		# 001a044c:ac830000	
	#bgtzl		a2, $001a0430		# 001a0450:5cc0fff7	^ __001a0430
	#lw		v1, $0000(a0)		# 001a0454:8c830000	
#__001a0458:					# 
	#blezl		a2, $001a0498		# 001a0458:58c0000f	v __001a0498
	#lw		t1, $001c(t0)		# 001a045c:8d09001c	
	#addiu		t1, t0, $001c		# 001a0460:2509001c	
	#nop					# 001a0464:00000000	
#__001a0468:					# 
	#lw		a0, $0018(t0)		# 001a0468:8d040018	
	#addiu		a2, a2, $ffff		# 001a046c:24c6ffff	
	#lw		v0, $0000(t1)		# 001a0470:8d220000	
	#addu		v1, a0, a3		# 001a0474:00871821	
	#addiu		a3, a3, $0001		# 001a0478:24e70001	
	#lbu		a1, $0000(v1)		# 001a047c:90650000	
	#addu		a0, a0, v0		# 001a0480:00822021	
	#addiu		v0, v0, $0001		# 001a0484:24420001	
	#sb		a1, $0000(a0)		# 001a0488:a0850000	
	#bgtz		a2, $001a0468		# 001a048c:1cc0fff6	^ __001a0468
	#sw		v0, $0000(t1)		# 001a0490:ad220000	
#__001a0494:					# 
	#lw		t1, $001c(t0)		# 001a0494:8d09001c	
#__001a0498:					# 
	#lw		a0, $0000(t0)		# 001a0498:8d040000	
#__001a049c:					# 
	#sltu		v0, t1, a0		# 001a049c:0124102b	
	#bnel		v0, zero, $001a0348	# 001a04a0:5440ffa9	^ __001a0348
	#srl		t3, t3, 1		# 001a04a4:000b5842	
	#sltu		v0, t1, a0		# 001a04a8:0124102b	
#__001a04ac:					# 
	#sll		v0, v0, 1		# 001a04ac:00021040	
#__001a04b0:					# 
	#jr		ra			# 001a04b0:03e00008	
	#nop					# 001a04b4:00000000	
