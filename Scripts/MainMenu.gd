extends Control

func _ready():
	# Use find_child to locate buttons anywhere in the scene tree
	# This allows you to move buttons into containers without breaking the script
	var battle_btn = find_child("BattleButton", true, false)
	var breeding_btn = find_child("NexusButton", true, false)
	var synthesis_btn = find_child("SynthesisButton", true, false)
	
	# Check for both common names just in case
	var collection_btn = find_child("MonsterButton", true, false)
	if not collection_btn:
		collection_btn = find_child("CollectionButton", true, false)
		
	# var quit_btn = find_child("QuitButton", true, false)
	
	if battle_btn:
		if not battle_btn.pressed.is_connected(_on_battle_pressed):
			battle_btn.pressed.connect(_on_battle_pressed)
	else:
		print("MainMenu: BattleButton not found")
	
	if breeding_btn:
		if not breeding_btn.pressed.is_connected(_on_breeding_pressed):
			breeding_btn.pressed.connect(_on_breeding_pressed)
	else:
		print("MainMenu: BreedingButton not found")
		
	if collection_btn:
		if not collection_btn.pressed.is_connected(_on_collection_pressed):
			collection_btn.pressed.connect(_on_collection_pressed)
	else:
		print("MainMenu: MonsterButton/CollectionButton not found")

	if synthesis_btn:
		if not synthesis_btn.pressed.is_connected(_on_synthesis_pressed):
			synthesis_btn.pressed.connect(_on_synthesis_pressed)
	else:
		print("MainMenu: SynthesisButton not found")

func _on_battle_pressed():
	GlobalManager.switch_scene("battle")

func _on_breeding_pressed():
	GlobalManager.switch_scene("nexus")

func _on_collection_pressed():
	GlobalManager.switch_scene("periodic_table")

func _on_synthesis_pressed():
	GlobalManager.switch_scene("nursery")