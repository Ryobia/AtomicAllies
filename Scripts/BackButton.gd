extends TextureButton

# OPTIONAL: Allow us to override the destination in the Inspector
# If empty, it defaults to the Main Menu.
@export var target_scene_path: String = "" 

func _ready():
	# Visual Polish: Set the pivot to the center so it scales nicely
	pivot_offset = size / 2
	
	# Connect the signal automatically
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_exit)

func _on_pressed():
	# 1. Click Animation (Squish)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.05)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.05)
	
	# 2. Wait for animation to finish
	await tween.finished
	
	# 3. Go Back
	if target_scene_path != "":
		get_tree().change_scene_to_file(target_scene_path)
	else:
		# Use GlobalManager if available to ensure consistent navigation
		if GlobalManager:
			GlobalManager.switch_scene("main_menu")
		else:
			# Fallback: Ensure the path matches your project structure (Capital 'S' in Scenes)
			get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

# -- HOVER EFFECTS (Optional "Juice") --
func _on_hover():
	# Make it slightly brighter or bigger when hovering
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1.2, 1.2, 1.5), 0.1) # Glow blueish

func _on_exit():
	# Return to normal color
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.1)