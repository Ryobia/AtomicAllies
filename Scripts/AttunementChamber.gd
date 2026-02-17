extends Control

var monster: MonsterData
var current_atom: Node2D

# UI References
var level_label
var xp_bar
var stats_label
var train_btn
var icon_rect

# Training Logic
var is_training = false
var train_timer = 0.0
var train_interval = 0.2
var min_interval = 0.05

func _ready():
	monster = PlayerData.selected_monster
	if not monster:
		GlobalManager.switch_scene("periodic_table")
		return
	
	# Find nodes
	level_label = find_child("LevelLabel", true, false)
	xp_bar = find_child("XPBar", true, false)
	stats_label = find_child("StatsLabel", true, false)
	train_btn = find_child("TrainButton", true, false)
	icon_rect = find_child("IconTexture", true, false)
	
	var back_btn = find_child("BackButton", true, false)
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
		
	if train_btn:
		train_btn.button_down.connect(_on_train_down)
		train_btn.button_up.connect(_on_train_up)
	
	if icon_rect:
		icon_rect.texture = monster.texture
		_setup_dynamic_atom(icon_rect)
		
	update_ui()

func _process(delta):
	if is_training:
		train_timer -= delta
		if train_timer <= 0:
			perform_training()
			train_timer = train_interval
			# Accelerate the training speed the longer you hold
			train_interval = max(min_interval, train_interval * 0.9)

func perform_training():
	var xp_available = PlayerData.resources.get("experience", 0)
	
	if xp_available > 0:
		PlayerData.add_resource("experience", -1)
		monster.current_xp += 1
		
		if monster.current_xp >= monster.xp_to_next_level:
			monster.current_xp -= monster.xp_to_next_level
			monster.level += 1
			# Optional: Play a "Level Up" sound here
			
		update_ui()
	else:
		is_training = false

func _on_train_down():
	is_training = true
	train_interval = 0.2 # Reset speed
	perform_training()

func _on_train_up():
	is_training = false
	PlayerData.save_game() # Save only when user releases button

func update_ui():
	if level_label: level_label.text = "Level %d" % monster.level
	
	if xp_bar:
		xp_bar.max_value = monster.xp_to_next_level
		xp_bar.value = monster.current_xp
		
	if stats_label:
		stats_label.text = "HP: %d\nATK: %d\nDEF: %d\nSPD: %d" % [
			monster.base_health, monster.base_attack, monster.base_defense, monster.base_speed
		]

func _setup_dynamic_atom(parent_rect: TextureRect):
	var atom_script = load("res://Scripts/DynamicAtom.gd")
	var electron_tex = load("res://data/ElectronGlow.tres")
	if atom_script and electron_tex:
		current_atom = Node2D.new()
		current_atom.set_script(atom_script)
		current_atom.atomic_number = monster.atomic_number
		current_atom.electron_texture = electron_tex
		parent_rect.add_child(current_atom)

func _on_back_pressed():
	GlobalManager.switch_scene("detail_view")