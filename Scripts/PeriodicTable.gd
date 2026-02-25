extends Control

@export var monster_card_scene: PackedScene

var research_popup

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

func _ready():
	# $Background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var grid = find_child("GridContainer", true, false)
	if grid:
		grid.columns = 18 # Standard Periodic Table width
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
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
			
	research_popup = find_child("ResearchNotesPopup", true, false)
	if research_popup:
		research_popup.visible = false
		
	_setup_legend_ui()

func _populate_table(grid: GridContainer):
	# Optimization: Pre-calculate owned monsters lookup
	_owned_lookup.clear()
	for m in PlayerData.owned_monsters:
		_owned_lookup[m.atomic_number] = m
	_style_cache.clear()

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
	
	# Clear lookup to free memory
	_owned_lookup.clear()

func _add_card(grid: Container, z: int):
	if not monster_card_scene: return
	
	var card = monster_card_scene.instantiate()
	grid.add_child(card)
	
	# Force a fixed size for the table cells so they align perfectly
	card.custom_minimum_size = Vector2(100, 120) 
	
	var monster = _find_monster_by_z(z)
	var is_owned = false
	if monster:
		is_owned = PlayerData.is_monster_owned(monster.monster_name)
	
	# --- Custom Styling ---
	var style = _get_cached_style(monster, is_owned)
	card.add_theme_stylebox_override("panel", style)
	
	var labels = [card.find_child("NameLabel", true, false), card.find_child("NumberLabel", true, false)]
	for lbl in labels:
		if lbl:
			if not is_owned and monster:
				lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			else:
				lbl.add_theme_color_override("font_color", Color("#60fafc"))
			lbl.add_theme_font_size_override("font_size", lbl.get_theme_font_size("font_size") + 4)
	
	if monster:
		card.set_monster(monster)
		
		if is_owned:
			card.modulate = Color(1, 1, 1, 1) # Full Color
			card.mouse_filter = Control.MOUSE_FILTER_STOP
			card.gui_input.connect(func(event):
				if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					if not _is_dragging:
						_on_monster_clicked(monster)
			)
		else:
			# Not owned: Dark Silhouette
			var icon = card.find_child("IconTexture", true, false)
			if icon: icon.modulate = Color(0, 0, 0, 0.7)
			
			# Allow clicking to see research notes
			card.mouse_filter = Control.MOUSE_FILTER_STOP
			card.gui_input.connect(func(event):
				if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					if not _is_dragging:
						_on_research_clicked(z, monster)
			)
	else:
		# Placeholder for elements not yet implemented
		card.set_placeholder(z)
		
		# Allow clicking to see research notes for placeholders
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(func(event):
			if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				if not _is_dragging:
					_on_research_clicked(z, null)
		)

func _add_spacers(grid: Container, count: int):
	for i in range(count):
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(100, 120) # Match card size
		grid.add_child(spacer)

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

func _on_research_clicked(z: int, monster: MonsterData):
	if research_popup:
		research_popup.setup(z, monster)

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
	var layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var btn = Button.new()
	btn.text = "Legend"
	btn.add_theme_font_size_override("font_size", 32)
	
	# Styling
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#60fafc")
	style.bg_color.a = 0.9
	style.set_corner_radius_all(8)
	
	var hover_style = style.duplicate()
	hover_style.bg_color = style.bg_color.lightened(0.2)
	
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_color_override("font_color", Color("#010813"))
	
	# Position top-left
	btn.anchor_left = 0.0
	btn.anchor_right = 0.0
	btn.offset_left = 30
	btn.offset_top = 30
	btn.offset_right = 190
	btn.offset_bottom = 100
	layer.add_child(btn)
	
	var panel = PanelContainer.new()
	panel.visible = false
	panel.set_anchors_preset(Control.PRESET_CENTER)
	layer.add_child(panel)
	
	# Panel Styling
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color("#010813")
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color("#60fafc")
	panel.add_theme_stylebox_override("panel", panel_style)
	
	btn.pressed.connect(func(): panel.visible = !panel.visible)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = "Atomic Classes"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 15)
	grid.add_theme_constant_override("v_separation", 5)
	vbox.add_child(grid)
	
	for group in AtomicConfig.GROUP_COLORS:
		if group == AtomicConfig.Group.UNKNOWN: continue
		
		var rect = ColorRect.new()
		rect.custom_minimum_size = Vector2(30, 30)
		rect.color = AtomicConfig.GROUP_COLORS[group]
		grid.add_child(rect)
		
		var lbl = Label.new()
		lbl.text = AtomicConfig.Group.find_key(group).replace("_", " ").capitalize()
		grid.add_child(lbl)
