# c:\Users\ryobi\Projects\nexus\Scripts\MainMenu.gd
extends Control

func _ready():
	# Connect your buttons. 
	# NOTE: Adjust the paths (e.g., $VBoxContainer/CollectionButton) to match your Scene Tree.
	
	if has_node("VBoxContainer/CollectionButton"):
		$VBoxContainer/CollectionButton.pressed.connect(_on_collection_pressed)
	
	if has_node("VBoxContainer/NexusButton"):
		$VBoxContainer/NexusButton.pressed.connect(_on_nexus_pressed)
		
	if has_node("VBoxContainer/BattleButton"):
		$VBoxContainer/BattleButton.pressed.connect(_on_battle_pressed)

func _on_collection_pressed():
	GlobalManager.switch_scene("collection")

func _on_nexus_pressed():
	GlobalManager.switch_scene("nexus")

func _on_battle_pressed():
	GlobalManager.switch_scene("battle")
