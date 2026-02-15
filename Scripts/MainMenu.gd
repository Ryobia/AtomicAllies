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
		
	# --- Resource Header Logic ---
	update_resource_display()
	
	# Connect to global signal to update UI automatically
	if not PlayerData.resource_updated.is_connected(_on_resource_updated):
		PlayerData.resource_updated.connect(_on_resource_updated)

func _on_battle_pressed():
	GlobalManager.switch_scene("battle")

func _on_breeding_pressed():
	GlobalManager.switch_scene("nexus")

func _on_collection_pressed():
	GlobalManager.switch_scene("periodic_table")

func _on_synthesis_pressed():
	GlobalManager.switch_scene("nursery")

func update_resource_display():
	# We look for labels that might be inside a Header container
	var xp_lbl = find_child("XPLabel", true, false)
	var dust_lbl = find_child("DustLabel", true, false)
	var gem_lbl = find_child("GemLabel", true, false)
	
	if xp_lbl: xp_lbl.text = str(PlayerData.resources.get("experience", 0))
	if dust_lbl: dust_lbl.text = str(PlayerData.resources.get("neutron_dust", 0))
	if gem_lbl: gem_lbl.text = str(PlayerData.resources.get("gems", 0))

func _on_resource_updated(_type, _amount):
	update_resource_display()