extends PanelContainer

signal claimed

var display_sprite: AnimatedSprite2D = null
var anim_sequence: Array = ["idle", "move", "attack"]
var current_anim_idx: int = 0

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

func populate_details(monster: MonsterData):
	var vbox = find_child("VBoxContainer", true, false)
	if not vbox: return
	
	var number_lbl = find_child("NumberLabel", true, false)
	var ok_btn = find_child("OkButton", true, false)
	
	if number_lbl: number_lbl.text = "Element #%d" % monster.atomic_number
	
	var stats_box = find_child("StatsBox", true, false)
	if not stats_box:
		stats_box = VBoxContainer.new()
		stats_box.name = "StatsBox"
		stats_box.add_theme_constant_override("separation", 10)
		vbox.add_child(stats_box)
		if ok_btn: vbox.move_child(stats_box, ok_btn.get_index())
		
	for child in stats_box.get_children():
		child.queue_free()
		
	var class_lbl = Label.new()
	var group_name = "Unknown"
	if "group" in monster:
		var key = AtomicConfig.Group.find_key(monster.group)
		if key: group_name = key.replace("_", " ").capitalize()
		class_lbl.add_theme_color_override("font_color", AtomicConfig.GROUP_COLORS.get(monster.group, Color.WHITE))
	class_lbl.text = "Class: %s" % group_name
	class_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_lbl.add_theme_font_size_override("font_size", 54)
	stats_box.add_child(class_lbl)
	
	var unique_move = null
	if AtomicConfig.UNIQUE_MOVES.has(monster.atomic_number):
		unique_move = AtomicConfig.UNIQUE_MOVES[monster.atomic_number]
		
	if unique_move:
		var move_lbl = RichTextLabel.new()
		move_lbl.bbcode_enabled = true
		move_lbl.fit_content = true
		move_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var type_color = "#ff4d4d" if unique_move.type == "Physical" else ("#60fafc" if unique_move.type == "Special" else "#2ecc71")
		move_lbl.text = "[center]Signature Move: [color=%s]%s[/color]\n[font_size=36][color=#cccccc]%s[/color][/font_size][/center]" % [type_color, unique_move.name, unique_move.description]
		move_lbl.add_theme_font_size_override("normal_font_size", 46)
		stats_box.add_child(move_lbl)

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

func setup_sprite_cycling(sprite: AnimatedSprite2D):
	display_sprite = sprite
	current_anim_idx = 0
	
	# Clear previous connections just in case the popup is reused
	for c in display_sprite.animation_finished.get_connections():
		display_sprite.animation_finished.disconnect(c["callable"])
		
	display_sprite.animation_finished.connect(_play_next_anim)
	_play_next_anim()

func _play_next_anim():
	if not is_instance_valid(display_sprite) or not display_sprite.sprite_frames:
		return
		
	var next_anim = anim_sequence[current_anim_idx]
	
	# Fallback safely if the monster doesn't have an attack/move animation
	if not display_sprite.sprite_frames.has_animation(next_anim):
		if display_sprite.sprite_frames.has_animation("idle"):
			next_anim = "idle"
		elif display_sprite.sprite_frames.has_animation("default"):
			next_anim = "default"
		else:
			var anims = display_sprite.sprite_frames.get_animation_names()
			if anims.size() > 0:
				next_anim = anims[0]
				
	display_sprite.play(next_anim)
	
	# Queue up the next sequence index
	current_anim_idx = (current_anim_idx + 1) % anim_sequence.size()

func _on_claim_pressed():
	visible = false
	claimed.emit()
