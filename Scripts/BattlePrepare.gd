extends Control

var enemy_container
var team_container
var legend_container
var start_btn
var back_btn
var clear_btn
var enemy_intel_label

@export var icon_physical: Texture2D
@export var icon_special: Texture2D
@export var icon_hostile: Texture2D
@export var icon_friendly: Texture2D

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
	enemy_intel_label = find_child("EnemyIntelLabel", true, false)
	
	if start_btn:
		start_btn.pressed.connect(_on_start_pressed)
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	if clear_btn:
		clear_btn.pressed.connect(_on_clear_team_pressed)
		
	var resource_header = find_child("ResourceHeader", true, false)
	if resource_header:
		resource_header.visible = false
		
	if enemy_intel_label:
		var level_val = PlayerData.current_campaign_level
		var suffix = ""
		if CampaignManager and CampaignManager.is_rogue_run:
			level_val = int(max(1, CampaignManager.current_run_target_z / 2)) + (CampaignManager.current_run_wave - 1)
			suffix = " - Wave %d/%d" % [CampaignManager.current_run_wave, CampaignManager.max_run_waves]
			
		enemy_intel_label.text = "Enemy Intel (Stage %d)%s" % [level_val, suffix]
		
	var enemies = []
	if not PlayerData.pending_enemy_team.is_empty():
		enemies = PlayerData.pending_enemy_team
	else:
		enemies = _generate_preview_enemies()
		
	PlayerData.pending_enemy_team = enemies
	_update_enemy_preview(enemies)
	
	# Ensure active team has exactly 6 slots, filling with nulls
	while PlayerData.active_team.size() < 6:
		PlayerData.active_team.append(null)
	while PlayerData.active_team.size() > 6:
		PlayerData.active_team.pop_back()
			
	_update_team_display()
	_populate_legend()
	
	# Trigger tutorial check (Wait for layout to settle)
	if TutorialManager:
		await get_tree().process_frame
		await get_tree().process_frame
		TutorialManager.check_tutorial_progress()

func _generate_preview_enemies() -> Array[MonsterData]:
	if CampaignManager:
		return CampaignManager.generate_level_encounter(PlayerData.current_campaign_level)
	
	var enemies: Array[MonsterData] = []
	var base_enemy = load("res://data/Enemies/NullGrunt.tres")
	
	for i in range(3):
		var enemy = base_enemy.duplicate()
		enemies.append(enemy)
	return enemies

func _update_enemy_preview(enemies: Array[MonsterData]):
	if not enemy_container: return
	
	for child in enemy_container.get_children():
		child.queue_free()
		
	for enemy in enemies:
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		enemy_container.add_child(vbox)
		
		var icon_container = Control.new()
		icon_container.custom_minimum_size = Vector2(250, 250)
		vbox.add_child(icon_container)
		
		var anim_frames = _get_anim_frames(enemy)
		
		if anim_frames:
			var sprite = AnimatedSprite2D.new()
			sprite.sprite_frames = anim_frames
			
			var anim_to_play = "idle"
			if not anim_frames.has_animation(anim_to_play):
				if anim_frames.has_animation("default"):
					anim_to_play = "default"
				else:
					var anims = anim_frames.get_animation_names()
					if anims.size() > 0:
						anim_to_play = anims[0]
			
			sprite.play(anim_to_play)
			sprite.position = icon_container.custom_minimum_size / 2
			sprite.flip_h = true # Enemies face left
			
			var tex = sprite.sprite_frames.get_frame_texture(anim_to_play, 0)
			if tex:
				var s = 250.0 / float(tex.get_height())
				sprite.scale = Vector2(s, s)
			icon_container.add_child(sprite)
		elif enemy.icon:
			var icon = TextureRect.new()
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.set_anchors_preset(Control.PRESET_FULL_RECT)
			icon.texture = enemy.icon
			icon_container.add_child(icon)
		else:
			var color = ColorRect.new()
			color.color = Color.PURPLE
			color.set_anchors_preset(Control.PRESET_FULL_RECT)
			icon_container.add_child(color)
		
		var name_lbl = Label.new()
		name_lbl.text = enemy.monster_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 32)
		name_lbl.add_theme_color_override("font_color", Color("#ff4d4d")) # Red for enemies
		name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		name_lbl.add_theme_constant_override("outline_size", 4)
		vbox.add_child(name_lbl)

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
			anim_frames = _get_anim_frames(monster)
			
		slot.setup(monster, team_idx, _target_slot_index != -1, anim_frames)
		slot.pressed.connect(func(): _on_team_slot_pressed(team_idx))
		
		if monster and monster.stability >= 100:
			var panel_style = slot.get_theme_stylebox("panel", "PanelContainer")
			if panel_style:
				var mastery_style = panel_style.duplicate()
				mastery_style.border_width_left = 4
				mastery_style.border_width_top = 4
				mastery_style.border_width_right = 4
				mastery_style.border_width_bottom = 4
				mastery_style.border_color = Color("#ffd700") # Gold
				slot.add_theme_stylebox_override("panel", mastery_style)
		
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

	# Tutorial Hook: Check if we can advance
	if TutorialManager:
		_check_tutorial_advancement()

func _get_anim_frames(monster: MonsterData) -> SpriteFrames:
	if _anim_cache.has(monster.monster_name): return _anim_cache[monster.monster_name]
	
	var anim_name = monster.monster_name.replace(" ", "")
	if "animation_override" in monster and monster.animation_override != "":
		anim_name = monster.animation_override
		
	var path = "res://Assets/Animations/" + anim_name + ".tres"
	var frames = null
	if ResourceLoader.exists(path):
		frames = load(path)
	
	_anim_cache[monster.monster_name] = frames
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
		if group >= AtomicConfig.Group.UNKNOWN: continue
		
		var item = legend_item_scene.instantiate()
		legend_container.add_child(item)
		item.setup(group, descriptions.get(group, "Unknown properties."))

func _on_team_slot_pressed(index: int):
	_target_slot_index = index
	
	# Tutorial: Advance from ASSIGN steps when slot is clicked
	if TutorialManager:
		var step = PlayerData.tutorial_step
		if step == TutorialManager.Step.ASSIGN_VANGUARD and index == 0:
			TutorialManager.advance_step() # Goes to SELECT_HELIUM
			# Note: _show_collection_selector is called below, which handles the highlight
		elif step == TutorialManager.Step.INSPECT_HELIUM and index == 0:
			TutorialManager.advance_step() # Goes to CLOSE_INSPECT
		elif step == TutorialManager.Step.ASSIGN_FLANK and (index == 1 or index == 2):
			TutorialManager.advance_step() # Goes to SELECT_HYDROGEN

	var monster = PlayerData.active_team[index]
	if monster:
		_show_mini_detail(monster, true)
	else:
		_show_collection_selector()

func _check_tutorial_advancement():
	var step = PlayerData.tutorial_step
	
	if step == TutorialManager.Step.ASSIGN_VANGUARD:
		# Check if Vanguard (Index 0) is filled
		if PlayerData.active_team[0] != null:
			# Don't advance yet, wait for specific monster check in _confirm_assignment
			pass
			
	elif step == TutorialManager.Step.ASSIGN_FLANK:
		# Check if at least one Flank (Index 1 or 2) is filled
		if PlayerData.active_team[1] != null or PlayerData.active_team[2] != null:
			pass

func _show_collection_selector():
	if _collection_popup_node: _collection_popup_node.queue_free()
	
	_collection_popup_node = PanelContainer.new()
	_collection_popup_node.anchor_left = 0.05
	_collection_popup_node.anchor_right = 0.95
	_collection_popup_node.anchor_top = 0.15
	_collection_popup_node.anchor_bottom = 0.75
	_collection_popup_node.z_index = 20
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color("#010813")
	bg_style.bg_color.a = 0.7
	bg_style.set_corner_radius_all(12)
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
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	
	main_vbox.add_child(scroll)
	
	var grid = GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 15)
	grid.add_theme_constant_override("v_separation", 15)
	scroll.add_child(grid)
	
	# Reset button states when scrolling starts (fixes stuck press states)
	scroll.scroll_started.connect(func():
		for child in grid.get_children():
			child.modulate = Color.WHITE
	)
	
	# Populate Grid
	for monster in PlayerData.owned_monsters:
		# Tutorial Filtering: Only show relevant monster for the step
		if TutorialManager:
			var step = PlayerData.tutorial_step
			# Force Helium for Vanguard assignment too, not just the SELECT_HELIUM step
			if step == TutorialManager.Step.ASSIGN_VANGUARD:
				if monster.atomic_number != 2: continue
				
			if step == TutorialManager.Step.SELECT_HELIUM:
				if monster.atomic_number != 2: continue
			elif step == TutorialManager.Step.SELECT_HYDROGEN:
				if monster.atomic_number != 1: continue
				# Also skip if already assigned (though active_team check handles this)
		
		var current_time = int(Time.get_unix_time_from_system())
		var is_fatigued = monster.fatigue_expiry > current_time
		
		# Skip if already in team (unless it's the one we are replacing, but simpler to just hide all active)
		if monster in PlayerData.active_team:
			continue
			
		var btn = PanelContainer.new()
		btn.custom_minimum_size = Vector2(0, 220)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.mouse_filter = Control.MOUSE_FILTER_PASS # Allow scrolling to pass through
		
		# Custom Layout for Mobile Friendly Icon
		var btn_margin = MarginContainer.new()
		btn_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn_margin.add_theme_constant_override("margin_left", 10)
		btn_margin.add_theme_constant_override("margin_right", 10)
		btn_margin.add_theme_constant_override("margin_top", 10)
		btn_margin.add_theme_constant_override("margin_bottom", 10)
		btn.add_child(btn_margin)
		
		var btn_vbox = VBoxContainer.new()
		btn_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn_margin.add_child(btn_vbox)
		
		var icon_rect = null
		if monster.icon:
			icon_rect = TextureRect.new()
			icon_rect.texture = monster.icon
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
			icon_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn_vbox.add_child(icon_rect)
		else:
			var spacer = Control.new()
			spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn_vbox.add_child(spacer)
			
		var lbl = Label.new()
		lbl.text = monster.monster_name
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_color_override("font_color", Color("#010813"))
		lbl.add_theme_font_size_override("font_size", 44)
		lbl.add_theme_color_override("font_outline_color", Color("#010813").darkened(0.5))
		lbl.add_theme_constant_override("outline_size", 5)
		btn_vbox.add_child(lbl)
		
		if is_fatigued:
			# Dim the visual elements, but NOT the container (so overlays stay bright)
			if icon_rect: icon_rect.modulate = Color(0.5, 0.5, 0.5, 0.8)
			lbl.modulate = Color(0.5, 0.5, 0.5, 0.8)
			
			var time_left = monster.fatigue_expiry - current_time
			var mins = time_left / 60
			var secs = time_left % 60
			var fatigue_lbl = Label.new()
			fatigue_lbl.text = "Fatigued: %02d:%02d" % [mins, secs]
			fatigue_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			fatigue_lbl.add_theme_color_override("font_color", Color("#ff4d4d"))
			fatigue_lbl.add_theme_font_size_override("font_size", 48)
			fatigue_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
			fatigue_lbl.add_theme_constant_override("outline_size", 8)
			btn_vbox.add_child(fatigue_lbl)
			
		# Style
		var bg_color = Color(0.1, 0.1, 0.1, 1)
		if "group" in monster:
			bg_color = AtomicConfig.GROUP_COLORS.get(monster.group, bg_color)
			
		var gradient = Gradient.new()
		gradient.set_color(0, bg_color)
		gradient.set_color(1, bg_color.darkened(0.5))
		
		var grad_tex = GradientTexture2D.new()
		grad_tex.gradient = gradient
		grad_tex.fill_from = Vector2(0, 0)
		grad_tex.fill_to = Vector2(0, 1)
		
		var style = StyleBoxTexture.new()
		style.texture = grad_tex
		btn.add_theme_stylebox_override("panel", style)
		
		if monster.stability >= 100:
			var border = ReferenceRect.new()
			border.name = "MasteryBorder"
			border.border_color = Color("#ffd700")
			border.border_width = 4.0
			border.editor_only = false
			border.set_anchors_preset(Control.PRESET_FULL_RECT)
			border.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(border)
		
		# Manual Input Handling for better scroll feel
		if is_fatigued:
			# Do not dim the whole button, visuals are already dimmed above
			pass
		else:
			btn.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
					if event.pressed:
						btn.modulate = Color(0.7, 0.7, 0.7)
					else:
						btn.modulate = Color.WHITE
						if Rect2(Vector2.ZERO, btn.size).has_point(event.position):
							_confirm_assignment(monster)
			)
		
		grid.add_child(btn)
		
		# Add Coolant Button overlay if fatigued
		if is_fatigued:
			var coolant_count = PlayerData.get_item_count("coolant_gel")
			var cool_btn = Button.new()
			cool_btn.text = "Use Coolant (%d)" % coolant_count
			if coolant_count == 0:
				cool_btn.text = "Buy Coolant (100 Dust)"
				
			cool_btn.custom_minimum_size = Vector2(0, 60)
			cool_btn.size_flags_vertical = Control.SIZE_SHRINK_END
			
			var c_style = StyleBoxFlat.new()
			c_style.bg_color = Color("#60fafc")
			c_style.set_corner_radius_all(4)
			cool_btn.add_theme_font_size_override("font_size", 32)
			cool_btn.add_theme_stylebox_override("normal", c_style)
			cool_btn.add_theme_stylebox_override("hover", c_style)
			cool_btn.add_theme_stylebox_override("pressed", c_style)
			cool_btn.add_theme_color_override("font_color", Color("#010813"))
			
			cool_btn.pressed.connect(func(): _on_use_coolant_in_prep(monster))
			
			# Add to the button's internal container (btn is a PanelContainer)
			# We need to find the VBox inside btn created above
			var internal_vbox = btn.get_child(0).get_child(0) # Margin -> VBox
			internal_vbox.add_child(cool_btn)
		
		# Tutorial Highlight
		if TutorialManager:
			var step = PlayerData.tutorial_step
			if step == TutorialManager.Step.SELECT_HELIUM and monster.atomic_number == 2:
				TutorialManager.show_instruction("Select Helium. Its Noble Gas properties make it an excellent tank.", btn, "talk")
				TutorialManager.current_target_node = btn # Ensure highlight tracks this button
			elif step == TutorialManager.Step.SELECT_HYDROGEN and monster.atomic_number == 1:
				TutorialManager.show_instruction("Select Hydrogen. As a Nonmetal, it can prime reactions.", btn, "talk")
		
	# Footer Buttons
	var footer_style = StyleBoxFlat.new()
	footer_style.bg_color = Color("#010813")
	footer_style.set_corner_radius_all(8)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(0, 80)
	cancel_btn.add_theme_font_size_override("font_size", 32)
	cancel_btn.add_theme_color_override("font_color", Color("#60fafc"))
	cancel_btn.add_theme_stylebox_override("normal", footer_style)
	cancel_btn.add_theme_stylebox_override("hover", footer_style)
	cancel_btn.add_theme_stylebox_override("pressed", footer_style)
	cancel_btn.pressed.connect(_collection_popup_node.queue_free)
	main_vbox.add_child(cancel_btn)
	
	# If slot is not empty, add a "Clear Slot" button
	if _target_slot_index != -1 and PlayerData.active_team[_target_slot_index] != null:
		var remove_btn = Button.new()
		remove_btn.text = "Remove from Squad"
		remove_btn.custom_minimum_size = Vector2(0, 80)
		remove_btn.add_theme_font_size_override("font_size", 32)
		remove_btn.add_theme_color_override("font_color", Color("#60fafc"))
		remove_btn.add_theme_stylebox_override("normal", footer_style)
		remove_btn.add_theme_stylebox_override("hover", footer_style)
		remove_btn.add_theme_stylebox_override("pressed", footer_style)
		remove_btn.pressed.connect(func():
			PlayerData.active_team[_target_slot_index] = null
			_update_team_display()
			_collection_popup_node.queue_free()
		)
		main_vbox.add_child(remove_btn)
	
	add_child(_collection_popup_node)
	
	# Animate popup in (Fade)
	_collection_popup_node.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(_collection_popup_node, "modulate:a", 1.0, 0.2)

func _on_use_coolant_in_prep(monster: MonsterData):
	var count = PlayerData.get_item_count("coolant_gel")
	if count > 0:
		if PlayerData.consume_item("coolant_gel", 1):
			monster.fatigue_expiry = 0
			PlayerData.save_game()
			_show_collection_selector() # Refresh UI
	else:
		# Buy logic
		if PlayerData.spend_resource("neutron_dust", 100):
			PlayerData.add_item("coolant_gel", 1)
			# Auto-use after buying for convenience
			_on_use_coolant_in_prep(monster)

func _show_mini_detail(monster: MonsterData, is_squad_member: bool = false):
	if _selection_popup and is_instance_valid(_selection_popup): _selection_popup.queue_free()
	
	_selection_popup = PanelContainer.new()
	_selection_popup.set_anchors_preset(Control.PRESET_CENTER)
	_selection_popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_selection_popup.grow_vertical = Control.GROW_DIRECTION_BOTH
	_selection_popup.custom_minimum_size = Vector2(800, 700)
	_selection_popup.z_index = 30 # Ensure it's on top of collection popup
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#010813")
	style.bg_color.a = 0.98
	style.border_width_left = 3; style.border_width_top = 3
	style.border_width_right = 3; style.border_width_bottom = 3
	style.border_color = Color("#60fafc")
	style.set_corner_radius_all(16)
	_selection_popup.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 25)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	margin.add_child(vbox)
	_selection_popup.add_child(margin)
	
	var title = Label.new()
	title.text = monster.monster_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("#60fafc"))
	vbox.add_child(title)
	
	if "group" in monster:
		var type_lbl = Label.new()
		var group_name = AtomicConfig.Group.find_key(monster.group).replace("_", " ").capitalize()
		type_lbl.text = group_name
		type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		type_lbl.add_theme_font_size_override("font_size", 32)
		var type_color = AtomicConfig.GROUP_COLORS.get(monster.group, Color.WHITE)
		type_lbl.add_theme_color_override("font_color", type_color)
		vbox.add_child(type_lbl)
	
	# Stats Row
	var stats_hbox = HBoxContainer.new()
	stats_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_hbox.add_theme_constant_override("separation", 50)
	vbox.add_child(stats_hbox)
	
	var stats = monster.get_current_stats()
	var stat_list = [
		{"name": "HP", "val": stats.max_hp},
		{"name": "ATK", "val": stats.attack},
		{"name": "DEF", "val": stats.defense},
		{"name": "SPD", "val": stats.speed}
	]
	
	for s in stat_list:
		var s_vbox = VBoxContainer.new()
		s_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
		var val_lbl = Label.new()
		val_lbl.text = str(s.val)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_lbl.add_theme_font_size_override("font_size", 42)
		val_lbl.add_theme_color_override("font_color", Color.WHITE)
		s_vbox.add_child(val_lbl)
		
		var name_lbl = Label.new()
		name_lbl.text = s.name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 24)
		name_lbl.add_theme_color_override("font_color", Color("#60fafc"))
		s_vbox.add_child(name_lbl)
		
		stats_hbox.add_child(s_vbox)
	
	# Moves Section
	var moves_lbl = Label.new()
	moves_lbl.text = "Moves:"
	moves_lbl.add_theme_font_size_override("font_size", 32)
	moves_lbl.add_theme_color_override("font_color", Color("#60fafc"))
	vbox.add_child(moves_lbl)
	
	var moves_vbox = VBoxContainer.new()
	moves_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	moves_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	moves_vbox.add_theme_constant_override("separation", 15)
	vbox.add_child(moves_vbox)
	
	var moves_list = monster.moves
	if moves_list.is_empty() and "group" in monster:
		moves_list = AtomicConfig.GROUP_MOVES.get(monster.group, [])
	
	for m in moves_list:
		var m_panel = PanelContainer.new()
		var m_style = StyleBoxFlat.new()
		m_style.bg_color = Color(0.1, 0.1, 0.1, 0.5)
		m_style.set_corner_radius_all(8)
		m_panel.add_theme_stylebox_override("panel", m_style)
		moves_vbox.add_child(m_panel)
		
		var m_margin = MarginContainer.new()
		m_margin.add_theme_constant_override("margin_left", 15)
		m_margin.add_theme_constant_override("margin_right", 15)
		m_margin.add_theme_constant_override("margin_top", 10)
		m_margin.add_theme_constant_override("margin_bottom", 10)
		m_panel.add_child(m_margin)
		
		var m_content = VBoxContainer.new()
		m_margin.add_child(m_content)
		
		var row1 = HBoxContainer.new()
		row1.add_theme_constant_override("separation", 15)
		m_content.add_child(row1)
		
		var type_badge = _create_move_type_badge(m.get("type", "Physical"))
		row1.add_child(type_badge)
		
		var m_name = Label.new()
		m_name.text = m.name
		m_name.add_theme_font_size_override("font_size", 28)
		m_name.add_theme_color_override("font_color", Color.WHITE)
		row1.add_child(m_name)
		
		var m_pwr = Label.new()
		m_pwr.text = "Pwr: " + str(m.power)
		m_pwr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m_pwr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		m_pwr.add_theme_font_size_override("font_size", 24)
		m_pwr.add_theme_color_override("font_color", Color("#a0a0a0"))
		row1.add_child(m_pwr)
		
		var m_desc = Label.new()
		var desc_text = m.get("description")
		m_desc.text = desc_text if desc_text else "No description available."
		m_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		m_desc.add_theme_font_size_override("font_size", 22)
		m_desc.add_theme_color_override("font_color", Color("#cccccc"))
		m_content.add_child(m_desc)
		
	# Footer Buttons
	var footer_style = StyleBoxFlat.new()
	footer_style.bg_color = Color("#010813")
	footer_style.set_corner_radius_all(8)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 40)
	vbox.add_child(hbox)
	
	var back_btn_popup = Button.new()
	back_btn_popup.name = "PopupBackButton"
	back_btn_popup.text = "Back"
	back_btn_popup.custom_minimum_size = Vector2(200, 80)
	back_btn_popup.add_theme_font_size_override("font_size", 32)
	back_btn_popup.add_theme_color_override("font_color", Color("#60fafc"))
	back_btn_popup.add_theme_stylebox_override("normal", footer_style)
	back_btn_popup.add_theme_stylebox_override("hover", footer_style)
	back_btn_popup.add_theme_stylebox_override("pressed", footer_style)
	back_btn_popup.pressed.connect(func():
		if TutorialManager and PlayerData.tutorial_step == TutorialManager.Step.CLOSE_INSPECT:
			TutorialManager.advance_step()
		_selection_popup.queue_free()
	)
	hbox.add_child(back_btn_popup)
	
	# Tutorial Highlight for Back Button
	if TutorialManager and PlayerData.tutorial_step == TutorialManager.Step.CLOSE_INSPECT:
		# Force the highlight immediately since we have the reference
		TutorialManager.show_instruction("Review stats and moves here. Tap Back to continue.", back_btn_popup, "talk")
		# Also update the manager's target so it tracks position
		TutorialManager.current_target_node = back_btn_popup 
	
	if is_squad_member:
		var remove_btn = Button.new()
		remove_btn.text = "Remove"
		remove_btn.custom_minimum_size = Vector2(200, 80)
		remove_btn.add_theme_font_size_override("font_size", 32)
		remove_btn.add_theme_color_override("font_color", Color("#60fafc"))
		remove_btn.add_theme_stylebox_override("normal", footer_style)
		remove_btn.add_theme_stylebox_override("hover", footer_style)
		remove_btn.add_theme_stylebox_override("pressed", footer_style)
		remove_btn.pressed.connect(func(): _confirm_assignment(null))
		hbox.add_child(remove_btn)
		
		var replace_btn = Button.new()
		replace_btn.text = "Replace"
		replace_btn.custom_minimum_size = Vector2(200, 80)
		replace_btn.add_theme_font_size_override("font_size", 32)
		replace_btn.add_theme_color_override("font_color", Color("#60fafc"))
		replace_btn.add_theme_stylebox_override("normal", footer_style)
		replace_btn.add_theme_stylebox_override("hover", footer_style)
		replace_btn.add_theme_stylebox_override("pressed", footer_style)
		replace_btn.pressed.connect(func(): 
			_selection_popup.queue_free()
			_show_collection_selector()
		)
		hbox.add_child(replace_btn)
	else:
		var add_btn = Button.new()
		add_btn.text = "Add to Squad"
		add_btn.custom_minimum_size = Vector2(250, 80)
		add_btn.add_theme_font_size_override("font_size", 32)
		add_btn.add_theme_color_override("font_color", Color("#60fafc"))
		add_btn.add_theme_stylebox_override("normal", footer_style)
		add_btn.add_theme_stylebox_override("hover", footer_style)
		add_btn.add_theme_stylebox_override("pressed", footer_style)
		add_btn.pressed.connect(func(): _confirm_assignment(monster))
		hbox.add_child(add_btn)
	
	add_child(_selection_popup)
	
	# Animate mini detail popup (Pop + Fade)
	_selection_popup.pivot_offset = _selection_popup.custom_minimum_size / 2
	_selection_popup.scale = Vector2(0.9, 0.9)
	_selection_popup.modulate.a = 0.0
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_selection_popup, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_selection_popup, "modulate:a", 1.0, 0.2)

func _create_move_type_badge(move_type: String) -> Control:
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(40, 40)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	match move_type:
		"Physical":
			icon_rect.texture = icon_physical
			icon_rect.tooltip_text = "Physical Attack"
		"Special":
			icon_rect.texture = icon_special
			icon_rect.tooltip_text = "Special Attack"
		"Status_Hostile":
			icon_rect.texture = icon_hostile
			icon_rect.tooltip_text = "Hostile Status"
		"Status_Friendly", "Passive":
			icon_rect.texture = icon_friendly
			icon_rect.tooltip_text = "Friendly Status"
	
	return icon_rect

func _confirm_assignment(monster: MonsterData):
	if _target_slot_index != -1:
		PlayerData.active_team[_target_slot_index] = monster
		
	if _selection_popup and is_instance_valid(_selection_popup): _selection_popup.queue_free()
	if _collection_popup_node and is_instance_valid(_collection_popup_node): _collection_popup_node.queue_free()
	
	var tutorial_needs_update = false
	
	# Tutorial Advancement Logic
	if TutorialManager and monster:
		var step = PlayerData.tutorial_step
		if step == TutorialManager.Step.SELECT_HELIUM and monster.atomic_number == 2:
			# Move to Assign Flank
			TutorialManager.advance_step()
			tutorial_needs_update = true # Will trigger check for INSPECT_HELIUM
		elif step == TutorialManager.Step.SELECT_HYDROGEN and monster.atomic_number == 1:
			# Move to Intel
			TutorialManager.advance_step()
			tutorial_needs_update = true # Will trigger check for EXPLAIN_INTEL
	
	_update_team_display()
	
	if tutorial_needs_update:
		# Wait for UI layout to settle so TutorialManager finds the correct new slot position
		await get_tree().process_frame
		TutorialManager.check_tutorial_progress()

func _on_clear_team_pressed():
	for i in range(PlayerData.active_team.size()):
		PlayerData.active_team[i] = null
	_update_team_display()

func _on_start_pressed():
	if start_btn.disabled:
		return
		
	if CampaignManager:
		CampaignManager.is_active_campaign_battle = true
		
	GlobalManager.switch_scene("battle")

func _on_back_pressed():
	GlobalManager.switch_scene("main_menu")


func _on_back_button_pressed():
	GlobalManager.switch_scene("main_menu")
