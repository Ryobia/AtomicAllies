extends Control

var enemy_container
var team_container
var legend_container
var start_btn
var back_btn
var clear_btn

var _selection_popup: PanelContainer
var _target_slot_index: int = -1
var _collection_popup_node: Control = null
var _anim_cache: Dictionary = {} # Cache loaded animations to reduce disk I/O

var team_slot_scene = preload("res://Scenes/TeamSlot.tscn")
var legend_item_scene = preload("res://Scenes/LegendItem.tscn")

func _ready():
	enemy_container = find_child("EnemyContainer", true, false)
	team_container = find_child("TeamContainer", true, false)
	legend_container = find_child("LegendContainer", true, false)
	start_btn = find_child("StartButton", true, false)
	back_btn = find_child("BackButton", true, false)
	clear_btn = find_child("ClearButton", true, false)
	
	if start_btn:
		start_btn.pressed.connect(_on_start_pressed)
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	if clear_btn:
		clear_btn.pressed.connect(_on_clear_team_pressed)
		
	var enemies = _generate_preview_enemies()
	PlayerData.pending_enemy_team = enemies
	_update_enemy_preview(enemies)
	
	# Ensure active team has exactly 6 slots, filling with nulls
	while PlayerData.active_team.size() < 6:
		PlayerData.active_team.append(null)
	while PlayerData.active_team.size() > 6:
		PlayerData.active_team.pop_back()
			
	_update_team_display()
	_populate_legend()

func _generate_preview_enemies() -> Array[MonsterData]:
	var enemies: Array[MonsterData] = []
	var base_enemy = load("res://data/Enemies/NullWalker.tres")
	
	for i in range(3):
		var enemy = base_enemy.duplicate()
		enemies.append(enemy)
	return enemies

func _update_enemy_preview(enemies: Array[MonsterData]):
	if not enemy_container: return
	
	for child in enemy_container.get_children():
		child.queue_free()
		
	for enemy in enemies:
		var icon = TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(100, 100)
		if enemy.icon:
			icon.texture = enemy.icon
		else:
			var color = ColorRect.new()
			color.color = Color.PURPLE
			color.set_anchors_preset(Control.PRESET_FULL_RECT)
			icon.add_child(color)
		enemy_container.add_child(icon)

func _update_team_display():
	if not team_container: return
	
	for child in team_container.get_children():
		child.queue_free()
		
	var display_order = [1, 0, 2, 3, 4, 5]
		
	for team_idx in display_order:
		var monster = PlayerData.active_team[team_idx]
		var slot = team_slot_scene.instantiate()
		team_container.add_child(slot)
		
		var anim_frames = null
		if monster:
			anim_frames = _get_anim_frames(monster.monster_name)
			
		slot.setup(monster, team_idx, _target_slot_index != -1, anim_frames)
		slot.pressed.connect(func(): _on_team_slot_pressed(team_idx))
		
	# Update start button state
	var has_member = false
	for m in PlayerData.active_team:
		if m != null:
			has_member = true
			break
			
	if start_btn:
		start_btn.disabled = not has_member
	if clear_btn:
		clear_btn.disabled = not has_member

func _get_anim_frames(monster_name: String) -> SpriteFrames:
	if _anim_cache.has(monster_name): return _anim_cache[monster_name]
	
	var path = "res://Assets/Animations/" + monster_name.replace(" ", "") + ".tres"
	var frames = null
	if ResourceLoader.exists(path):
		frames = load(path)
	
	_anim_cache[monster_name] = frames
	return frames

func _populate_legend():
	if not legend_container: return
	
	# Optimization: Legend is static, don't rebuild if already populated
	if legend_container.get_child_count() > 0: return
	
	for child in legend_container.get_children():
		child.queue_free()
		
	var descriptions = {
		AtomicConfig.Group.ALKALI_METAL: "Glass Cannon: High Speed & Attack, Low Defense.",
		AtomicConfig.Group.ALKALINE_EARTH: "Sturdy Tank: Balanced stats with good Defense.",
		AtomicConfig.Group.TRANSITION_METAL: "Bruiser: High HP and steady Damage.",
		AtomicConfig.Group.POST_TRANSITION: "Utility: Balanced stats, supports allies.",
		AtomicConfig.Group.METALLOID: "Disrupter: Fast and utility-focused.",
		AtomicConfig.Group.NONMETAL: "Combo Primer: Enables huge reactions.",
		AtomicConfig.Group.HALOGEN: "Assailant: High Speed and Status Effects.",
		AtomicConfig.Group.NOBLE_GAS: "Pure Wall: Massive Defense, Low Attack.",
		AtomicConfig.Group.ACTINIDE: "The Nuke: Massive stats but unstable.",
		AtomicConfig.Group.LANTHANIDE: "Rare Earth: High Attack, unique properties."
	}
	
	for group in AtomicConfig.GROUP_COLORS:
		if group == AtomicConfig.Group.UNKNOWN or group == AtomicConfig.Group.VOID: continue
		
		var item = legend_item_scene.instantiate()
		legend_container.add_child(item)
		item.setup(group, descriptions.get(group, "Unknown properties."))

func _on_team_slot_pressed(index: int):
	_target_slot_index = index
	_show_collection_selector()

func _show_collection_selector():
	if _collection_popup_node: _collection_popup_node.queue_free()
	
	_collection_popup_node = PanelContainer.new()
	_collection_popup_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_collection_popup_node.z_index = 20
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.05, 0.05, 0.1, 0.98)
	_collection_popup_node.add_theme_stylebox_override("panel", bg_style)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 20)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.add_child(main_vbox)
	_collection_popup_node.add_child(margin)
	
	# Header
	var header = Label.new()
	header.text = "Select Monster for Slot"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 40)
	main_vbox.add_child(header)
	
	# Scroll Area
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)
	
	var grid = GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 15)
	grid.add_theme_constant_override("v_separation", 15)
	scroll.add_child(grid)
	
	# Populate Grid
	for monster in PlayerData.owned_monsters:
		# Skip if already in team (unless it's the one we are replacing, but simpler to just hide all active)
		if monster in PlayerData.active_team:
			continue
			
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 150)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.text = monster.monster_name + "\nLv." + str(monster.level)
		
		if monster.icon:
			btn.icon = monster.icon
			btn.expand_icon = true
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			
		# Style
		var style = StyleBoxFlat.new()
		var bg_color = Color(0.1, 0.1, 0.1, 1)
		if "group" in monster:
			bg_color = AtomicConfig.GROUP_COLORS.get(monster.group, bg_color)
		style.bg_color = bg_color.darkened(0.6)
		style.set_corner_radius_all(8)
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		
		btn.add_theme_font_size_override("font_size", 24)
		btn.pressed.connect(func(): _show_mini_detail(monster))
		grid.add_child(btn)
		
	# Footer Buttons
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(0, 80)
	cancel_btn.add_theme_font_size_override("font_size", 32)
	cancel_btn.pressed.connect(_collection_popup_node.queue_free)
	main_vbox.add_child(cancel_btn)
	
	# If slot is not empty, add a "Clear Slot" button
	if _target_slot_index != -1 and PlayerData.active_team[_target_slot_index] != null:
		var remove_btn = Button.new()
		remove_btn.text = "Remove from Squad"
		remove_btn.custom_minimum_size = Vector2(0, 80)
		remove_btn.add_theme_font_size_override("font_size", 32)
		remove_btn.pressed.connect(func():
			PlayerData.active_team[_target_slot_index] = null
			_update_team_display()
			_collection_popup_node.queue_free()
		)
		main_vbox.add_child(remove_btn)
	
	add_child(_collection_popup_node)

func _show_mini_detail(monster: MonsterData):
	if _selection_popup and is_instance_valid(_selection_popup): _selection_popup.queue_free()
	
	_selection_popup = PanelContainer.new()
	_selection_popup.set_anchors_preset(Control.PRESET_CENTER)
	_selection_popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_selection_popup.grow_vertical = Control.GROW_DIRECTION_BOTH
	_selection_popup.custom_minimum_size = Vector2(600, 400)
	_selection_popup.z_index = 30 # Ensure it's on top of collection popup
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.95)
	style.border_width_left = 2; style.border_width_top = 2
	style.border_width_right = 2; style.border_width_bottom = 2
	style.border_color = Color("#60fafc")
	_selection_popup.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	margin.add_child(vbox)
	_selection_popup.add_child(margin)
	
	var title = Label.new()
	title.text = monster.monster_name + " (Lv. " + str(monster.level) + ")"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)
	
	var stats = monster.get_current_stats()
	var stats_lbl = Label.new()
	stats_lbl.text = "HP: %d | ATK: %d | DEF: %d | SPD: %d" % [stats.max_hp, stats.attack, stats.defense, stats.speed]
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_lbl)
	
	var moves_lbl = Label.new()
	moves_lbl.text = "Moves:"
	vbox.add_child(moves_lbl)
	for m in monster.moves:
		var m_lbl = Label.new()
		m_lbl.text = "- " + m.name + " (" + str(m.power) + " Pwr)"
		m_lbl.add_theme_color_override("font_color", Color("#a0a0a0"))
		vbox.add_child(m_lbl)
		
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 40)
	vbox.add_child(hbox)
	
	var back_btn_popup = Button.new()
	back_btn_popup.text = "Back"
	back_btn_popup.custom_minimum_size = Vector2(150, 60)
	back_btn_popup.pressed.connect(_selection_popup.queue_free)
	hbox.add_child(back_btn_popup)
	
	var add_btn = Button.new()
	add_btn.text = "Add to Squad"
	add_btn.custom_minimum_size = Vector2(200, 60)
	add_btn.pressed.connect(func(): _confirm_assignment(monster))
	hbox.add_child(add_btn)
	
	add_child(_selection_popup)

func _confirm_assignment(monster: MonsterData):
	if _target_slot_index != -1:
		PlayerData.active_team[_target_slot_index] = monster
		
	if _selection_popup and is_instance_valid(_selection_popup): _selection_popup.queue_free()
	if _collection_popup_node and is_instance_valid(_collection_popup_node): _collection_popup_node.queue_free()
	
	_update_team_display()

func _on_clear_team_pressed():
	for i in range(PlayerData.active_team.size()):
		PlayerData.active_team[i] = null
	_update_team_display()

func _on_start_pressed():
	if start_btn.disabled:
		return
	GlobalManager.switch_scene("battle")

func _on_back_pressed():
	GlobalManager.switch_scene("main_menu")


func _on_back_button_pressed():
	GlobalManager.switch_scene("main_menu")
