extends Control

func _ready():
	# Navigation Buttons - Using find_child to be safe against hierarchy changes
	var nexus_btn = find_child("NexusButton", true, false)
	if nexus_btn:
		nexus_btn.pressed.connect(func(): GlobalManager.switch_scene("nexus"))
		
	var collection_btn = find_child("CollectionButton", true, false)
	if collection_btn:
		collection_btn.pressed.connect(func(): GlobalManager.switch_scene("collection"))
		
	var battle_btn = find_child("BattleButton", true, false)
	if battle_btn:
		battle_btn.pressed.connect(func(): GlobalManager.switch_scene("battle"))
		
	var nursery_btn = find_child("NurseryButton", true, false)
	if nursery_btn:
		nursery_btn.pressed.connect(func(): GlobalManager.switch_scene("nursery"))

	var periodic_btn = find_child("PeriodicTableButton", true, false)
	if periodic_btn:
		periodic_btn.pressed.connect(func(): GlobalManager.switch_scene("periodic_table"))

	# Connect Reset Button
	# We check for both "ResetButton" and "Reset" just in case
	var reset_btn = find_child("ResetButton", true, false)
	if not reset_btn: reset_btn = find_child("Reset", true, false)
	
	if reset_btn:
		if not reset_btn.pressed.is_connected(PlayerData.reset_save):
			reset_btn.pressed.connect(PlayerData.reset_save)
	
	# Quit Button (Optional)
	var quit_btn = find_child("QuitButton", true, false)
	if quit_btn:
		quit_btn.pressed.connect(func(): get_tree().quit())
