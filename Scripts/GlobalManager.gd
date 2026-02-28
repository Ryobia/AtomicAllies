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
	"battle_prepare": "res://Scenes/BattlePrepare.tscn",
	"nursery": "res://Scenes/Nursery.tscn",
	"detail_view": "res://Scenes/DetailView.tscn",
	"periodic_table": "res://Scenes/PeriodicTable.tscn",
	"rest_site": "res://Scenes/RestSite.tscn",
	"synergy_view": "res://Scenes/SynergyView.tscn",
}

var tooltip_theme: Theme

func _ready():
	_create_tooltip_theme()

func _create_tooltip_theme():
	tooltip_theme = Theme.new()
	var tooltip_bg = StyleBoxFlat.new()
	tooltip_bg.bg_color = Color(0.02, 0.05, 0.1, 0.95) # Less transparent
	tooltip_bg.border_width_left = 1
	tooltip_bg.border_width_top = 1
	tooltip_bg.border_width_right = 1
	tooltip_bg.border_width_bottom = 1
	tooltip_bg.border_color = Color("#60fafc")
	tooltip_bg.content_margin_left = 10
	tooltip_bg.content_margin_right = 10
	tooltip_bg.content_margin_top = 5
	tooltip_bg.content_margin_bottom = 5
	tooltip_theme.set_stylebox("panel", "TooltipPanel", tooltip_bg)
	tooltip_theme.set_color("font_color", "TooltipLabel", Color("#60fafc"))
	tooltip_theme.set_font_size("font_size", "TooltipLabel", 20)

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
