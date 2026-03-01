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
var speed_label
var icon_texture
var moves_container
var class_label
var class_help_icon
var class_bonus_label
var fatigue_label
var fatigue_container
var coolant_btn
var view_toggle
var prev_button
var next_button
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
	speed_label = find_child("SpeedLabel", true, false)
	icon_texture = find_child("IconTexture", true, false)
	moves_container = find_child("MovesContainer", true, false)
	class_label = find_child("ClassLabel", true, false)
	class_help_icon = find_child("HelpIcon", true, false)
	class_bonus_label = find_child("ClassBonus", true, false)
	fatigue_label = find_child("FatigueLabel", true, false)
	fatigue_container = find_child("FatigueContainer", true, false)
	coolant_btn = find_child("CoolantButton", true, false)
	view_toggle = find_child("ViewToggle", true, false)
	prev_button = find_child("PrevButton", true, false)
	next_button = find_child("NextButton", true, false)
	
	if prev_button: prev_button.pressed.connect(_on_prev_pressed)
	if next_button: next_button.pressed.connect(_on_next_pressed)
	
	if view_toggle:
		view_toggle.toggled.connect(_on_view_toggle_toggled)
	
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
		
		if hp_label: hp_label.modulate = content_modulate
		if attack_label: attack_label.modulate = content_modulate
		if defense_label: defense_label.modulate = content_modulate
		if speed_label: speed_label.modulate = content_modulate

	if class_label and "group" in current_monster:
		var group_name = AtomicConfig.Group.find_key(current_monster.group)
		if group_name:
			class_label.text = "Class: " + group_name.replace("_", " ").capitalize()
			
			if class_help_icon:
				class_help_icon.tooltip_text = _get_class_description(current_monster.group)

	if class_bonus_label and "group" in current_monster:
		var group = current_monster.group
		var owned = PlayerData.class_resonance.get(group, 0)
		var total = 0
		for m in MonsterManifest.all_monsters:
			if m.group == group:
				total += 1
		
		class_bonus_label.text = "Synergy: %d/%d Collected" % [owned, total]
		class_bonus_label.tooltip_text = _get_synergy_desc(group, owned)

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
		theme.set_font_size("font_size", "Label", 32)
		
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
		theme.set_font_size("font_size", "Button", 28)
		
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
