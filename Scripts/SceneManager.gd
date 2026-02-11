extends Node

# Dictionary to store paths to your scenes
var scenes = {
    "main_menu": "res://scenes/MainMenu.tscn",
    "breeding": "res://scenes/Nexus.tscn",
    "battle": "res://scenes/Battle.tscn"
}

func goto_scene(scene_name: String):
    var path = scenes[scene_name]
    get_tree().change_scene_to_file(path)