extends Control

# This variable will be set by your SceneManager before this scene is displayed.
var current_monster: MonsterData

@export var icon_physical: Texture2D
@export var icon_special: Texture2D
@export var icon_hostile: Texture2D
@export var icon_friendly: Texture2D

# --- UI Node References ---
var name_label
var number_label
var stability_label
var stability_bar
var hp_label
var attack_label
var defense_label
var stats_label
var speed_label
var crit_label
var icon_texture
var moves_container
var class_label
var class_container
var class_help_icon
var class_bonus_label
var fatigue_label
var fatigue_container
var coolant_btn
var view_toggle
var prev_button
var next_button
var replay_container
var replay_btn
var _run_confirm_popup
var _touch_start_pos = Vector2.ZERO
var _min_swipe_distance = 50


func _ready():
	# Find nodes dynamically to avoid path errors
	name_label = find_child("NameLabel", true, false)
	number_label = find_child("NumberLabel", true, false)
	stability_label = find_child("StabilityLabel", true, false)
	stability_bar = find_child("StabilityBar", true, false)
	hp_label = find_child("HPLabel", true, false)
	attack_label = find_child("AttackLabel", true, false)
	defense_label = find_child("DefenseLabel", true, false)
	stats_label = find_child("StatsLabel", true, false)
	speed_label = find_child("SpeedLabel", true, false)
	crit_label = find_child("CritLabel", true, false)
	icon_texture = find_child("IconTexture", true, false)
	moves_container = find_child("MovesContainer", true, false)
	class_label = find_child("ClassLabel", true, false)
	class_container = find_child("ClassContainer", true, false)
	class_help_icon = find_child("HelpIcon", true, false)
	class_bonus_label = find_child("ClassBonus", true, false)
	fatigue_label = find_child("FatigueLabel", true, false)
	fatigue_container = find_child("FatigueContainer", true, false)
	coolant_btn = find_child("CoolantButton", true, false)
	view_toggle = find_child("ViewToggle", true, false)
	prev_button = find_child("PrevButton", true, false)
	next_button = find_child("NextButton", true, false)
	replay_container = find_child("ReplayContainer", true, false)
	replay_btn = find_child("ReplayButton", true, false)
	
	if prev_button: prev_button.pressed.connect(_on_prev_pressed)
	if next_button: next_button.pressed.connect(_on_next_pressed)
	
	if view_toggle:
		view_toggle.toggled.connect(_on_view_toggle_toggled)
	
	if replay_btn:
		replay_btn.pressed.connect(_on_replay_pressed)
	
	if class_help_icon:
		class_help_icon.theme = GlobalManager.tooltip_theme
		# Mobile support: Make icon clickable to show tooltip
		class_help_icon.mouse_filter = Control.MOUSE_FILTER_STOP
		if not class_help_icon.gui_input.is_connected(_on_help_icon_input):
			class_help_icon.gui_input.connect(_on_help_icon_input)

	if class_bonus_label:
		class_bonus_label.mouse_filter = Control.MOUSE_FILTER_STOP
		if not class_bonus_label.gui_input.is_connected(_on_class_bonus_input):
			class_bonus_label.gui_input.connect(_on_class_bonus_input)
			
	if stats_label:
		stats_label.mouse_filter = Control.MOUSE_FILTER_STOP
		if not stats_label.gui_input.is_connected(_on_stats_label_input):
			stats_label.gui_input.connect(_on_stats_label_input)

	if not fatigue_label and name_label:
		# Create dynamically if not found in scene
		fatigue_container = HBoxContainer.new()
		fatigue_container.name = "FatigueContainer"
		fatigue_container.alignment = BoxContainer.ALIGNMENT_CENTER
		fatigue_container.add_theme_constant_override("separation", 20)
		name_label.get_parent().add_child(fatigue_container)
		name_label.get_parent().move_child(fatigue_container, name_label.get_index() + 1)

		fatigue_label = Label.new()
		fatigue_label.name = "FatigueLabel"
		fatigue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fatigue_label.add_theme_color_override("font_color", Color("#ff4d4d"))
		fatigue_label.add_theme_font_size_override("font_size", 48)
		fatigue_container.add_child(fatigue_label)
		
		coolant_btn = Button.new()
		coolant_btn.name = "CoolantButton"
		coolant_btn.add_theme_font_size_override("font_size", 24)
		coolant_btn.custom_minimum_size = Vector2(200, 60)
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color("#60fafc")
		btn_style.bg_color.a = 0.2
		btn_style.set_corner_radius_all(8)
		coolant_btn.add_theme_stylebox_override("normal", btn_style)
		coolant_btn.pressed.connect(_on_coolant_pressed)
		fatigue_container.add_child(coolant_btn)

	if stability_bar:
		stability_bar.mouse_filter = Control.MOUSE_FILTER_STOP
		if not stability_bar.gui_input.is_connected(_on_stability_bar_input):
			stability_bar.gui_input.connect(_on_stability_bar_input)

	# Fetch the selected monster from global state if not already set
	if not current_monster:
		current_monster = PlayerData.selected_monster

	# This function is called when the scene loads.
	# We assume current_monster has been set by the previous screen.
	if is_instance_valid(current_monster):
		update_ui()
		_update_visuals()
		_update_navigation_buttons()

func _process(_delta):
	if is_instance_valid(current_monster):
		var current_time = int(Time.get_unix_time_from_system())
		var is_fatigued = current_monster.fatigue_expiry > current_time
		
		if fatigue_container:
			fatigue_container.visible = is_fatigued
			if is_fatigued: _update_fatigue_text()
		elif fatigue_label and fatigue_label.visible:
			if is_fatigued:
				_update_fatigue_text()
			else:
				fatigue_label.visible = false
	
func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start_pos = event.position
		else:
			var drag = event.position - _touch_start_pos
			if drag.length() > _min_swipe_distance:
				if abs(drag.x) > abs(drag.y): # Horizontal swipe
					# Swipe Right (positive X) -> Go Previous
					# Swipe Left (negative X) -> Go Next
					if drag.x > 0:
						if prev_button and not prev_button.disabled: _on_prev_pressed()
					else:
						if next_button and not next_button.disabled: _on_next_pressed()

func _on_prev_pressed():
	_navigate_monster(-1)

func _on_next_pressed():
	_navigate_monster(1)

func update_ui():
	# This function refreshes all the text on the screen.
	if not is_instance_valid(current_monster):
		return
		
	var is_owned = PlayerData.is_monster_owned(current_monster.monster_name)
	var content_modulate = Color.WHITE if is_owned else Color(1, 1, 1, 0.5)
		
	var group_color = Color.WHITE
	if "group" in current_monster:
		group_color = AtomicConfig.GROUP_COLORS.get(current_monster.group, Color.WHITE)

	if name_label: name_label.text = current_monster.monster_name
	if number_label: number_label.text = "#" + str(current_monster.atomic_number)
	
	if stability_label:
		stability_label.text = "Stability: %d%%" % current_monster.stability
		if current_monster.stability >= 100:
			stability_label.modulate = Color("#ffd700") # Gold for max
		else:
			stability_label.modulate = Color.WHITE
			
	if stability_bar:
		_update_stability_bar(current_monster.stability)
	
	if current_monster.has_method("get_current_stats"):
		var stats = current_monster.get_current_stats()
		if hp_label: hp_label.text = "HP: " + str(stats.max_hp)
		if attack_label: attack_label.text = "Attack: " + str(stats.attack)
		if defense_label: defense_label.text = "Defense: " + str(stats.defense)
		if speed_label: speed_label.text = "Speed: " + str(stats.speed)
		if crit_label: crit_label.text = "Crit: %d%%" % stats.get("crit_chance", 5)
		
		if hp_label: hp_label.modulate = content_modulate
		if attack_label: attack_label.modulate = content_modulate
		if defense_label: defense_label.modulate = content_modulate
		if speed_label: speed_label.modulate = content_modulate
		if crit_label: crit_label.modulate = content_modulate

	if class_label and "group" in current_monster:
		var group_name = AtomicConfig.Group.find_key(current_monster.group)
		if group_name:
			class_label.text = "Class: " + group_name.replace("_", " ").capitalize()
			class_label.add_theme_color_override("font_color", group_color)
			class_label.add_theme_color_override("font_outline_color", Color.BLACK)
			class_label.add_theme_constant_override("outline_size", 6)
			
			if class_help_icon:
				class_help_icon.tooltip_text = _get_class_description(current_monster.group)
				class_help_icon.modulate = group_color

	if class_bonus_label and "group" in current_monster:
		var group = current_monster.group
		var owned = PlayerData.class_resonance.get(group, 0)
		var total = 0
		for m in MonsterManifest.all_monsters:
			if m.group == group:
				total += 1
		
		class_bonus_label.text = "%d/%d Collected" % [owned, total]
		class_bonus_label.tooltip_text = _get_synergy_desc(group, owned)
		class_bonus_label.add_theme_color_override("font_color", group_color)
		class_bonus_label.add_theme_color_override("font_outline_color", Color.BLACK)
		class_bonus_label.add_theme_constant_override("outline_size", 6)

	if replay_container:
		var has_blueprint = (current_monster.atomic_number in PlayerData.unlocked_blueprints)
		replay_container.visible = is_owned or has_blueprint

	if fatigue_label or fatigue_container:
		var current_time = int(Time.get_unix_time_from_system())
		var is_fatigued = current_monster.fatigue_expiry > current_time
		
		if fatigue_container: fatigue_container.visible = is_fatigued
		elif fatigue_label: fatigue_label.visible = is_fatigued
		
		if is_fatigued:
			_update_fatigue_text()
			_update_coolant_btn()

	if moves_container: moves_container.modulate = content_modulate
	if moves_container:
		for child in moves_container.get_children():
			child.queue_free()
		
		var moves_list = CombatManager.get_active_moves(current_monster)
		
		for m in moves_list:
			if m:
				var margin = MarginContainer.new()
				margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				margin.add_theme_constant_override("margin_left", 20)
				margin.add_theme_constant_override("margin_right", 20)
				
				var hbox = HBoxContainer.new()
				hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				hbox.add_theme_constant_override("separation", 15)
				margin.add_child(hbox)
				
				var move_rtl = RichTextLabel.new()
				move_rtl.bbcode_enabled = true
				move_rtl.fit_content = true
				move_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				
				var pwr = m.power if "power" in m else 0
				var desc = m.description if "description" in m else ""
				var acc = m.accuracy if "accuracy" in m else 100
				var m_type = m.type if "type" in m else "Physical"

				var type_badge = _create_move_type_badge(m_type)
				type_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				hbox.add_child(type_badge)
				
				var text = "[color=#60fafc][font_size=40]%s (Pwr: %d)[/font_size][/color]" % [m.name, pwr]
				if desc != "":
					text += "\n[color=#e6e6e6][font_size=30]%s[/font_size][/color]" % desc
				
				move_rtl.text = text
				move_rtl.tooltip_text = "Type: %s\nAccuracy: %d%%" % [m_type, acc]
				move_rtl.mouse_filter = Control.MOUSE_FILTER_PASS
				move_rtl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				hbox.add_child(move_rtl)
				moves_container.add_child(margin)
				
				# Input Handling for Animation
				var on_click = func(event):
					if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
						_play_attack_animation()
				
				margin.mouse_filter = Control.MOUSE_FILTER_STOP
				margin.gui_input.connect(on_click)
				hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
				type_badge.mouse_filter = Control.MOUSE_FILTER_PASS
				type_badge.gui_input.connect(on_click)
				move_rtl.gui_input.connect(on_click)
				
				var sep = HSeparator.new()
				sep.modulate = Color("#60fafc")
				sep.modulate.a = 0.3
				moves_container.add_child(sep)

func _on_view_toggle_toggled(_toggled_on: bool):
	_update_visuals()

func _navigate_monster(direction: int):
	if not current_monster: return
	
	var max_z = PlayerData.get_max_unlocked_z()
	var new_z = current_monster.atomic_number + direction
	if new_z < 1 or new_z > max_z: return
	
	var path = PlayerData.get_monster_path_by_z(new_z)
	if path != "":
		var base_monster = load(path)
		if base_monster:
			# 1. Create proxy of current state for animation
			var old_proxy = _create_visual_proxy()
			
			# Check if we own a copy to show stats/level
			var owned = PlayerData.get_owned_monster(base_monster.monster_name)
			if owned:
				current_monster = owned
			else:
				current_monster = base_monster
			
			update_ui()
			# Update visuals immediately without icon animation (we animate the whole page)
			_update_visuals(0, true)
			_update_navigation_buttons()
			
			# 2. Create proxy of new state
			var new_proxy = _create_visual_proxy()
			var slide_offset = get_viewport_rect().size.x * direction
			new_proxy.global_position.x += slide_offset
			
			# 3. Hide real elements during animation
			for child in get_children():
				if child != old_proxy and child != new_proxy and child is CanvasItem:
					child.modulate.a = 0.0
			
			# 4. Animate
			var tween = create_tween()
			tween.set_parallel(true)
			tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			
			tween.tween_property(old_proxy, "global_position:x", old_proxy.global_position.x - slide_offset, 0.3)
			tween.tween_property(new_proxy, "global_position:x", new_proxy.global_position.x - slide_offset, 0.3)
			
			tween.chain().tween_callback(func():
				if is_instance_valid(old_proxy): old_proxy.queue_free()
				if is_instance_valid(new_proxy): new_proxy.queue_free()
				# Restore visibility
				for child in get_children():
					if child is CanvasItem:
						child.modulate.a = 1.0
			)

func _create_visual_proxy() -> Control:
	var proxy = Control.new()
	proxy.top_level = true
	proxy.global_position = global_position
	proxy.size = size
	add_child(proxy)
	
	for child in get_children():
		if child == proxy: continue
		# Don't duplicate existing proxies or popups
		if child is CanvasItem and child.top_level: continue
		if child.name == "InfoPopup": continue
		
		if child is Control or child is Node2D:
			var dup = child.duplicate(0)
			proxy.add_child(dup)
	return proxy

func _update_visuals(slide_direction: int = 0, skip_animation: bool = false):
	if not icon_texture or not current_monster: return
	
	# Capture old visuals to fade them out
	var old_visuals = icon_texture.get_children()
	
	# Clear the background texture if it was set
	icon_texture.texture = null
	
	var is_owned = PlayerData.is_monster_owned(current_monster.monster_name)
	var target_modulate = Color.WHITE if is_owned else Color(0.2, 0.2, 0.2, 0.8)
	
	var new_visual = null
	
	if view_toggle and view_toggle.button_pressed:
		new_visual = _setup_sprite()
	else:
		new_visual = _setup_atom()
	
	if new_visual:
		if skip_animation:
			new_visual.modulate = target_modulate
			for child in old_visuals:
				child.queue_free()
			return

		var tween = create_tween()
		tween.set_parallel(true)
		
		if slide_direction == 0:
			# Default Fade Transition
			new_visual.modulate = target_modulate
			new_visual.modulate.a = 0.0
			tween.tween_property(new_visual, "modulate:a", target_modulate.a, 0.3)
			
			for child in old_visuals:
				tween.tween_property(child, "modulate:a", 0.0, 0.3)
		else:
			# Slide Transition
			var offset = icon_texture.size.x
			var start_x = new_visual.position.x + (offset * slide_direction)
			var end_x = new_visual.position.x
			
			# Setup new visual start position
			new_visual.position.x = start_x
			new_visual.modulate = target_modulate
			new_visual.modulate.a = 0.0 # Start transparent for smoother entry
			
			# Animate New Visual In
			tween.tween_property(new_visual, "position:x", end_x, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(new_visual, "modulate:a", target_modulate.a, 0.3)
			
			# Animate Old Visuals Out
			for child in old_visuals:
				var child_end_x = child.position.x - (offset * slide_direction)
				tween.tween_property(child, "position:x", child_end_x, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				tween.tween_property(child, "modulate:a", 0.0, 0.3)
		
		tween.chain().tween_callback(func():
			for child in old_visuals:
				if is_instance_valid(child):
					child.queue_free()
		)

func _setup_atom() -> Node2D:
	if not icon_texture or not current_monster: return null

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
		return atom
	return null

func _setup_sprite() -> Node2D:
	if not icon_texture or not current_monster: return null
	
	var anim_path = "res://Assets/Animations/" + current_monster.monster_name.replace(" ", "") + ".tres"
	
	if ResourceLoader.exists(anim_path):
		var sprite_frames = load(anim_path)
		if sprite_frames:
			var sprite = AnimatedSprite2D.new()
			sprite.sprite_frames = sprite_frames
			
			# Robust animation playing
			var anim_to_play = "idle"
			if not sprite_frames.has_animation(anim_to_play):
				if sprite_frames.has_animation("default"):
					anim_to_play = "default"
				else:
					var anims = sprite_frames.get_animation_names()
					if anims.size() > 0:
						anim_to_play = anims[0]
			
			sprite.play(anim_to_play)
			sprite.position = icon_texture.size / 2
			
			# Scale sprite to fit container (with padding)
			var tex = sprite_frames.get_frame_texture(anim_to_play, 0)
			if tex:
				var s = (icon_texture.size.y * 0.8) / float(tex.get_height())
				sprite.scale = Vector2(s, s)
				
			icon_texture.add_child(sprite)
			return sprite
	else:
		# Fallback to static icon as a child Sprite2D for transitions
		var sprite = Sprite2D.new()
		sprite.texture = current_monster.icon
		sprite.position = icon_texture.size / 2
		
		if current_monster.icon:
			var s = (icon_texture.size.y * 0.8) / float(current_monster.icon.get_height())
			sprite.scale = Vector2(s, s)
			
		icon_texture.add_child(sprite)
		return sprite
	return null

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

func _on_help_icon_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_tooltip_popup(class_help_icon.tooltip_text)

func _on_class_bonus_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_tooltip_popup(class_bonus_label.tooltip_text)

func _on_stats_label_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_detailed_stats_popup()

func _show_detailed_stats_popup():
	if not current_monster: return

	var result = AtomicConfig.calculate_stats_with_breakdown(current_monster.group, current_monster.atomic_number, current_monster.stability)
	var breakdown = result.breakdown
	var final_stats = result.final_stats

	var text = ""
	text += _format_stat_breakdown("HP", breakdown.hp, final_stats.max_hp)
	text += _format_stat_breakdown("Attack", breakdown.atk, final_stats.attack)
	text += _format_stat_breakdown("Defense", breakdown.def, final_stats.defense)
	text += _format_stat_breakdown("Speed", breakdown.spd, final_stats.speed)
	text += _format_stat_breakdown("Crit Chance", breakdown.crit, final_stats.crit_chance)
	
	# Create a custom popup
	var popup = PanelContainer.new()
	popup.name = "DetailedStatsPopup"
	popup.set_anchors_preset(Control.PRESET_CENTER)
	popup.custom_minimum_size = Vector2(900, 0)
	popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	popup.grow_vertical = Control.GROW_DIRECTION_BOTH
	popup.z_index = 100
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#010813")
	style.border_color = Color("#60fafc")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	popup.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40); margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 40); margin.add_theme_constant_override("margin_bottom", 40)
	popup.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = "Stat Breakdown"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color("#60fafc"))
	vbox.add_child(title)
	
	var sep = HSeparator.new()
	sep.modulate = Color("#60fafc")
	vbox.add_child(sep)
	
	var rtl = RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.text = text
	rtl.fit_content = true
	rtl.add_theme_font_size_override("normal_font_size", 42)
	rtl.add_theme_font_size_override("bold_font_size", 42)
	vbox.add_child(rtl)
	
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size.y = 80
	close_btn.add_theme_font_size_override("font_size", 40)
	close_btn.pressed.connect(popup.queue_free)
	vbox.add_child(close_btn)
	
	add_child(popup)

func _format_stat_breakdown(stat_name: String, data: Dictionary, final_value: int) -> String:
	var str = "[color=#60fafc][b]%s: %d[/b][/color]\n" % [stat_name, final_value]
	str += "[color=#cccccc]  • Base: %d[/color]\n" % int(data.base)
	
	var total_mult = 1.0 + data.stability + data.resonance + data.ship_upgrade + data.lanthanide_set
	if data.stability > 0: str += "[color=#ffd700]  • Stability: +%d%%[/color]\n" % int(data.stability * 100)
	if data.resonance > 0: str += "[color=#a0a0a0]  • Resonance: +%d%%[/color]\n" % int(data.resonance * 100)
	if data.ship_upgrade > 0: str += "[color=#a0a0a0]  • Ship Upgrade: +%d%%[/color]\n" % int(data.ship_upgrade * 100)
	if data.lanthanide_set > 0: str += "[color=#a0a0a0]  • Lanthanide Set: +%d%%[/color]\n" % int(data.lanthanide_set * 100)
		
	str += "[color=#888888]  • Total Multiplier: x%.2f[/color]\n\n" % total_mult
	return str

func _on_stability_bar_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var bonus = 0.0
		if current_monster:
			bonus = float(current_monster.stability) / 2.0
			if current_monster.stability >= 100:
				bonus += 10.0
		
		var text = "Stability amplifies stats.\n\n"
		text += "Current Bonus: +%d%%\n\n" % int(bonus)
		text += "Thresholds:\n• 50% Stability: +25% Stats\n• 100% Stability: +50% Stats\n\n"
		text += "MASTERY:\nAt 100%, unlocks Class Potential for an extra +10%."
		_show_tooltip_popup(text)

func _show_tooltip_popup(text: String):
	var popup = find_child("InfoPopup", true, false)
	if not popup:
		popup = AcceptDialog.new()
		popup.name = "InfoPopup"
		add_child(popup)
		
		var theme = Theme.new()
		
		# Background
		var bg = StyleBoxFlat.new()
		bg.bg_color = Color("#010813")
		bg.border_width_left = 2
		bg.border_width_top = 2
		bg.border_width_right = 2
		bg.border_width_bottom = 2
		bg.border_color = Color("#60fafc")
		bg.content_margin_left = 20
		bg.content_margin_right = 20
		bg.content_margin_top = 20
		bg.content_margin_bottom = 20
		theme.set_stylebox("panel", "Window", bg)
		
		# Text
		theme.set_color("font_color", "Label", Color("#60fafc"))
		theme.set_font_size("font_size", "Label", 40)
		
		# Button
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color("#60fafc")
		btn_style.content_margin_left = 30
		btn_style.content_margin_right = 30
		btn_style.content_margin_top = 10
		btn_style.content_margin_bottom = 10
		
		theme.set_stylebox("normal", "Button", btn_style)
		theme.set_stylebox("hover", "Button", btn_style)
		theme.set_stylebox("pressed", "Button", btn_style)
		theme.set_color("font_color", "Button", Color("#010813"))
		theme.set_font_size("font_size", "Button", 32)
		
		popup.theme = theme
	
	popup.dialog_text = text
	popup.popup_centered()

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

func _play_attack_animation():
	if not icon_texture: return
	
	for child in icon_texture.get_children():
		var handled = false
		if child is AnimatedSprite2D:
			if child.sprite_frames.has_animation("attack"):
				child.play("attack")
				if not child.animation_finished.is_connected(_return_to_idle):
					child.animation_finished.connect(_return_to_idle, CONNECT_ONE_SHOT)
				handled = true
		
		if not handled and child is Node2D:
			# Feedback punch if no attack animation
			var base_scale = child.get_meta("base_scale", child.scale)
			if not child.has_meta("base_scale"):
				child.set_meta("base_scale", base_scale)
			
			var tween = create_tween()
			tween.tween_property(child, "scale", base_scale * 1.2, 0.1)
			tween.tween_property(child, "scale", base_scale, 0.1)

func _return_to_idle():
	if not icon_texture: return
	for child in icon_texture.get_children():
		if child is AnimatedSprite2D:
			var anim_to_play = "idle"
			if not child.sprite_frames.has_animation(anim_to_play):
				if child.sprite_frames.has_animation("default"):
					anim_to_play = "default"
				else:
					var anims = child.sprite_frames.get_animation_names()
					if anims.size() > 0:
						anim_to_play = anims[0]
			child.play(anim_to_play)

func _update_stability_bar(value: int):
	stability_bar.max_value = 100
	stability_bar.value = value
	
	# Sci-Fi Background: Dark void with a metallic rim
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color("#050508") # Deep void black
	bg_style.border_width_left = 2
	bg_style.border_width_top = 2
	bg_style.border_width_right = 2
	bg_style.border_width_bottom = 2
	bg_style.border_color = Color("#404050") # Dark steel
	bg_style.set_corner_radius_all(6)
	stability_bar.add_theme_stylebox_override("background", bg_style)

	var style = stability_bar.get_theme_stylebox("fill")
	if not style is StyleBoxFlat or not stability_bar.has_meta("custom_style"):
		style = StyleBoxFlat.new()
		style.set_corner_radius_all(6)
		# Add a top highlight for a "glass tube" effect
		style.border_width_top = 2
		style.border_blend = true
		stability_bar.add_theme_stylebox_override("fill", style)
		stability_bar.set_meta("custom_style", true)
	
	# Reset any active pulse
	if stability_bar.has_meta("pulse_tween"):
		var t = stability_bar.get_meta("pulse_tween")
		if t and t.is_valid():
			t.kill()
		stability_bar.set_meta("pulse_tween", null)
	
	# Color coding based on stability - Neon/Plasma look
	if value >= 100:
		style.bg_color = Color("#ffd700") # Gold (Max)
		style.border_color = Color("#ffffaa")
		style.bg_color.a = 1.0
		_start_pulse(stability_bar, style)
	elif value >= 80:
		style.bg_color = Color("#60fafc") # Cyan (High)
		style.border_color = Color("#ccffff")
		style.bg_color.a = 0.9
	elif value >= 50:
		style.bg_color = Color("#2ecc71") # Green (Stable)
		style.border_color = Color("#aaffaa")
		style.bg_color.a = 0.9
	else:
		style.bg_color = Color("#ff4d4d") # Red (Unstable)
		style.border_color = Color("#ffaaaa")
		style.bg_color.a = 0.9

func _update_navigation_buttons():
	if not current_monster: return
	
	var max_z = PlayerData.get_max_unlocked_z()
	var current_z = current_monster.atomic_number
	
	if prev_button:
		prev_button.disabled = (current_z <= 1)
		prev_button.visible = not prev_button.disabled
		
	if next_button:
		next_button.disabled = (current_z >= max_z)
		next_button.visible = not next_button.disabled

func _start_pulse(bar: ProgressBar, style: StyleBoxFlat):
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(style, "bg_color", Color("#fff5cc"), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(style, "bg_color", Color("#ffd700"), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bar.set_meta("pulse_tween", tween)

func _get_synergy_desc(group: int, count: int) -> String:
	match group:
		AtomicConfig.Group.ALKALI_METAL:
			var val = count * 5
			return "Current Bonus: Ignore %d%% Defense.\nPassive: +5%% Defense Penetration per element." % val
		AtomicConfig.Group.ALKALINE_EARTH:
			var val = count * 5
			return "Current Bonus: +%d%% Defense.\nPassive: +5%% Defense per element." % val
		AtomicConfig.Group.TRANSITION_METAL:
			var val = count * 2
			return "Current Bonus: %d%% Double Hit Chance.\nPassive: +2%% Double Hit Chance per element." % val
		AtomicConfig.Group.HALOGEN:
			var val = count * 1
			return "Current Bonus: +%d%% Poison Damage.\nPassive: +1%% Poison Damage per element." % val
		AtomicConfig.Group.NOBLE_GAS:
			var val = count * 5
			return "Current Bonus: +%d%% Max HP.\nPassive: +5%% Max HP per element." % val
		AtomicConfig.Group.LANTHANIDE:
			var val = count * 1
			return "Current Bonus: +%d%% All Stats.\nPassive: +1%% All Stats per element." % val
		AtomicConfig.Group.NONMETAL:
			var val = count * 5
			return "Current Bonus: %d%% Chain Reaction Chance.\nPassive: +5%% Chain Reaction Chance per element." % val
		AtomicConfig.Group.METALLOID:
			var val = count * 5
			return "Current Bonus: +%d%% Debuff Effectiveness.\nPassive: +5%% Debuff Effectiveness per element." % val
		AtomicConfig.Group.POST_TRANSITION:
			var val = count * 5
			return "Current Bonus: +%d%% Buff Effectiveness.\nPassive: +5%% Buff Effectiveness per element." % val
		AtomicConfig.Group.ACTINIDE:
			var val = count * 1
			return "Current Bonus: +%d%% Speed.\nPassive: +1%% Speed per element." % val
	return "Unknown Synergy."

func _update_fatigue_text():
	var time_left = current_monster.fatigue_expiry - int(Time.get_unix_time_from_system())
	var mins = time_left / 60
	var secs = time_left % 60
	fatigue_label.text = "Fatigue: %02d:%02d" % [mins, secs]

func _update_coolant_btn():
	if not coolant_btn: return
	var count = PlayerData.get_item_count("coolant_gel")
	coolant_btn.text = "Use Coolant (%d)" % count
	coolant_btn.disabled = (count <= 0)

func _on_coolant_pressed():
	if PlayerData.consume_item("coolant_gel", 1):
		current_monster.fatigue_expiry = 0
		PlayerData.save_game()
		update_ui()

func _on_replay_pressed():
	if not current_monster: return
	_show_run_confirmation(current_monster)

func _show_run_confirmation(monster: MonsterData):
	if _run_confirm_popup: _run_confirm_popup.queue_free()
	
	_run_confirm_popup = PanelContainer.new()
	_run_confirm_popup.set_anchors_preset(Control.PRESET_CENTER)
	_run_confirm_popup.z_index = 50
	_run_confirm_popup.custom_minimum_size = Vector2(800, 500)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#010813")
	style.border_color = Color("#60fafc")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	_run_confirm_popup.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.add_child(vbox)
	_run_confirm_popup.add_child(margin)
	
	var title = Label.new()
	title.text = "Resource Run: %s" % monster.monster_name
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("#60fafc"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var desc = Label.new()
	
	var z = monster.atomic_number
	var energy = AtomicConfig.calculate_fusion_cost(z)
	var waves = 3 + int(z / 16.0)
	if CampaignManager:
		var race = CampaignManager.GROUP_TO_RACE_MAP.get(monster.group, "void")
		if race == "brood":
			waves += 2
	
	desc.text = "Replay this discovery run to earn resources.\n\n" + \
				"Potential Rewards (Full Run):\n" + \
				"• Binding Energy: ~%d\n" % energy + \
				"• Neutron Dust: 0 - %d\n" % (waves * 200) + \
				"• Gems: 0 - %d" % waves
	
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 36)
	vbox.add_child(desc)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)
	
	var start_btn = Button.new()
	start_btn.text = "Start Run"
	start_btn.custom_minimum_size = Vector2(250, 80)
	start_btn.add_theme_color_override("font_color", Color("#010813"))
	start_btn.add_theme_font_size_override("font_size", 36)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color("#60fafc")
	btn_style.set_corner_radius_all(4)
	start_btn.add_theme_stylebox_override("normal", btn_style)
	start_btn.add_theme_stylebox_override("hover", btn_style)
	start_btn.add_theme_stylebox_override("pressed", btn_style)
	
	start_btn.pressed.connect(func():
		if CampaignManager:
			CampaignManager.start_node_run(monster.atomic_number)
		_run_confirm_popup.queue_free()
	)
	hbox.add_child(start_btn)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(250, 80)
	cancel_btn.add_theme_font_size_override("font_size", 36)
	cancel_btn.pressed.connect(_run_confirm_popup.queue_free)
	hbox.add_child(cancel_btn)
	
	add_child(_run_confirm_popup)
	_run_confirm_popup.position = (get_viewport_rect().size - _run_confirm_popup.custom_minimum_size) / 2
