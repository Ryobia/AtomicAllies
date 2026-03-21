extends Control

var daily_ad_btn

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

	# Help Button
	var help_btn = find_child("HelpButton", true, false)
	var help_popup = find_child("HelpPopup", true, false)
	
	if help_btn and help_popup:
		help_btn.pressed.connect(func(): help_popup.visible = true)

	# Progress Button
	var progress_btn = find_child("ProgressButton", true, false)
	var progress_popup = find_child("ProgressPopup", true, false)
	if progress_btn and progress_popup:
		progress_btn.pressed.connect(func(): progress_popup.visible = true)

	# Quest Button
	var quest_btn = find_child("QuestButton", true, false)
	var quest_log = find_child("QuestLog", true, false)
	
	if quest_btn and quest_log:
		quest_btn.pressed.connect(func(): quest_log.visible = true)
		# Update badge when log is closed (in case reward was claimed)
		quest_log.visibility_changed.connect(_update_quest_badge)
		
	_update_quest_badge()

	# --- Daily Ad / Free Cores System ---
	daily_ad_btn = find_child("DailyAdButton", true, false)
	var daily_ad_popup = find_child("DailyAdPopup", true, false)
	var watch_ad_btn = find_child("WatchAdButton", true, false)
	var close_ad_btn = find_child("CloseAdPopupButton", true, false)
	
	if daily_ad_btn and daily_ad_popup:
		daily_ad_btn.pressed.connect(_on_daily_ad_btn_pressed)
		
	if close_ad_btn and daily_ad_popup:
		close_ad_btn.pressed.connect(func(): daily_ad_popup.visible = false)
		
	if watch_ad_btn:
		watch_ad_btn.pressed.connect(_on_watch_ad_pressed)
		
	# Listen for the reward signal
	if AdManager and not AdManager.reward_earned.is_connected(_on_ad_reward_earned):
		AdManager.reward_earned.connect(_on_ad_reward_earned)

	# Trigger tutorial check
	if TutorialManager:
		TutorialManager.check_tutorial_progress()

func _process(delta):
	if is_instance_valid(daily_ad_btn):
		# Fetch the timestamp of the last free core reward (0 if never claimed)
		var last_time = int(PlayerData.settings.get("last_free_core_time", 0))
		var current_time = int(Time.get_unix_time_from_system())
		var time_passed = current_time - last_time
		var cooldown = 1800 # 30 minutes in seconds
		
		if time_passed < cooldown:
			var time_left = int(cooldown - time_passed)
			var mins = time_left / 60
			var secs = time_left % 60
			
			var time_str = "Free Cores (%02d:%02d)" % [mins, secs]
			if "text" in daily_ad_btn:
				daily_ad_btn.text = time_str
			elif daily_ad_btn.has_node("Label"):
				daily_ad_btn.get_node("Label").text = time_str
				
			daily_ad_btn.modulate = Color(0.5, 0.5, 0.5, 1.0) # Dim the button
			daily_ad_btn.set_meta("on_cooldown", true)
		elif daily_ad_btn.has_meta("on_cooldown") and daily_ad_btn.get_meta("on_cooldown"):
			if "text" in daily_ad_btn:
				daily_ad_btn.text = "Free Cores"
			elif daily_ad_btn.has_node("Label"):
				daily_ad_btn.get_node("Label").text = "Free Cores"
				
			daily_ad_btn.modulate = Color(1.0, 1.0, 1.0, 1.0) # Restore original color
			daily_ad_btn.set_meta("on_cooldown", false)

func _exit_tree():
	# Clean up the signal connection when leaving the main menu so we don't accidentally
	# trigger the Main Menu reward while watching a Fatigue ad in the Detail View.
	if AdManager and AdManager.reward_earned.is_connected(_on_ad_reward_earned):
		AdManager.reward_earned.disconnect(_on_ad_reward_earned)

func _update_quest_badge():
	var badge = find_child("NotificationBadge", true, false)
	if badge:
		badge.visible = PlayerData.is_quest_claimable()

func _on_daily_ad_btn_pressed():
	var last_time = int(PlayerData.settings.get("last_free_core_time", 0))
	var current_time = int(Time.get_unix_time_from_system())
	var time_passed = current_time - last_time
	var cooldown = 1800 # 30 minutes in seconds
	
	if time_passed < cooldown:
		var time_left = int(cooldown - time_passed)
		var mins = time_left / 60
		var secs = time_left % 60
		if AdManager and AdManager.has_method("show_toast"):
			AdManager.show_toast("Reward not ready. Come back in %02d:%02d!" % [mins, secs])
	else:
		var daily_ad_popup = find_child("DailyAdPopup", true, false)
		if daily_ad_popup:
			daily_ad_popup.visible = true

func _on_watch_ad_pressed():
	if AdManager:
		AdManager.show_rewarded_ad()

func _on_ad_reward_earned(reward_type, amount):
	# Hide the popup upon returning from the ad
	var daily_ad_popup = find_child("DailyAdPopup", true, false)
	if daily_ad_popup:
		daily_ad_popup.visible = false
		
	# Award the premium currency
	if PlayerData:
		# Record the current time to start the 30-minute cooldown
		PlayerData.settings["last_free_core_time"] = int(Time.get_unix_time_from_system())
		PlayerData.add_resource("luminous_core", 5)
		print("Main Menu: Awarded 5 Luminous Cores!")
