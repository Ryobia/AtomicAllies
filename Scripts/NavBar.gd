extends CanvasLayer

func _ready():
	# Connect to GlobalManager to listen for scene changes
	if GlobalManager:
		GlobalManager.scene_changed.connect(_on_scene_changed)
	
	# Connect your buttons
	# Ensure these node names match your Scene Tree exactly!
	_connect_btn("HomeButton", "main_menu")
	_connect_btn("CollectionButton", "periodic_table")
	_connect_btn("NexusButton", "nexus")
	
	# Try both names to ensure it works regardless of scene setup
	_connect_btn("BattleButton", "battle")
	_connect_btn("SynthesisButton", "nursery")

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
	# Logic to hide the bar in specific scenes (like Battle)
	if scene_key == "battle":
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
        "battle:": ["BattleButton"] # If you add a Battle button in the future
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
