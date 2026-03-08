extends CanvasLayer

var _notify_timer: float = 0.0
var _current_scene_key: String = ""

func _ready():
	# Connect to GlobalManager to listen for scene changes
	if GlobalManager:
		GlobalManager.scene_changed.connect(_on_scene_changed)
	
	# Connect your buttons
	# Ensure these node names match your Scene Tree exactly!
	_connect_btn("HomeButton", "main_menu")
	_connect_btn("CollectionButton", "periodic_table")
	_connect_btn("NexusButton", "nexus")
	_connect_btn("ShopButton", "item_shop") # If you have a shop scene
	
	# Try both names to ensure it works regardless of scene setup
	_connect_btn("BattleButton", "battle_prepare")
	_connect_btn("SynthesisButton", "nursery")

func _process(delta):
	_notify_timer += delta
	if _notify_timer >= 1.0:
		_notify_timer = 0.0
		_update_notifications()
		_update_tutorial_highlights()

func _connect_btn(btn_name: String, scene_key: String):
	var btn = find_child(btn_name, true, false)
	if btn:
		# Disconnect if already connected (safety check)
		if btn.pressed.is_connected(_on_nav_pressed):
			btn.pressed.disconnect(_on_nav_pressed)
		
		# Bind the specific scene key to the button click
		btn.pressed.connect(_on_nav_pressed.bind(scene_key))

func _on_nav_pressed(scene_key: String):
	GlobalManager.switch_scene(scene_key)

func _on_scene_changed(scene_key: String):
	_current_scene_key = scene_key
	# Logic to hide the bar in specific scenes (like Battle)
	if scene_key == "battle" or scene_key == "battle_prepare" or scene_key == "detail_view" or scene_key == "rest_site":
		visible = false
	else:
		visible = true
		
	_update_highlights(scene_key)

func _update_highlights(active_key: String):
	# Map scene keys to potential button names
	var button_map = {
		"main_menu": ["HomeButton"],
		"periodic_table": ["CollectionButton"],
		"nexus": ["NexusButton"],
		"nursery": ["NurseryButton", "SynthesisButton"],
        "item_shop": ["ShopButton"],
	}
	
	# 1. Reset all buttons
	for key in button_map:
		for btn_name in button_map[key]:
			var btn = find_child(btn_name, true, false)
			if btn: 
				btn.modulate = Color(1, 1, 1) # Reset to normal
				btn.scale = Vector2(1.0, 1.0)
	
	# 2. Highlight active button
	if button_map.has(active_key):
		for btn_name in button_map[active_key]:
			var btn = find_child(btn_name, true, false)
			if btn: 
				btn.modulate = Color("#a360ff") 
				btn.pivot_offset = btn.size / 2
				btn.scale = Vector2(1.15, 1.15)

func _update_notifications():
	if not PlayerData: return
	var has_ready = PlayerData.has_ready_chamber()
	
	# Try to find the button (could be named differently depending on setup)
	var btn = find_child("SynthesisButton", true, false)
	if not btn: btn = find_child("NurseryButton", true, false)
	
	if btn:
		var badge = btn.find_child("NotificationBadge", true, false)
		if has_ready:
			if not badge:
				badge = Panel.new()
				badge.name = "NotificationBadge"
				badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
				
				var style = StyleBoxFlat.new()
				style.bg_color = Color("#ff4d4d") # Red
				style.set_corner_radius_all(12)
				badge.add_theme_stylebox_override("panel", style)
				
				badge.custom_minimum_size = Vector2(24, 24)
				badge.size = Vector2(24, 24)
				# Position top-right relative to button
				badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
				badge.position = Vector2(-20, 0) 
				
				btn.add_child(badge)
			badge.visible = true
		else:
			if badge: badge.visible = false

func _update_tutorial_highlights():
	if not PlayerData or not TutorialManager: return
	
	var nexus_btn = find_child("NexusButton", true, false)
	if nexus_btn:
		if PlayerData.tutorial_step == TutorialManager.Step.GO_TO_NEXUS:
			_start_pulse(nexus_btn)
		else:
			_stop_pulse(nexus_btn)

func _start_pulse(btn: Control):
	if btn.has_meta("pulse_tween"): return
	
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(btn, "modulate", Color(1.5, 1.5, 1.5), 0.5)
	tween.tween_property(btn, "modulate", Color.WHITE, 0.5)
	btn.set_meta("pulse_tween", tween)

func _stop_pulse(btn: Control):
	if btn.has_meta("pulse_tween"):
		var t = btn.get_meta("pulse_tween")
		if t and t.is_valid(): t.kill()
		btn.remove_meta("pulse_tween")
		# Restore correct state (highlighted or normal)
		_update_highlights(_current_scene_key)
