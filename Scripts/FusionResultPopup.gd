extends PanelContainer

signal claimed

func setup(monster: MonsterData):
	if not monster: return
	
	var name_lbl = find_child("NameLabel", true, false)
	var number_lbl = find_child("NumberLabel", true, false)
	var icon_rect = find_child("IconTexture", true, false)
	var stats_lbl = find_child("StatsLabel", true, false)
	var claim_btn = find_child("ClaimButton", true, false)
	
	if name_lbl: name_lbl.text = monster.monster_name
	if number_lbl: number_lbl.text = "Element #%d (%s)" % [monster.atomic_number, monster.symbol]
	
	if stats_lbl:
		stats_lbl.text = "HP: %d  |  ATK: %d  |  DEF: %d  |  SPD: %d" % [
			monster.base_health, monster.base_attack, monster.base_defense, monster.base_speed
		]
	
	if icon_rect:
		icon_rect.texture = monster.texture
		# Reset size to ensure it centers correctly
		icon_rect.custom_minimum_size = Vector2(200, 200)
		_spawn_atom(icon_rect, monster)
		
	if claim_btn:
		if not claim_btn.pressed.is_connected(_on_claim_pressed):
			claim_btn.pressed.connect(_on_claim_pressed)
	
	# Ensure popup is visible and on top
	visible = true
	z_index = 20
	move_to_front()

func _spawn_atom(parent: Control, monster: MonsterData):
	# Clear existing atoms
	for child in parent.get_children():
		if child is Node2D: child.queue_free()
		
	var atom_script = load("res://Scripts/DynamicAtom.gd")
	var electron_tex = load("res://data/ElectronGlow.tres")
	
	if atom_script and electron_tex:
		var atom = Node2D.new()
		atom.set_script(atom_script)
		atom.atomic_number = monster.atomic_number
		atom.electron_texture = electron_tex
		atom.rotation_speed = 20.0
		
		parent.add_child(atom)
		
		# Center the atom
		atom.position = parent.size / 2.0
		
		# Keep centered if parent resizes
		if not parent.resized.is_connected(func(): atom.position = parent.size / 2.0):
			parent.resized.connect(func(): atom.position = parent.size / 2.0)

func _on_claim_pressed():
	visible = false
	claimed.emit()
