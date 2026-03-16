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
	"item_shop": "res://Scenes/ItemShop.tscn",
	"codex": "res://Scenes/Codex.tscn",
}

const SCENE_ORDER = {
	"nursery": 0,
	"synthesis": 0,
	"nexus": 1,
	"main_menu": 2,
	"item_shop": 3,
	"shop": 3,
	"collection": 4,
	"periodic_table": 4
}

var current_scene_name: String = "main_menu"
var _is_transitioning: bool = false

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
	if _is_transitioning or scene_key == current_scene_name: 
		return
		
	print("GlobalManager: Switching to " + scene_key)
	if scenes.has(scene_key):
		var path = scenes[scene_key]
		# Check if the file actually exists before trying to load it
		if ResourceLoader.exists(path):
			var new_scene_resource = load(path)
			if not new_scene_resource: return
			
			var new_scene = new_scene_resource.instantiate()
			var root = get_tree().root
			var old_scene = get_tree().current_scene
			
			var current_index = SCENE_ORDER.get(current_scene_name, -1)
			var new_index = SCENE_ORDER.get(scene_key, -1)
			
			# If one of the scenes isn't in our layout map, use a fade-to-black transition
			if current_index == -1 or new_index == -1 or current_index == new_index:
				_is_transitioning = true
				
				var fade_layer = CanvasLayer.new()
				fade_layer.layer = 150 # High above the UI
				var fade_rect = ColorRect.new()
				fade_rect.color = Color.BLACK
				fade_rect.modulate.a = 0.0
				fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
				fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP # Block clicks during fade
				fade_layer.add_child(fade_rect)
				root.add_child(fade_layer)
				
				var fade_in = create_tween()
				fade_in.tween_property(fade_rect, "modulate:a", 1.0, 0.3)
				fade_in.finished.connect(func():
					root.add_child(new_scene)
					get_tree().current_scene = new_scene
					if is_instance_valid(old_scene):
						old_scene.queue_free()
					current_scene_name = scene_key
					scene_changed.emit(scene_key)
					
					var fade_out = create_tween()
					fade_out.tween_property(fade_rect, "modulate:a", 0.0, 0.3)
					fade_out.finished.connect(func():
						fade_layer.queue_free()
						_is_transitioning = false
					)
				)
				return
				
			_is_transitioning = true
			
			# Determine direction: 1 = slide from right, -1 = slide from left
			var dir = 1 if new_index > current_index else -1
			var screen_width = get_viewport().get_visible_rect().size.x
			
			# Position the new scene completely off-screen in the correct direction
			new_scene.position.x = screen_width * dir
			root.add_child(new_scene)
			get_tree().current_scene = new_scene # Update Godot's internal reference
			
			# Create the smooth sliding animation
			var tween = create_tween()
			tween.set_parallel(true)
			
			# Slide old scene out
			if is_instance_valid(old_scene):
				tween.tween_property(old_scene, "position:x", -screen_width * dir, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
				
			# Slide new scene in to 0
			tween.tween_property(new_scene, "position:x", 0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
			
			# Clean up after the animation finishes
			tween.chain().tween_callback(func():
				if is_instance_valid(old_scene):
					old_scene.queue_free()
				_is_transitioning = false
				current_scene_name = scene_key
				scene_changed.emit(scene_key)
			)
		else:
			print("CRITICAL ERROR: Could not find scene file at: " + path)
			print("Please check that the file exists and the path in GlobalManager.gd is correct.")
	else:
		print("Error: Scene key '" + scene_key + "' not found in GlobalManager.scenes dictionary.")
