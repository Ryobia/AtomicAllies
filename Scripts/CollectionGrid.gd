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
	
	# 2. Loop through the global player data
	for monster in PlayerData.owned_monsters:
		if monster_card_scene:
			var card = monster_card_scene.instantiate()
			grid.add_child(card)
			
			# Make the card expand to fill the grid cell
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			
			# 3. Pass the data to the card
			if card.has_method("set_monster"):
				card.set_monster(monster)
		else:
			print("Error: Monster Card Scene is not assigned in the Inspector!")

func _on_back_button_pressed():
	GlobalManager.switch_scene("main_menu")
