extends Node

@onready var au_load_nfp: FileDialog = $AULoadNFP
@onready var au_load_mlh: FileDialog = $AULoadMLH
@onready var au_load_folder: FileDialog = $AULoadFOLDER

var chose_file:bool = false
var nfp_path:PackedStringArray
var chose_folder:bool = false
var folder_path:String

var output_bmp:bool = true

var chose_mlh:bool = false
var selected_files:PackedStringArray

var out_decomp:bool = false
	
	
func _process(_delta):
	if chose_mlh and chose_folder:
		MLHMakeFiles()
		selected_files.clear()
		chose_folder = false
		chose_mlh = false
		nfp_path.clear()
	elif nfp_path and chose_folder:
		NFPExtract()
		selected_files.clear()
		chose_folder = false
		chose_mlh = false
		nfp_path.clear()
	
	
func _on_load_nfp_pressed():
	au_load_nfp.visible = true
	
	
func _on_au_load_noah_file_selected(path):
	au_load_nfp.visible = false
	au_load_folder.visible = true
	chose_file = true
	nfp_path = path


func _on_au_load_nfp_files_selected(paths):
	au_load_nfp.visible = false
	au_load_folder.visible = true
	chose_file = true
	nfp_path = paths
	
	
func _on_au_load_folder_dir_selected(dir):
	folder_path = dir
	chose_folder = true
	
	
func _on_decomp_button_toggled(_toggled_on):
	out_decomp = !out_decomp
	
	
func _on_load_mlh_pressed():
	au_load_mlh.visible = true
	
	
func _on_au_load_mlh_files_selected(paths):
	au_load_mlh.visible = false
	au_load_folder.visible = true
	selected_files = paths
	chose_mlh = true
	
	
func MLHMakeFiles() -> void:
	var in_file:FileAccess
	var out_file:FileAccess
	var next_file_off:int
	var image_size:int
	var comp_data:PackedByteArray
	var file_name:String
	var sub_name:String
	var bpp:int
	var width:int
	var height:int
	var buff:PackedByteArray
	var pos:int
	var pal_data_pos:int
	var pal_off:int
	var data_start_off:int
	var dec_data:PackedByteArray
	var mlh_header_start:int = 0
	var mlh_files:int = 0
	var mlh_files_start:int = 0
	var mlh_files_comp_flag:int = 0 #?
	var mlh_f_comp_size:int
	var mlh_f_dec_size:int
	var mlh_f_start:int
	var mlh_f_next_f:int
	
	for a in range(0, selected_files.size()):
		#MLH
		in_file = FileAccess.open(selected_files[a], FileAccess.READ)
		pos = 0
		
		mlh_header_start = pos
		in_file.seek(mlh_header_start + 0x24)
		mlh_files = in_file.get_32()
		mlh_files_start = in_file.get_32()
		mlh_files_comp_flag = in_file.get_32()
		mlh_f_next_f = mlh_header_start + mlh_files_start
		
		match Main.game_type:
			Main.FUTAKOI:
				for i in range(0, mlh_files):
					pos = mlh_f_next_f
					in_file.seek(pos)
					file_name = in_file.get_line()
					
					in_file.seek(pos + 0x10)
					mlh_f_comp_size = in_file.get_32()
					mlh_f_dec_size = in_file.get_32()
					mlh_f_start = in_file.get_32()
					mlh_f_next_f = in_file.get_32()
					
					in_file.seek(mlh_f_start)
					comp_data = in_file.get_buffer(mlh_f_comp_size)
					
					if mlh_f_comp_size != mlh_f_dec_size:
						comp_data = comp_data.slice(4)
						dec_data = ComFuncs.decompLZSS(comp_data, mlh_f_comp_size, mlh_f_dec_size)
						
						if file_name.get_extension() == "NBP" and output_bmp:
							var org_pallete_data: PackedByteArray
							var org_pal_off: int = 0
							
							pos = 0
							
							next_file_off = dec_data.decode_u32(pos + 0x18)
							bpp = dec_data.decode_u8(pos + 0x1C)
							pal_off = dec_data.decode_u32(pos + 0x24)
							image_size = dec_data.decode_u32(pos + 0x28)
							width = dec_data.decode_u16(pos + 0x5C)
							height = dec_data.decode_u16(pos + 0x5E)
							data_start_off = dec_data.decode_u32(pos + 0x50)
							
							var string_bytes:PackedByteArray = dec_data.slice(pos + image_size)
							sub_name = string_bytes.get_string_from_ascii()
							
							if sub_name.contains("/"):
								sub_name = sub_name.replace("/", "_")
								
							string_bytes.clear()
							
							pal_data_pos = image_size - 0x400
							
							# debug
							if out_decomp:
								out_file = FileAccess.open(folder_path + "/%s" % file_name + "_%s" % sub_name + ".DEC", FileAccess.WRITE)
								out_file.store_buffer(dec_data)
								out_file.close()
							
							var remove_size:int = next_file_off - image_size
							buff = dec_data.slice(pos, next_file_off - remove_size)
							
							
							if pal_off:
								var png:Image = ComFuncs.processImg(buff, data_start_off, width, height, bpp, pal_data_pos)
								png.save_png(folder_path + "/%s" % file_name + "_%s" % sub_name + ".png")
								
								org_pallete_data = dec_data.slice(pal_data_pos, pal_data_pos + 0x400)
								org_pal_off = pal_data_pos
							else:
								if bpp == 32:
									var png:Image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, buff.slice(data_start_off))
									png.save_png(folder_path + "/%s" % file_name + "_%s" % sub_name + ".png")
								elif bpp == 24:
									var png:Image = Image.create_from_data(width, height, false, Image.FORMAT_RGB8, buff.slice(data_start_off))
									png.save_png(folder_path + "/%s" % file_name + "_%s" % sub_name + ".png")
								elif bpp == 8:
									var png:Image = Image.create_from_data(width, height, false, Image.FORMAT_L8, buff.slice(data_start_off))
									png.save_png(folder_path + "/%s" % file_name + "_%s" % sub_name + ".png")
								else:
									push_error("Unknown BPP format in %s" % file_name)
							
							print("0x%08X " % pos + "0x%08X " % buff.size() + folder_path + "/%s" % file_name + "_%s" % sub_name + ".NBP")
							
							buff.clear()
							pos = image_size + remove_size
							
							while next_file_off > 0:
								next_file_off = dec_data.decode_u32(pos + 0x18)
								bpp = dec_data.decode_u8(pos + 0x1C)
								pal_off = dec_data.decode_u32(pos + 0x24)
								image_size = dec_data.decode_u32(pos + 0x28)
								width = dec_data.decode_u16(pos + 0x5C)
								height = dec_data.decode_u16(pos + 0x5E)
								data_start_off = dec_data.decode_u32(pos + 0x50)
								
								
								string_bytes = dec_data.slice(pos + image_size)
								sub_name = string_bytes.get_string_from_ascii()
								
								if sub_name.contains("/"):
									sub_name = sub_name.replace("/", "_")
								
								string_bytes.clear()
								
								pal_data_pos = image_size - 0x400
								
								remove_size = next_file_off - image_size
								
								if next_file_off != 0:
									buff = dec_data.slice(pos, next_file_off + pos - remove_size)
								else:
									buff = dec_data.slice(pos, image_size + pos)
									
								# debug
								if out_decomp:
									out_file = FileAccess.open(folder_path + "/%s" % file_name + "_%s" % sub_name + ".PART", FileAccess.WRITE)
									out_file.store_buffer(buff)
									out_file.close()
								
								if pal_off:
									var png:Image = ComFuncs.processImg(buff, data_start_off, width, height, bpp, pal_off)
									png.save_png(folder_path + "/%s" % file_name + "_%s" % sub_name + ".png")
								else:
									if bpp == 32:
										var png:Image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, buff.slice(data_start_off))
										png.save_png(folder_path + "/%s" % file_name + "_%s" % sub_name + ".png")
									elif bpp == 24:
										var png:Image = Image.create_from_data(width, height, false, Image.FORMAT_RGB8, buff.slice(data_start_off))
										png.save_png(folder_path + "/%s" % file_name + "_%s" % sub_name + ".png")
									elif bpp == 8 and org_pal_off:
										var img_w_pal: PackedByteArray = PackedByteArray(buff)
										img_w_pal.append_array(org_pallete_data)
										var png:Image = ComFuncs.processImg(img_w_pal, data_start_off, width, height, bpp, image_size)
										png.save_png(folder_path + "/%s" % file_name + "_%s" % sub_name + ".png")
									else:
										push_error("Unknown BPP format in %s" % file_name)
								
								print("0x%08X " % pos + "0x%08X " % buff.size() + folder_path + "/%s" % file_name + "_%s" % sub_name + ".NBP")
								
								pos += buff.size() + remove_size
								buff.clear()
							
							dec_data.clear()
						else:
							out_file = FileAccess.open(folder_path + "/%s" % file_name + "_%s" % sub_name + ".BIN", FileAccess.WRITE)
							out_file.store_buffer(dec_data)
							out_file.close()
							comp_data.clear()
							dec_data.clear()
							
							print("0x%08X " % pos + "0x%08X " % buff.size() + folder_path + "/%s" % file_name + "_%s" % sub_name + ".BIN")
					else:
						out_file = FileAccess.open(folder_path + "/%s" % file_name, FileAccess.WRITE)
						out_file.store_buffer(comp_data)
						out_file.close()
						comp_data.clear()
						
						print("0x%08X " % mlh_f_start + "0x%08X " % mlh_f_dec_size + folder_path + "/%s" % file_name)
			Main.PIA3:
				for i in range(0, mlh_files):
					pos = mlh_f_next_f
					in_file.seek(pos)
					file_name = in_file.get_line()
					
					in_file.seek(pos + 0x10)
					mlh_f_comp_size = in_file.get_32()
					mlh_f_dec_size = in_file.get_32()
					mlh_f_start = in_file.get_32()
					mlh_f_next_f = in_file.get_32()
					
					in_file.seek(mlh_f_start)
					comp_data = in_file.get_buffer(mlh_f_comp_size)
					
					if mlh_f_comp_size != mlh_f_dec_size:
						comp_data = comp_data.slice(4)
						dec_data = ComFuncs.decompLZSS(comp_data, mlh_f_comp_size, mlh_f_dec_size)
						
						if file_name.get_extension().to_lower() == "nbp" and output_bmp:
							pos = 0
							
							var num_img_parts:int = dec_data.decode_u8(0x18)
							var f_width:int = dec_data.decode_u16(0x30)
							var f_height:int = dec_data.decode_u16(0x32)
							var img_parts_off:int = dec_data.decode_u32(0x34)
							var tile_hor_vert_flag: int = dec_data.decode_u32(0x20) #1 horizontal, 2 vertical
							bpp = dec_data.decode_u8(0x38)
							
							# debug
							if out_decomp:
								out_file = FileAccess.open(folder_path + "/%s" % file_name, FileAccess.WRITE)
								out_file.store_buffer(dec_data)
								out_file.close()
								
							if bpp == 32:
								var final_img: Image
								var slice_cnt:int = 1
								pos = img_parts_off
								var png_arr: Array[Image]
								while pos < (num_img_parts * 0x10) + img_parts_off:
									data_start_off = dec_data.decode_u32(pos)
									var size:int = dec_data.decode_u32(pos + 4)
									width = dec_data.decode_u16(pos + 12)
									height = dec_data.decode_u16(pos + 14)
									var image:PackedByteArray = dec_data.slice(data_start_off, data_start_off + size)
									var png:Image = Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, image)
									png_arr.append(png)
									pos += 0x10
									slice_cnt += 1
								
								if tile_hor_vert_flag == 1:
									final_img = ComFuncs.combine_images_horizontally(png_arr)
								elif tile_hor_vert_flag == 2:
									final_img = ComFuncs.combine_images_vertically(png_arr)
								else:
									final_img = ComFuncs.combine_images_vertically(png_arr)
									push_error("Unknown tile flag '%X' in '%s'. Image may be incorrect." % [tile_hor_vert_flag, file_name])
									
								final_img.save_png(folder_path + "/%s" % file_name + ".png")
							elif bpp == 24:
								var png: Image
								var final_img: Image
								var png_arr: Array[Image]
								var size: int
								
								pos = img_parts_off
								
								while pos < (num_img_parts * 0x10) + img_parts_off:
									data_start_off = dec_data.decode_u32(pos)
									size = dec_data.decode_u32(pos + 4)
									width = dec_data.decode_u16(pos + 12)
									height = dec_data.decode_u16(pos + 14)
									
									var image:PackedByteArray = dec_data.slice(data_start_off, data_start_off + size)
									
									#Unsure why PFxx images are incorrect with RGB8
									if file_name.begins_with("PF"):
										png = Image.create_from_data(width, height, false, Image.FORMAT_L8, image)
									else:
										png = Image.create_from_data(width, height, false, Image.FORMAT_RGB8, image)
										
									png_arr.append(png)
									pos += 0x10
									
								if tile_hor_vert_flag == 1:
									final_img = ComFuncs.combine_images_horizontally(png_arr)
								elif tile_hor_vert_flag == 2:
									final_img = ComFuncs.combine_images_vertically(png_arr)
								else:
									final_img = ComFuncs.combine_images_vertically(png_arr)
									push_error("Unknown tile flag '%X' in '%s'. Image may be incorrect." % [tile_hor_vert_flag, file_name])
									
								final_img.save_png(folder_path + "/%s" % file_name + ".png")
							elif bpp == 8:
								#Palette data at the end
								var image:PackedByteArray
								var final_image: PackedByteArray
								var palette_off: int = dec_data.decode_u32(0x14)
								var palette_bpp: int = dec_data.decode_u8(palette_off + 2)
								var palette_bytes_pp: int = dec_data.decode_u8(palette_off + 3)
								var palette_data: PackedByteArray = dec_data.slice(palette_off + 0x10)
								var size: int
								var tga:PackedByteArray
								var pal_unswiz: PackedByteArray
								var new_pal: PackedByteArray
								var widths: Array[int]
								var heights: Array[int]
								
								pos = img_parts_off
								
								while pos < (num_img_parts * 0x10) + img_parts_off:
									data_start_off = dec_data.decode_u32(pos)
									size = dec_data.decode_u32(pos + 4)
									width = dec_data.decode_u16(pos + 12)
									widths.append(width)
									
									height = dec_data.decode_u16(pos + 14)
									heights.append(height)
									
									image = dec_data.slice(data_start_off, data_start_off + size)
									final_image.append_array(image)
									pos += 0x10
									
								tga = ComFuncs.makeTGAHeader(true, 1, palette_bytes_pp * 8, bpp, f_width, f_height)
								pal_unswiz = ComFuncs.unswizzle_palette(palette_data, 16)
								new_pal = ComFuncs.convert_palette16_bgr_to_rgb(pal_unswiz)
								if tile_hor_vert_flag == 1:
									final_image = ComFuncs.combine_greyscale_data_horizontally_arr(final_image, widths, heights)
								elif tile_hor_vert_flag == 2:
									final_image = ComFuncs.combine_greyscale_data_vertically_arr(final_image, widths, heights)
								else:
									push_error("Unknown tile flag '%X' in '%s'. Image may be incorrect." % [tile_hor_vert_flag, file_name])
								
								tga.append_array(new_pal)
								tga.append_array(final_image)
								
								out_file = FileAccess.open(folder_path + "/%s" % file_name + ".TGA", FileAccess.WRITE)
								out_file.store_buffer(tga)
								out_file.close()
								image.clear()
								pal_unswiz.clear()
								tga.clear()
								new_pal.clear()
								final_image.clear()
							elif bpp == 4:
								var palette_off: int = dec_data.decode_u32(0x14)
								var png: Image
								var final_img: Image
								var png_arr: Array[Image]
								var size: int
								
								if num_img_parts > 1:
									push_error("BPP '%s' format has > 1 parts . Output will be wrong in '%s'" % [bpp, file_name])
									
								pos = img_parts_off
								
								while pos < (num_img_parts * 0x10) + img_parts_off:
									data_start_off = dec_data.decode_u32(pos)
									size = dec_data.decode_u32(pos + 4)
									width = dec_data.decode_u16(pos + 12)
									height = dec_data.decode_u16(pos + 14)
									
									var image:PackedByteArray = dec_data.slice(data_start_off, data_start_off + size)
									var pal: PackedByteArray = dec_data.slice(palette_off + 0x10)
									image.append_array(pal)
									
									# debug
									if out_decomp:
										out_file = FileAccess.open(folder_path + "/%s" % file_name + ".IMG", FileAccess.WRITE)
										out_file.store_buffer(image)
										out_file.close()
									
									var rgb8: PackedByteArray = ComFuncs.convert_greyscale_4bit_to_rgb8(image)
									png = Image.create_from_data(width, height, false, Image.FORMAT_RGB8, rgb8)
										
									png_arr.append(png)
									pos += 0x10
									
								if tile_hor_vert_flag == 1:
									final_img = ComFuncs.combine_images_horizontally(png_arr)
								elif tile_hor_vert_flag == 2:
									final_img = ComFuncs.combine_images_vertically(png_arr)
								else:
									final_img = ComFuncs.combine_images_vertically(png_arr)
									push_error("Unknown tile flag '%X' in '%s'. Image may be incorrect." % [tile_hor_vert_flag, file_name])
									
								final_img.save_png(folder_path + "/%s" % file_name + ".png")
								#push_error("BPP '%s' format not supported in '%s'" % [bpp, file_name])
								#var image:PackedByteArray
								#var final_image: PackedByteArray
								#var palette_off: int = dec_data.decode_u32(0x14)
								#var palette_bpp: int = dec_data.decode_u8(palette_off + 2)
								#var palette_bytes_pp: int = dec_data.decode_u8(palette_off + 3)
								#var palette_data: PackedByteArray = dec_data.slice(palette_off + 0x10)
								#var size: int = 0
								#pos = img_parts_off
								#while pos < (num_img_parts * 0x10) + img_parts_off:
									#data_start_off = dec_data.decode_u32(pos)
									#size = dec_data.decode_u32(pos + 4)
									#width = dec_data.decode_u16(pos + 12)
									#height = dec_data.decode_u16(pos + 14)
									#image = dec_data.slice(data_start_off, data_start_off + size)
									#if num_img_parts > 1:
										#final_image.append_array(image)
									#pos += 0x10
								#var tga:PackedByteArray = makeTGAHeader(false, 3, 8, 8, width, height)
								#if num_img_parts > 1:
									#final_image = combine_greyscale_data_horizontally(final_image, width, height, num_img_parts)
								#else:
									#final_image = image
								#tga.append_array(palette_data)
								#tga.append_array(final_image)
								#out_file = FileAccess.open(folder_path + "/%s" % file_name + ".TGA", FileAccess.WRITE)
								#out_file.store_buffer(tga)
								#out_file.close()
							else:
								push_error("Unknown BPP %s format in %s" % [bpp, file_name])
							
							print("0x%02X " % num_img_parts + "0x%08X " % dec_data.size() + folder_path + "/%s" % file_name)
							
							buff.clear()
							comp_data.clear()
						else:
							out_file = FileAccess.open(folder_path + "/%s" % file_name, FileAccess.WRITE)
							out_file.store_buffer(dec_data)
							
							print("0x%08X " % mlh_f_start + "0x%08X " % mlh_f_dec_size + folder_path + "/%s" % file_name)
							
							out_file.close()
							comp_data.clear()
				
		in_file.close()
		
	print_rich("[color=green]Finished![/color]")
	
func NFPExtract() -> void:
	var in_file:FileAccess
	var out_file:FileAccess
	var buff:PackedByteArray
	var files:int
	var pos:int
	var last_file_pos:int
	var unk32:int
	var offset:int
	var size:int
	
	for a in range(0, nfp_path.size()):
		in_file = FileAccess.open(nfp_path[a], FileAccess.READ)
		in_file.seek(0x34)
		files = in_file.get_32()
		
		in_file.seek(0x800)
		pos = in_file.get_position()
		last_file_pos = pos
		for b in range(0, files):
			var string_bytes:PackedByteArray
			
			for c in range(0, 0xC):
				string_bytes.append(in_file.get_8())
				
			var file_name:String = string_bytes.get_string_from_ascii()
			string_bytes.clear()
			
			pos = last_file_pos
			
			in_file.seek(pos + 0x18)
			offset = in_file.get_32()
			size = in_file.get_32()
			
			last_file_pos = in_file.get_position()
			
			in_file.seek(offset)
			buff = in_file.get_buffer(size)
			
			out_file = FileAccess.open(folder_path + "/%s" % file_name, FileAccess.WRITE)
			out_file.store_buffer(buff)
			
			out_file.close()
			buff.clear()
			
			pos = last_file_pos
			in_file.seek(pos)
			
			print("0x%08X " % offset + "0x%08X " % size + folder_path + "/%s" % file_name)
		
	print_rich("[color=green]Finished![/color]")
	
