# c:\Users\ryobi\Projects\nexus\Scripts\GlobalManager.gd
extends Node

signal scene_changed(scene_key)

# Dictionary to hold the paths to your scenes.
# IMPORTANT: Make sure these paths match where you actually save your .tscn files!
var scenes = {
	"main_menu": "res://Scenes/MainMenu.tscn",
	"nexus": "res://Scenes/Nexus.tscn",
	"collection": "res://Scenes/Collection.tscn",
	"battle": "res://Scenes/BattleManager.tscn",
	"nursery": "res://Scenes/Nursery.tscn",
	"detail_view": "res://Scenes/DetailView.tscn",
	"periodic_table": "res://Scenes/PeriodicTable.tscn",
	"attunement": "res://Scenes/AttunementChamber.tscn",
}

func switch_scene(scene_key: String):
	print("GlobalManager: Switching to " + scene_key)
	if scenes.has(scene_key):
		var path = scenes[scene_key]
		# Check if the file actually exists before trying to load it
		if ResourceLoader.exists(path):
			get_tree().call_deferred("change_scene_to_file", path)
			scene_changed.emit(scene_key)
		else:
			print("CRITICAL ERROR: Could not find scene file at: " + path)
			print("Please check that the file exists and the path in GlobalManager.gd is correct.")
	else:
		print("Error: Scene key '" + scene_key + "' not found in GlobalManager.scenes dictionary.")
