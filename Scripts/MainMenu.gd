extends Control

func _ready():
	# Start Music via AudioManager
	if AudioManager:
		var music = load("res://Assets/Sounds/Lonely Orbit.mp3")
		AudioManager.play_music(music)

	# Navigation Buttons - Using find_child to be safe against hierarchy changes
	var nexus_btn = find_child("NexusButton", true, false)
	if nexus_btn:
		nexus_btn.pressed.connect(func(): GlobalManager.switch_scene("nexus"))
		
	var collection_btn = find_child("CollectionButton", true, false)
	if collection_btn:
		collection_btn.pressed.connect(func(): GlobalManager.switch_scene("collection"))
		
	var battle_btn = find_child("BattleButton", true, false)
	if battle_btn:
		battle_btn.pressed.connect(func(): GlobalManager.switch_scene("battle_prepare"))
		
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

	# Codex Button
	var codex_btn = find_child("CodexButton", true, false)
	if codex_btn:
		codex_btn.pressed.connect(func(): GlobalManager.switch_scene("codex"))

	# Settings Button
	var settings_btn = find_child("SettingsButton", true, false)
	var settings_popup = find_child("SettingsPopup", true, false)
	
	if settings_btn and settings_popup:
		settings_btn.pressed.connect(func(): settings_popup.visible = true)

	# Quest Button
	var quest_btn = find_child("QuestButton", true, false)
	var quest_log = find_child("QuestLog", true, false)
	
	if quest_btn and quest_log:
		quest_btn.pressed.connect(func(): quest_log.visible = true)
		# Update badge when log is closed (in case reward was claimed)
		quest_log.visibility_changed.connect(_update_quest_badge)
		
	_update_quest_badge()

func _update_quest_badge():
	var badge = find_child("NotificationBadge", true, false)
	if badge:
		badge.visible = PlayerData.is_quest_claimable()
