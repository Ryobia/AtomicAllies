extends Control

@export var monster_card_scene: PackedScene

var research_popup

func _ready():
	var grid = find_child("GridContainer", true, false)
	if grid:
		grid.columns = 18 # Standard Periodic Table width
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		_populate_table(grid)
	
	var back_btn = find_child("BackButton", true, false)
	if back_btn:
		if not back_btn.pressed.is_connected(_on_back_pressed):
			back_btn.pressed.connect(_on_back_pressed)
			
	research_popup = find_child("ResearchNotesPopup", true, false)
	if research_popup:
		research_popup.visible = false

func _populate_table(grid: GridContainer):
	# Clear existing
	for child in grid.get_children():
		child.queue_free()
	
	# --- Row 1 ---
	_add_card(grid, 1) # Hydrogen
	_add_spacers(grid, 16) # Gap
	_add_card(grid, 2) # Helium
	
	# --- Row 2 ---
	_add_card(grid, 3) # Lithium
	_add_card(grid, 4) # Beryllium
	_add_spacers(grid, 10) # Gap (Transition Metals skipped in row 2)
	for z in range(5, 11): # Boron (5) through Neon (10)
		_add_card(grid, z)
		
	# --- Row 3 ---
	_add_card(grid, 11) # Sodium
	_add_card(grid, 12) # Magnesium
	_add_spacers(grid, 10)
	for z in range(13, 19): _add_card(grid, z) # Al - Ar
	
	# --- Row 4 ---
	for z in range(19, 37): _add_card(grid, z) # K - Kr
	
	# --- Row 5 ---
	for z in range(37, 55): _add_card(grid, z) # Rb - Xe
	
	# --- Row 6 ---
	_add_card(grid, 55) # Cs
	_add_card(grid, 56) # Ba
	_add_spacers(grid, 1) # Lanthanide placeholder gap
	for z in range(72, 87): _add_card(grid, z) # Hf - Rn
	
	# --- Row 7 ---
	_add_card(grid, 87) # Fr
	_add_card(grid, 88) # Ra
	_add_spacers(grid, 1) # Actinide placeholder gap
	for z in range(104, 119): _add_card(grid, z) # Rf - Og
	
	# --- Spacing Row (Vertical Gap) ---
	_add_spacers(grid, 18)
	
	# --- Lanthanides (Row 8) ---
	_add_spacers(grid, 3) # Indent to align with Group 3
	for z in range(57, 72): _add_card(grid, z) # La - Lu
	
	# --- Actinides (Row 9) ---
	_add_spacers(grid, 3) # Indent
	for z in range(89, 104): _add_card(grid, z) # Ac - Lr

func _add_card(grid: Container, z: int):
	if not monster_card_scene: return
	
	var card = monster_card_scene.instantiate()
	grid.add_child(card)
	
	# Force a fixed size for the table cells so they align perfectly
	card.custom_minimum_size = Vector2(100, 120) 
	
	var monster = _find_monster_by_z(z)
	
	if monster:
		card.set_monster(monster)
		
		if PlayerData.is_monster_owned(monster.monster_name):
			card.modulate = Color(1, 1, 1, 1) # Full Color
			card.mouse_filter = Control.MOUSE_FILTER_STOP
			card.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					_on_monster_clicked(monster)
			)
		else:
			# Not owned: Dark Silhouette
			card.modulate = Color(0.2, 0.2, 0.2, 1.0)
			# Allow clicking to see research notes
			card.mouse_filter = Control.MOUSE_FILTER_STOP
			card.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					_on_research_clicked(z, monster)
			)
	else:
		# Placeholder for elements not yet implemented
		card.modulate = Color(0.1, 0.1, 0.1, 0.5)
		var num_lbl = card.find_child("NumberLabel", true, false)
		if num_lbl: num_lbl.text = str(z)
		var name_lbl = card.find_child("NameLabel", true, false)
		if name_lbl: name_lbl.text = ""
		var icon = card.find_child("IconTexture", true, false)
		if icon: icon.texture = null
		
		# Allow clicking to see research notes for placeholders
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_research_clicked(z, null)
		)

func _add_spacers(grid: Container, count: int):
	for i in range(count):
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(100, 120) # Match card size
		grid.add_child(spacer)

func _find_monster_by_z(z: int) -> MonsterData:
	for path in PlayerData.starter_monster_paths:
		if ResourceLoader.exists(path):
			var m = load(path)
			if m and m.atomic_number == z:
				return m
	return null

func _on_monster_clicked(monster: MonsterData):
	PlayerData.selected_monster = monster
	GlobalManager.switch_scene("detail_view")

func _on_research_clicked(z: int, monster: MonsterData):
	if research_popup:
		research_popup.setup(z, monster)

func _on_back_pressed():
	GlobalManager.switch_scene("main_menu")
