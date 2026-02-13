# c:\Users\ryobi\Projects\nexus\Scripts\CollectionGrid.gd
extends Control

# Drag your MonsterCard.tscn file into this slot in the Inspector
@export var monster_card_scene: PackedScene

# Adjust this path to point to your GridContainer
@onready var grid = $ScrollContainer/GridContainer

func _ready():
	# Set padding between cards programmatically
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	
	# Make the grid responsive (adjust columns based on screen width)
	get_tree().root.size_changed.connect(_on_screen_resize)
	_on_screen_resize()
	
	# Connect the Back Button automatically
	var back_btn = find_child("BackButton", true, false)
	if back_btn:
		if not back_btn.pressed.is_connected(_on_back_button_pressed):
			back_btn.pressed.connect(_on_back_button_pressed)
	
	update_collection_display()

func _on_screen_resize():
	var screen_width = get_viewport_rect().size.x
	# Adjust 160 to be the minimum width you want for a card
	var columns = floor(screen_width / 160.0)
	grid.columns = min(4, max(2, columns)) # Ensure between 2 and 4 columns

func update_collection_display():
	# 1. Clear any existing placeholder cards
	for child in grid.get_children():
		child.queue_free()
	
	# 2. Load all possible monsters to create the "Periodic Table"
	var all_monsters = []
	for path in PlayerData.starter_monster_paths:
		if ResourceLoader.exists(path):
			all_monsters.append(load(path))
	
	# Sort by Atomic Number (Z)
	all_monsters.sort_custom(func(a, b): return a.atomic_number < b.atomic_number)
	
	# 3. Create a card for every element (Owned or Not)
	for monster in all_monsters:
		if monster_card_scene:
			var card = monster_card_scene.instantiate()
			grid.add_child(card)
			
			# Make the card expand to fill the grid cell
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			# Pass the data to the card
			if card.has_method("set_monster"):
				card.set_monster(monster)
			
			# Check if the player actually owns this element
			if PlayerData.is_monster_owned(monster.monster_name):
				card.modulate = Color(1, 1, 1, 1) # Owned: Full Color
				
				# Make it clickable
				card.mouse_filter = Control.MOUSE_FILTER_STOP
				card.gui_input.connect(func(event):
					if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
						_on_monster_clicked(monster.monster_name)
				)
			else:
				card.modulate = Color(0, 0, 0, 0.7) # Not Owned: Silhouette
				
				# Optional: Hide the name for mystery
				var label = card.find_child("Label", true, false)
				if label:
					label.text = "#%d ???" % monster.atomic_number
		else:
			print("Error: Monster Card Scene is not assigned in the Inspector!")

func _on_monster_clicked(monster_name: String):
	var owned_monster = PlayerData.get_owned_monster(monster_name)
	if owned_monster:
		PlayerData.selected_monster = owned_monster
		GlobalManager.switch_scene("detail_view")

func _on_back_button_pressed():
	GlobalManager.switch_scene("main_menu")
