extends Control

@onready var memory_usage: Label = $MemoryUsage
@onready var game_type_selector: OptionButton = $GameTypeSelector
@onready var game_type_text: Label = $GameTypeText
@onready var game_type_sub_text: Label = $GameTypeSubText

enum {FUTAKOI, PIA3} # game types. Note: Only add new entries at the end of this list.
var game_type:int = PIA3

func _ready() -> void:
	#DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	Engine.max_fps = 60
	
	game_type_selector.select(0)
	game_type_text.text = "Choose game format type:"


func _process(_delta: float) -> void:
	var MEM: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	var MEM2: float = Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
	memory_usage.text = str("%.3f MB / %.3f MB" % [MEM * 0.000001, MEM2 * 0.000001])
	
	if game_type_selector.selected == 0:
		game_type_sub_text.text = "Supports 'Futakoijima: Koi to Mizugi no Survival', 'Futakoi' & 'Ichigo 100% Strawberry Diary' games."
		game_type_selector.select(0)
		game_type = FUTAKOI
	elif game_type_selector.selected == 1:
		game_type_sub_text.text = "Supports 'Pia Carrot he Youkoso!! 3: Round Summer'."
		game_type_selector.select(1)
		game_type = PIA3


func _on_game_type_selector_item_selected(index: int) -> void:
	if index == FUTAKOI:
		var next_scene: PackedScene = load("res://src/scenes/AlphaUnit.tscn")
		sceneChanger(next_scene)
	if index == PIA3:
		var next_scene: PackedScene = load("res://src/scenes/AlphaUnit.tscn")
		sceneChanger(next_scene)
		
func sceneChanger(scene: PackedScene) -> void:
	get_tree().change_scene_to_packed(scene)
	return
