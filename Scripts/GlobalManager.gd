# c:\Users\ryobi\Projects\nexus\Scripts\GlobalManager.gd
extends Node

# Dictionary to hold the paths to your scenes.
# IMPORTANT: Make sure these paths match where you actually save your .tscn files!
var scenes = {
	"main_menu": "res://Scenes/MainMenu.tscn",
	"nexus": "res://Scenes/Nexus.tscn",
	"collection": "res://Scenes/Collection.tscn",
	"battle": "res://Scenes/Battle.tscn"
}

func switch_scene(scene_key: String):
	if scenes.has(scene_key):
		# call_deferred is safer when switching scenes during button callbacks
		get_tree().call_deferred("change_scene_to_file", scenes[scene_key])
	else:
		print("Error: Scene key '" + scene_key + "' not found in GlobalManager.scenes dictionary.")
