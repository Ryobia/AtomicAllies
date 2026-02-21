extends Control

# This variable will be set by your SceneManager before this scene is displayed.
var current_monster: MonsterData

# --- UI Node References ---
var name_label
var level_label
var player_xp_label
var cost_label
var level_up_button
var number_label
var hp_label
var attack_label
var defense_label
var speed_label
var icon_texture
var moves_container
var class_label
var class_help_icon


func _ready():
	# Find nodes dynamically to avoid path errors
	name_label = find_child("NameLabel", true, false)
	level_label = find_child("LevelLabel", true, false)
	player_xp_label = find_child("PlayerXpLabel", true, false)
	cost_label = find_child("CostLabel", true, false)
	level_up_button = find_child("LevelUpButton", true, false)
	number_label = find_child("NumberLabel", true, false)
	hp_label = find_child("HPLabel", true, false)
	attack_label = find_child("AttackLabel", true, false)
	defense_label = find_child("DefenseLabel", true, false)
	speed_label = find_child("SpeedLabel", true, false)
	icon_texture = find_child("IconTexture", true, false)
	moves_container = find_child("MovesContainer", true, false)
	class_label = find_child("ClassLabel", true, false)
	class_help_icon = find_child("HelpIcon", true, false)
	
	if class_help_icon:
		class_help_icon.theme = GlobalManager.tooltip_theme

	# Fetch the selected monster from global state if not already set
	if not current_monster:
		current_monster = PlayerData.selected_monster

	# This function is called when the scene loads.
	# We assume current_monster has been set by the previous screen.
	if is_instance_valid(current_monster):
		update_ui()
		_setup_atom()
	
	# Connect the button's "pressed" signal to our level-up function.
	if level_up_button:
		level_up_button.pressed.connect(_on_level_up_pressed)
	
	# Listen for global resource changes to keep the UI fresh.
	PlayerData.resource_updated.connect(_on_player_resource_updated)


func update_ui():
	# This function refreshes all the text on the screen.
	if not is_instance_valid(current_monster):
		return
		
	if name_label: name_label.text = current_monster.monster_name
	if level_label: level_label.text = "Level: " + str(current_monster.level)
	if player_xp_label: player_xp_label.text = "Player XP: " + str(PlayerData.resources.get("experience", 0))
	if number_label: number_label.text = "#" + str(current_monster.atomic_number)
	
	if current_monster.has_method("get_current_stats"):
		var stats = current_monster.get_current_stats()
		if hp_label: hp_label.text = "HP: " + str(stats.max_hp)
		if attack_label: attack_label.text = "Attack: " + str(stats.attack)
		if defense_label: defense_label.text = "Defense: " + str(stats.defense)
		if speed_label: speed_label.text = "Speed: " + str(stats.speed)

	if class_label and "group" in current_monster:
		var group_name = AtomicConfig.Group.find_key(current_monster.group)
		if group_name:
			class_label.text = "Class: " + group_name.replace("_", " ").capitalize()
			
			if class_help_icon:
				class_help_icon.tooltip_text = _get_class_description(current_monster.group)

	if moves_container and "moves" in current_monster:
		for child in moves_container.get_children():
			child.queue_free()
			
		for m in current_monster.moves:
			if m:
				var margin = MarginContainer.new()
				margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				margin.add_theme_constant_override("margin_left", 20)
				margin.add_theme_constant_override("margin_right", 20)
				
				var move_rtl = RichTextLabel.new()
				move_rtl.bbcode_enabled = true
				move_rtl.fit_content = true
				move_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				
				var pwr = m.power if "power" in m else 0
				var desc = m.description if "description" in m else ""
				
				var text = "[color=#60fafc][font_size=22]• %s (Pwr: %d)[/font_size][/color]" % [m.name, pwr]
				if desc != "":
					text += " [color=#e6e6e6][font_size=18]%s[/font_size][/color]" % desc
				
				move_rtl.text = text
				margin.add_child(move_rtl)
				moves_container.add_child(margin)
				
				var sep = HSeparator.new()
				sep.modulate = Color("#60fafc")
				sep.modulate.a = 0.3
				moves_container.add_child(sep)
	
	var cost = AtomicConfig.calculate_xp_requirement(current_monster.level)
	if cost_label: cost_label.text = "Cost: " + str(cost) + " XP"
	
	# Automatically disable the button if the player can't afford the upgrade.
	if level_up_button:
		level_up_button.disabled = PlayerData.resources.get("experience", 0) < cost


func _on_level_up_pressed():
	var cost = AtomicConfig.calculate_xp_requirement(current_monster.level)
	
	# Use our new centralized spend_resource function.
	if PlayerData.spend_resource("experience", cost):
		current_monster.level += 1
		update_ui() # Refresh the screen to show the new level and cost.

func _on_player_resource_updated(resource_type: String, _new_amount: int):
	if resource_type == "experience":
		update_ui()

func _setup_atom():
	if not icon_texture or not current_monster: return
	
	# Clear existing atoms
	for child in icon_texture.get_children():
		child.queue_free()
	
	var atom_script = load("res://Scripts/DynamicAtom.gd")
	var electron_tex = load("res://data/ElectronGlow.tres")
	
	if atom_script and electron_tex:
		var atom = Node2D.new()
		atom.set_script(atom_script)
		atom.atomic_number = current_monster.atomic_number
		atom.electron_texture = electron_tex
		atom.rotation_speed = 20.0
		
		# Center the atom in the TextureRect
		atom.position = icon_texture.size / 2
		icon_texture.add_child(atom)

func _get_class_description(group: int) -> String:
	match group:
		AtomicConfig.Group.ALKALI_METAL:
			return "Role: Glass Cannon\nHigh Speed & Attack, Low Defense.\nHighly reactive and volatile."
		AtomicConfig.Group.ALKALINE_EARTH:
			return "Role: Sturdy Tank\nBalanced stats with good Defense.\nA reliable frontline presence."
		AtomicConfig.Group.TRANSITION_METAL:
			return "Role: Bruiser\nHigh HP and steady Damage.\nThe versatile all-rounders."
		AtomicConfig.Group.POST_TRANSITION:
			return "Role: Utility\nBalanced stats.\nSpecializes in supporting allies."
		AtomicConfig.Group.METALLOID:
			return "Role: Disrupter\nFast and utility-focused.\nGood at messing with enemy plans."
		AtomicConfig.Group.NONMETAL:
			return "Role: Combo Primer\nWeak alone, but enables huge reactions.\nEssential for synergy."
		AtomicConfig.Group.HALOGEN:
			return "Role: Assailant\nHigh Speed and Status Effects.\nDeals corrosive damage over time."
		AtomicConfig.Group.NOBLE_GAS:
			return "Role: Pure Wall\nMassive Defense, Low Attack.\nInert and immune to most reactions."
		AtomicConfig.Group.ACTINIDE:
			return "Role: The Nuke\nMassive stats but unstable.\nHigh risk of decay."
		AtomicConfig.Group.LANTHANIDE:
			return "Role: Rare Earth\nHigh Attack and unique properties.\nSimilar to Actinides but more stable."
		_:
			return "Unknown Class properties."
