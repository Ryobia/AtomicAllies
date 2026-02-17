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
	_connect_btn("NurseryButton", "nursery")
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
		
	# Optional: You could add logic here to highlight the active button
	# e.g. turn the "Home" button green if scene_key == "main_menu"
