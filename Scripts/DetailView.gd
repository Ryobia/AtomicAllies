extends Control

var monster: MonsterData
var current_atom: Node2D = null

func _ready():
	monster = PlayerData.selected_monster
	if not monster:
		print("Error: No monster selected for Detail View")
		GlobalManager.switch_scene("collection")
		return
	
	update_display()
	
	# Connect Back Button
	var back_btn = find_child("BackButton", true, false)
	if back_btn:
		back_btn.z_index = 10
		back_btn.move_to_front()
		if not back_btn.pressed.is_connected(_on_back_pressed):
			back_btn.pressed.connect(_on_back_pressed)

func update_display():
	# Find nodes dynamically
	var name_lbl = find_child("NameLabel", true, false)
	var icon_rect = find_child("IconTexture", true, false)
	var number_lbl = find_child("NumberLabel", true, false)
	var level_lbl = find_child("LevelLabel", true, false)
	
	if name_lbl: name_lbl.text = monster.monster_name
	if icon_rect: 
		icon_rect.texture = monster.texture
		_setup_dynamic_atom(icon_rect)
		
	if number_lbl: number_lbl.text = "Atomic #: %d (%s)" % [monster.atomic_number, monster.symbol]
	if level_lbl: level_lbl.text = "Level: %d" % monster.level
	
	# Display Stats
	var hp_lbl = find_child("HPLabel", true, false)
	var atk_lbl = find_child("AttackLabel", true, false)
	var def_lbl = find_child("DefenseLabel", true, false)
	var spd_lbl = find_child("SpeedLabel", true, false)
	
	if hp_lbl: hp_lbl.text = "HP: %d" % monster.base_health
	if atk_lbl: atk_lbl.text = "Attack: %d" % monster.base_attack
	if def_lbl: def_lbl.text = "Defense: %d" % monster.base_defense
	if spd_lbl: spd_lbl.text = "Speed: %d" % monster.base_speed

func _setup_dynamic_atom(parent_rect: TextureRect):
	# Clear previous atom if it exists
	if current_atom:
		current_atom.queue_free()
		current_atom = null
	
	var atom_script = load("res://Scripts/DynamicAtom.gd")
	var electron_tex = load("res://data/ElectronGlow.tres")
	
	if atom_script and electron_tex:
		current_atom = Node2D.new()
		current_atom.set_script(atom_script)
		current_atom.atomic_number = monster.atomic_number
		current_atom.electron_texture = electron_tex
		current_atom.rotation_speed = monster.base_speed * 0.5 # Lighter elements spin faster!
		
		parent_rect.add_child(current_atom)
		
		# Center the atom. Connect to resized to keep it centered.
		var update_pos = func():
			if is_instance_valid(current_atom) and is_instance_valid(parent_rect):
				current_atom.position = parent_rect.size / 2.0
		
		if not parent_rect.resized.is_connected(update_pos):
			parent_rect.resized.connect(update_pos)
		
		# Initial position
		update_pos.call()

func _on_back_pressed():
	GlobalManager.switch_scene("collection")
