extends Control

@export var monster_card_scene: PackedScene

# Zoom variables
var _zoom_wrapper: Control
var _scroll_container: ScrollContainer
var _touch_points = {}
var _start_zoom_dist = 0.0
var _start_scale = Vector2.ONE
var _start_pinch_center = Vector2.ZERO
var _start_scroll_offset = Vector2.ZERO
var _is_dragging = false
var _drag_start_pos = Vector2.ZERO

var _style_cache = {}
var _owned_lookup = {}
var _card_nodes = {} # Z -> Control (Card Node)
var _current_max_z = 0

# Run UI
var _run_popup: Control
var _selected_run_z: int = 0
var _ui_layer: CanvasLayer

func _ready():
	# $Background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var grid = find_child("GridContainer", true, false)
	if grid:
		grid.columns = 18 # Standard Periodic Table width
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		grid.sort_children.connect(func(): grid.queue_redraw())
		_populate_table(grid)
		
		# Inject Zoom Wrapper for Pinch-to-Zoom
		var parent = grid.get_parent()
		if parent is ScrollContainer:
			_scroll_container = parent
			_zoom_wrapper = Control.new()
			_zoom_wrapper.name = "ZoomWrapper"
			_zoom_wrapper.mouse_filter = Control.MOUSE_FILTER_PASS
			_zoom_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_zoom_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
			
			parent.remove_child(grid)
			parent.add_child(_zoom_wrapper)
			_zoom_wrapper.add_child(grid)
			
			grid.resized.connect(_update_zoom_wrapper)
			_update_zoom_wrapper()
	
	var back_btn = find_child("BackButton", true, false)
	if back_btn:
		if not back_btn.pressed.is_connected(_on_back_pressed):
			back_btn.pressed.connect(_on_back_pressed)
	
	_run_popup = find_child("DiscoveryRunPopup", true, false)
	if _run_popup:
		_run_popup.visible = false
		var confirm_btn = _run_popup.find_child("ConfirmButton", true, false)
		if not confirm_btn: confirm_btn = _run_popup.find_child("StartButton", true, false)
		
		var cancel_btn = _run_popup.find_child("CancelButton", true, false)
		
		if confirm_btn:
			confirm_btn.pressed.connect(_on_start_run_confirmed)
		if cancel_btn:
			cancel_btn.pressed.connect(func(): _run_popup.visible = false)
		
	_setup_legend_ui()

func _populate_table(grid: GridContainer):
	# Optimization: Pre-calculate owned monsters lookup
	_owned_lookup.clear()
	for m in PlayerData.owned_monsters:
		_owned_lookup[m.atomic_number] = m
	_style_cache.clear()
	_card_nodes.clear()
	_current_max_z = PlayerData.get_max_unlocked_z()

	# Clear existing
	for child in grid.get_children():
		child.queue_free()
	
	# --- Row 1 ---
	_add_card(grid, 1) # Hydrogen
	_add_spacers(grid, 16) # Gap
	_add_card(grid, 2) # Helium
	await get_tree().process_frame
	
	# --- Row 2 ---
	_add_card(grid, 3) # Lithium
	_add_card(grid, 4) # Beryllium
	_add_spacers(grid, 10) # Gap (Transition Metals skipped in row 2)
	for z in range(5, 11): # Boron (5) through Neon (10)
		_add_card(grid, z)
	await get_tree().process_frame
		
	# --- Row 3 ---
	_add_card(grid, 11) # Sodium
	_add_card(grid, 12) # Magnesium
	_add_spacers(grid, 10)
	for z in range(13, 19): _add_card(grid, z) # Al - Ar
	await get_tree().process_frame
	
	# --- Row 4 ---
	for z in range(19, 37): _add_card(grid, z) # K - Kr
	await get_tree().process_frame
	
	# --- Row 5 ---
	for z in range(37, 55): _add_card(grid, z) # Rb - Xe
	await get_tree().process_frame
	
	# --- Row 6 ---
	_add_card(grid, 55) # Cs
	_add_card(grid, 56) # Ba
	_add_spacers(grid, 1) # Lanthanide placeholder gap
	for z in range(72, 87): _add_card(grid, z) # Hf - Rn
	await get_tree().process_frame
	
	# --- Row 7 ---
	_add_card(grid, 87) # Fr
	_add_card(grid, 88) # Ra
	_add_spacers(grid, 1) # Actinide placeholder gap
	for z in range(104, 119): _add_card(grid, z) # Rf - Og
	
	# --- Spacing Row (Vertical Gap) ---
	_add_spacers(grid, 18)
	await get_tree().process_frame
	
	# --- Lanthanides (Row 8) ---
	_add_spacers(grid, 3) # Indent to align with Group 3
	for z in range(57, 72): _add_card(grid, z) # La - Lu
	await get_tree().process_frame
	
	# --- Actinides (Row 9) ---
	_add_spacers(grid, 3) # Indent
	for z in range(89, 104): _add_card(grid, z) # Ac - Lr
	
	_add_scene_legend(grid)
	grid.queue_redraw()
	# Clear lookup to free memory
	_owned_lookup.clear()

func _add_card(grid: Container, z: int):
	if not monster_card_scene: return
	
	var card = monster_card_scene.instantiate()
	grid.add_child(card)
	_card_nodes[z] = card
	
	# Force a fixed size for the table cells so they align perfectly
	card.custom_minimum_size = Vector2(100, 120) 
	
	var monster = _find_monster_by_z(z)
	var is_owned = false
	var has_blueprint = false
	var status = 0 # 0: Locked, 1: Next, 2: Owned/Blueprint
	
	if monster:
		is_owned = PlayerData.is_monster_owned(monster.monster_name)
		if "unlocked_blueprints" in PlayerData:
			has_blueprint = z in PlayerData.unlocked_blueprints
			
	if is_owned or has_blueprint: status = 2
	elif z <= _current_max_z + 1: status = 1
	
	# --- Custom Styling ---
	# Fog of War: If locked, don't show group color
	var display_monster = monster if status > 0 else null
	var style = _get_cached_style(display_monster, is_owned or has_blueprint).duplicate()
	card.add_theme_stylebox_override("panel", style)
	
	# Add gold border for 100% stability on owned monsters
	if is_owned and monster and monster.stability >= 100:
		style.border_width_left = 4
		style.border_width_top = 4
		style.border_width_right = 4
		style.border_width_bottom = 4
		style.border_color = Color("#ffd700") # Gold
	
	var labels = [card.find_child("NameLabel", true, false), card.find_child("NumberLabel", true, false)]
	for lbl in labels:
		if lbl:
			if status == 0:
				lbl.visible = false
			else:
				lbl.visible = true
				if not is_owned and not has_blueprint and monster:
					lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
				else:
					lbl.add_theme_color_override("font_color", Color("#60fafc"))
				lbl.add_theme_font_size_override("font_size", lbl.get_theme_font_size("font_size") + 4)
	
	if monster:
		card.set_monster(monster)
		
		if is_owned:
			var current_time = int(Time.get_unix_time_from_system())
			if monster.fatigue_expiry > current_time:
				card.modulate = Color(0.6, 0.6, 0.6, 1) # Dim fatigued units
				
				var fatigue_lbl = Label.new()
				fatigue_lbl.text = "zzz"
				fatigue_lbl.add_theme_color_override("font_color", Color("#ff4d4d"))
				fatigue_lbl.add_theme_font_size_override("font_size", 24)
				fatigue_lbl.layout_mode = 1 # Anchors
				fatigue_lbl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
				fatigue_lbl.position += Vector2(-35, 0)
				card.add_child(fatigue_lbl)
			else:
				card.modulate = Color(1, 1, 1, 1) # Full Color
			
			card.mouse_filter = Control.MOUSE_FILTER_STOP
			card.gui_input.connect(func(event):
				if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					if not _is_dragging:
						_on_monster_clicked(monster)
			)
		elif has_blueprint:
			# Blueprint Unlocked: Blue Tint
			var icon = card.find_child("IconTexture", true, false)
			if icon: icon.modulate = Color(0.4, 0.6, 1.0, 0.9)
			
			card.mouse_filter = Control.MOUSE_FILTER_STOP
			card.gui_input.connect(func(event):
				if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					if not _is_dragging:
						_show_run_dialog(z, monster, true)
			)
		else:
			# Not owned: Dark Silhouette
			var icon = card.find_child("IconTexture", true, false)
			
			# Only allow running for the next sequential element
			if z <= _current_max_z + 1:
				if icon: icon.modulate = Color(0, 0, 0, 0.7)
				card.mouse_filter = Control.MOUSE_FILTER_STOP
				card.gui_input.connect(func(event):
					if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
						if not _is_dragging:
							_show_run_dialog(z, monster, false)
				)
			else:
				# Locked (Too far ahead)
				if icon: icon.visible = false
				card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	else:
		# Placeholder for elements not yet implemented
		card.set_placeholder(z)
		if status == 0:
			var icon = card.find_child("IconTexture", true, false)
			if icon: icon.visible = false
			for lbl in labels:
				if lbl: lbl.visible = false
	
	if status == 1:
		var particles = CPUParticles2D.new()
		particles.position = card.custom_minimum_size / 2
		particles.amount = 20
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		particles.emission_rect_extents = card.custom_minimum_size / 2
		particles.direction = Vector2(0, -1)
		particles.gravity = Vector2(0, -10)
		particles.initial_velocity_min = 10
		particles.initial_velocity_max = 30
		particles.scale_amount_min = 2.0
		particles.scale_amount_max = 4.0
		particles.color = Color("#ffd700") # Gold
		card.add_child(particles)
		
		# Add Pulse Animation & Border for the current target
		card.pivot_offset = card.custom_minimum_size / 2
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(card, "scale", Vector2(1.05, 1.05), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(card, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
		var active_style = style.duplicate()
		active_style.border_color = Color("#ffd700")
		active_style.set_border_width_all(2)
		card.add_theme_stylebox_override("panel", active_style)
		
	card.set_meta("status", status)

func _add_spacers(grid: Container, count: int):
	for i in range(count):
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(100, 120) # Match card size
		grid.add_child(spacer)

func _add_scene_legend(grid: Control):
	# Create a Node2D holder so GridContainer layout ignores it, 
	# but it still moves/scales with the grid.
	var holder = Node2D.new()
	holder.name = "LegendHolder"
	
	# Position calculation:
	# Col width = 100 + 8 = 108. Row height = 120 + 8 = 128.
	# Gap starts after Col 2 (x = 216) and Row 1 (y = 128).
	holder.position = Vector2(216, 128)
	grid.add_child(holder)
	
	var panel = PanelContainer.new()
	# Gap size: 10 columns wide (1072px), 2 rows high (248px)
	panel.custom_minimum_size = Vector2(1040, 248)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.3) # Subtle background
	style.border_color = Color("#60fafc")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	
	holder.add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = "Atomic Classes"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("#60fafc"))
	vbox.add_child(title)
	
	var legend_grid = GridContainer.new()
	legend_grid.columns = 5
	legend_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	legend_grid.add_theme_constant_override("h_separation", 17)
	legend_grid.add_theme_constant_override("v_separation", 20)
	vbox.add_child(legend_grid)
	
	for group in AtomicConfig.GROUP_COLORS:
		if group >= AtomicConfig.Group.UNKNOWN: continue
		
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_theme_constant_override("separation", 12)
		legend_grid.add_child(hbox)
		
		var rect = ColorRect.new()
		rect.custom_minimum_size = Vector2(40, 40)
		rect.color = AtomicConfig.GROUP_COLORS[group]
		rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(rect)
		
		var lbl = Label.new()
		lbl.text = AtomicConfig.Group.find_key(group).replace("_", " ").capitalize()
		lbl.add_theme_font_size_override("font_size", 26)
		hbox.add_child(lbl)

func _get_cached_style(monster: MonsterData, is_owned: bool) -> StyleBoxFlat:
	var group = -1
	if monster and "group" in monster:
		group = monster.group
		
	var key = str(group) + "_" + str(is_owned)
	if _style_cache.has(key):
		return _style_cache[key]
		
	var style = StyleBoxFlat.new()
	var card_color = Color("#010813")
	if group != -1:
		card_color = AtomicConfig.GROUP_COLORS.get(group, card_color)
		if not is_owned:
			card_color = card_color.darkened(0.7)
	
	style.bg_color = card_color
	style.bg_color.a = 0.5
	style.set_corner_radius_all(8)
	
	_style_cache[key] = style
	return style

func _find_monster_by_z(z: int) -> MonsterData:
	# 1. Check if player owns it (return the specific instance with stats)
	if _owned_lookup.has(z):
		return _owned_lookup[z]
			
	# 2. Fallback to base resource
	return MonsterManifest.get_monster(z)

func _on_monster_clicked(monster: MonsterData):
	PlayerData.selected_monster = monster
	GlobalManager.switch_scene("detail_view")

func _show_run_dialog(z: int, monster: MonsterData, has_blueprint: bool):
	_selected_run_z = z
	var m_name = monster.monster_name if monster else "Unknown Element"
	var title = "Discovery Run: %s" % m_name
	
	var difficulty_level = max(1, z/2)
	var star_count = clampi(int(ceil(difficulty_level / 10.0)), 1, 6)
	var stars = "💀".repeat(star_count)
	var desc = "Target: Element #%d\nThreat: %s (Lv. %d)" % [z, stars, difficulty_level]
	
	if has_blueprint:
		title = "Resource Run: %s" % m_name
		desc += "\n\nBlueprint acquired.\nRun for Binding Energy?"
	else:
		desc += "\n\nReward: Unlock Blueprint + Energy"
		
	if _run_popup:
		var title_lbl = _run_popup.find_child("TitleLabel", true, false)
		var desc_lbl = _run_popup.find_child("DescriptionLabel", true, false)
		if not desc_lbl: desc_lbl = _run_popup.find_child("Label", true, false)
		
		if title_lbl: title_lbl.text = title
		if desc_lbl: desc_lbl.text = desc
		
		var icon_rect = _run_popup.find_child("MonsterIcon", true, false)
		if icon_rect:
			# Clear previous visuals
			icon_rect.texture = null
			for child in icon_rect.get_children():
				child.queue_free()
				
			if monster:
				icon_rect.visible = true
				
				# Try to load animation
				var anim_name = monster.monster_name.replace(" ", "")
				if "animation_override" in monster and monster.animation_override != "":
					anim_name = monster.animation_override
					
				var anim_path = "res://Assets/Animations/" + anim_name + ".tres"
				if ResourceLoader.exists(anim_path):
					var sprite_frames = load(anim_path)
					var sprite = AnimatedSprite2D.new()
					sprite.sprite_frames = sprite_frames
					
					var anim_to_play = "idle"
					if not sprite_frames.has_animation(anim_to_play):
						if sprite_frames.has_animation("default"):
							anim_to_play = "default"
						else:
							var anims = sprite_frames.get_animation_names()
							if anims.size() > 0:
								anim_to_play = anims[0]
					
					sprite.play(anim_to_play)
					
					var target_size = icon_rect.size if icon_rect.size != Vector2.ZERO else icon_rect.custom_minimum_size
					if target_size == Vector2.ZERO: target_size = Vector2(100, 100)
					
					sprite.position = target_size / 2
					var tex = sprite_frames.get_frame_texture(anim_to_play, 0)
					if tex:
						var s = min(target_size.x, target_size.y) / float(tex.get_height())
						sprite.scale = Vector2(s, s)
					icon_rect.add_child(sprite)
				elif monster.icon:
					icon_rect.texture = monster.icon
			else:
				# Hide the icon if there's no monster data (e.g., placeholder)
				icon_rect.visible = false
		_run_popup.visible = true
		_run_popup.move_to_front()

func _on_start_run_confirmed():
	if _run_popup: _run_popup.visible = false
	if CampaignManager:
		CampaignManager.start_node_run(_selected_run_z)

func _on_back_pressed():
	GlobalManager.switch_scene("main_menu")

func _update_zoom_wrapper():
	var grid = find_child("GridContainer", true, false)
	if grid and _zoom_wrapper:
		_zoom_wrapper.custom_minimum_size = grid.size * grid.scale

func _input(event):
	var grid = find_child("GridContainer", true, false)
	if not grid or not _zoom_wrapper: return

	if event is InputEventScreenTouch:
		if event.pressed:
			_is_dragging = false
			if event.index == 0:
				_drag_start_pos = event.position
			_touch_points[event.index] = event.position
		else:
			_touch_points.erase(event.index)
		
		if _touch_points.size() == 2:
			var p1 = _touch_points.values()[0]
			var p2 = _touch_points.values()[1]
			_start_zoom_dist = p1.distance_to(p2)
			_start_scale = grid.scale
			_start_pinch_center = (p1 + p2) / 2.0
			if _scroll_container:
				_start_scroll_offset = Vector2(_scroll_container.scroll_horizontal, _scroll_container.scroll_vertical)
			
	elif event is InputEventScreenDrag:
		if not _is_dragging:
			if _touch_points.size() > 1:
				_is_dragging = true
			elif event.index == 0 and event.position.distance_to(_drag_start_pos) > 20.0:
				_is_dragging = true
		
		if _touch_points.has(event.index):
			_touch_points[event.index] = event.position
			
		if _touch_points.size() == 2:
			var p1 = _touch_points.values()[0]
			var p2 = _touch_points.values()[1]
			var current_dist = p1.distance_to(p2)
			var current_center = (p1 + p2) / 2.0
			
			if _start_zoom_dist > 0:
				var zoom_factor = current_dist / _start_zoom_dist
				var new_scale = _start_scale * zoom_factor
				new_scale = new_scale.clamp(Vector2(0.5, 0.5), Vector2(3.0, 3.0))
				
				if _scroll_container:
					var container_global_pos = _scroll_container.global_position
					var point_on_grid_unscaled = (_start_pinch_center + _start_scroll_offset - container_global_pos) / _start_scale
					
					grid.scale = new_scale
					_update_zoom_wrapper()
					
					var new_scroll_pos = (point_on_grid_unscaled * new_scale) - (current_center - container_global_pos)
					_scroll_container.scroll_horizontal = int(new_scroll_pos.x)
					_scroll_container.scroll_vertical = int(new_scroll_pos.y)

func _setup_legend_ui():
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	add_child(_ui_layer)

	# Styling
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#60fafc")
	style.bg_color.a = 0.9
	style.set_corner_radius_all(8)
	
	var hover_style = style.duplicate()
	hover_style.bg_color = style.bg_color.lightened(0.2)
	
	# --- Synergy Button ---
	var syn_btn = Button.new()
	syn_btn.text = "Synergies"
	syn_btn.add_theme_font_size_override("font_size", 32)
	syn_btn.add_theme_stylebox_override("normal", style)
	syn_btn.add_theme_stylebox_override("hover", hover_style)
	syn_btn.add_theme_stylebox_override("pressed", style)
	syn_btn.add_theme_color_override("font_color", Color("#010813"))
	
	# Position top-left
	syn_btn.anchor_left = 0.0
	syn_btn.anchor_right = 0.0
	syn_btn.offset_left = 30
	syn_btn.offset_top = 30
	syn_btn.offset_right = 220
	syn_btn.offset_bottom = 100
	syn_btn.pressed.connect(_show_synergy_popup)
	_ui_layer.add_child(syn_btn)
	
func _show_synergy_popup():
	var scene = load("res://Scenes/SynergyView.tscn")
	if scene:
		var popup = scene.instantiate()
		_ui_layer.add_child(popup)
