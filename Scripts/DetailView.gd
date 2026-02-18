extends Control

var monster: MonsterData
var current_atom: Node2D = null

# Training Logic
var is_training = false
var train_timer = 0.0
var train_interval = 0.2
var min_interval = 0.05

func _ready():
	monster = PlayerData.selected_monster
	if not monster:
		print("Error: No monster selected for Detail View")
		GlobalManager.switch_scene("periodic_table")
		return
	
	update_display()
	
	# Connect Back Button
	var back_btn = find_child("BackButton", true, false)
	if back_btn:
		back_btn.z_index = 10
		if not back_btn.pressed.is_connected(_on_back_button_pressed):
			back_btn.pressed.connect(_on_back_button_pressed)
			
	var train_btn = find_child("TrainButton", true, false)
	if train_btn:
		train_btn.button_down.connect(_on_train_down)
		train_btn.button_up.connect(_on_train_up)
		
	# Connect Stat Upgrade Buttons
	_connect_upgrade_btn("HPUpgradeBtn", "hp")
	_connect_upgrade_btn("AtkUpgradeBtn", "attack")
	_connect_upgrade_btn("DefUpgradeBtn", "defense")
	_connect_upgrade_btn("SpdUpgradeBtn", "speed")

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
			
		update_display()
	else:
		is_training = false

func _on_train_down():
	is_training = true
	train_interval = 0.2 # Reset speed
	perform_training()

func _on_train_up():
	is_training = false
	PlayerData.save_game() # Save only when user releases button

func _connect_upgrade_btn(btn_name: String, stat_type: String):
	var btn = find_child(btn_name, true, false)
	if btn:
		if not btn.pressed.is_connected(_on_upgrade_pressed):
			btn.pressed.connect(func(): _on_upgrade_pressed(stat_type))

func _on_upgrade_pressed(stat_type: String):
	var cost = 5 # Fixed cost for MVP, can scale later
	var current_dust = PlayerData.resources.get("neutron_dust", 0)
	
	if current_dust >= cost:
		PlayerData.add_resource("neutron_dust", -cost)
		
		match stat_type:
			"hp": monster.infused_health += 10
			"attack": monster.infused_attack += 2
			"defense": monster.infused_defense += 2
			"speed": monster.infused_speed += 1
			
		update_display()
		PlayerData.save_game()
	else:
		print("Not enough Neutron Dust!")

func update_display():
	# Find nodes dynamically
	var name_lbl = find_child("NameLabel", true, false)
	var icon_rect = find_child("IconTexture", true, false)
	var number_lbl = find_child("NumberLabel", true, false)
	var level_lbl = find_child("LevelLabel", true, false)
	var xp_bar = find_child("XPBar", true, false)
	
	if name_lbl: name_lbl.text = monster.monster_name
	if icon_rect: 
		icon_rect.texture = monster.texture
		_setup_dynamic_atom(icon_rect)
		
	if number_lbl: number_lbl.text = "Atomic #: %d (%s)" % [monster.atomic_number, monster.symbol]
	if level_lbl: level_lbl.text = "Level: %d" % monster.level
	
	if xp_bar:
		if xp_bar is ProgressBar:
			xp_bar.max_value = monster.xp_to_next_level
			xp_bar.value = monster.current_xp
		else:
			push_error("DetailView Error: The node named 'XPBar' is not a ProgressBar. Please fix it in the scene.")
	
	# Display Stats
	var hp_lbl = find_child("HPLabel", true, false)
	var atk_lbl = find_child("AttackLabel", true, false)
	var def_lbl = find_child("DefenseLabel", true, false)
	var spd_lbl = find_child("SpeedLabel", true, false)
	
	# Helper to format stat text with infusion bonus
	var fmt_stat = func(base, infused):
		if infused > 0:
			return "%d (+%d)" % [base, infused]
		return "%d" % base
	
	if hp_lbl: hp_lbl.text = "HP: " + fmt_stat.call(monster.base_health, monster.infused_health)
	if atk_lbl: atk_lbl.text = "Attack: " + fmt_stat.call(monster.base_attack, monster.infused_attack)
	if def_lbl: def_lbl.text = "Defense: " + fmt_stat.call(monster.base_defense, monster.infused_defense)
	if spd_lbl: spd_lbl.text = "Speed: " + fmt_stat.call(monster.base_speed, monster.infused_speed)

	# Update Button States (Disable if can't afford)
	_update_btn_state("HPUpgradeBtn", "hp")
	_update_btn_state("AtkUpgradeBtn", "attack")
	_update_btn_state("DefUpgradeBtn", "defense")
	_update_btn_state("SpdUpgradeBtn", "speed")

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

func _on_back_button_pressed():
	GlobalManager.switch_scene("periodic_table")

func _update_btn_state(btn_name: String, stat_type: String):
	var btn = find_child(btn_name, true, false)
	if btn:
		var cost = 5
		var current_dust = PlayerData.resources.get("neutron_dust", 0)
		
		btn.disabled = current_dust < cost
		btn.text = "+ (Cost: %d Dust)" % cost
