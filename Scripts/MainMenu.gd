# c:\Users\ryobi\Projects\nexus\Scripts\MainMenu.gd
extends Control

func _ready():
	# Connect your buttons.
	# We use find_child to locate them anywhere in the scene tree (e.g. inside MarginContainers)
	
	var collection_btn = find_child("CollectionButton", true, false)
	if collection_btn:
		collection_btn.pressed.connect(_on_collection_pressed)
	else:
		print("Error: Could not find 'CollectionButton' in MainMenu")
	
	var nexus_btn = find_child("NexusButton", true, false)
	if nexus_btn:
		nexus_btn.pressed.connect(_on_nexus_pressed)
	else:
		print("Error: Could not find 'NexusButton' in MainMenu")
		
	var battle_btn = find_child("BattleButton", true, false)
	if battle_btn:
		battle_btn.pressed.connect(_on_battle_pressed)
	else:
		print("Error: Could not find 'BattleButton' in MainMenu")
	
	var nursery_btn = find_child("NurseryButton", true, false)
	if nursery_btn:
		nursery_btn.pressed.connect(_on_nursery_pressed)
	else:
		print("Error: Could not find 'NurseryButton' in MainMenu")

func _on_collection_pressed():
	print("MainMenu: Collection button pressed")
	GlobalManager.switch_scene("collection")

func _on_nexus_pressed():
	print("MainMenu: Nexus button pressed")
	GlobalManager.switch_scene("nexus")

func _on_battle_pressed():
	print("MainMenu: Battle button pressed")
	GlobalManager.switch_scene("battle")

func _on_nursery_pressed():
	print("MainMenu: Nursery button pressed")
	GlobalManager.switch_scene("nursery")
