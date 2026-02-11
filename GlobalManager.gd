extends Node

# Dictionary to hold the paths to your scenes
var scenes = {
	"main_menu": "res://scenes/menus/MainMenu.tscn",
	"collection": "res://scenes/collection/CollectionGrid.tscn",
	# We'll add "nexus", "nursery", and "battle" here later
}

# The actual function to switch scenes
func switch_scene(scene_key: String):
	if scenes.has(scene_key):
		# We use deferred to ensure the current scene finishes its logic first
		get_tree().call_deferred("change_scene_to_file", scenes[scene_key])
	else:
		print("Error: Scene key '", scene_key, "' not found!")