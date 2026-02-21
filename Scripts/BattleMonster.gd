extends Node2D
class_name BattleMonster

signal died(monster)
signal hp_changed(new_hp, max_hp)

# --- Data ---
var data: MonsterData
var is_player: bool
var current_hp: int
var max_hp: int
var stats: Dictionary = {}

# --- ATB State ---
var atb_value: float = 0.0
var is_dead: bool = false

# --- Node References ---
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var center_marker = find_child("Center", true, false)
@onready var shadow = find_child("Shadow", true, false)

func setup(monster_data: MonsterData, player_team: bool):
	data = monster_data
	is_player = player_team
	
	# 1. Setup Visuals
	# Try to load specific animation first (e.g. "NullWalker.tres")
	# Assumes naming convention: MonsterName.tres in Assets/Animations/
	var anim_path = "res://Assets/Animations/" + data.monster_name.replace(" ", "") + ".tres"
	var loaded_frames = null
	
	if ResourceLoader.exists(anim_path):
		loaded_frames = load(anim_path)
	
	if loaded_frames:
		sprite.sprite_frames = loaded_frames
		# Robust animation playing
		var anim_to_play = "idle"
		if not loaded_frames.has_animation(anim_to_play):
			if loaded_frames.has_animation("default"):
				anim_to_play = "default"
			else:
				var anims = loaded_frames.get_animation_names()
				if anims.size() > 0:
					anim_to_play = anims[0]
		sprite.play(anim_to_play)
	elif data.icon:
		# Fallback: Create a temporary 1-frame animation from the icon
		var frames = SpriteFrames.new()
		frames.add_animation("idle")
		frames.add_frame("idle", data.icon)
		sprite.sprite_frames = frames
		sprite.play("idle")

		if shadow:
			var w = data.icon.get_width()
			var s = clamp(w / 150.0, 0.4, 1.5) # Normalize around 150px width
			shadow.scale = Vector2(s, s)
	
	if not is_player:
		sprite.flip_h = true
	
	# 2. Setup Stats
	stats = data.get_current_stats()
	max_hp = stats.max_hp
	current_hp = max_hp

func update_atb(delta: float, tuning_factor: float = 0.5) -> float:
	if is_dead: return 0.0
	
	var speed = stats.get("speed", 10)
	atb_value += speed * delta * tuning_factor
	return atb_value

func take_damage(amount: int):
	current_hp = max(0, current_hp - amount)
	hp_changed.emit(current_hp, max_hp)
	
	# Hit Flash
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(10, 10, 10), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)
	_spawn_damage_number(amount)
	
	if current_hp <= 0:
		if not is_dead: # Prevent die() from being called multiple times
			die()

func die():
	if is_dead: return
	is_dead = true
	atb_value = 0.0
	died.emit(self)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)

func _spawn_damage_number(amount: int):
	var label = Label.new()
	label.text = str(amount)
	label.z_index = 20 # Ensure it appears above other sprites
	label.add_theme_color_override("font_color", Color("#ff4d4d")) # Red color
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	
	# Center the label
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-20, -20) # Approximate centering offset
	
	# Add to a specific marker if it exists, otherwise just add to self
	if center_marker:
		center_marker.add_child(label)
	else:
		add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 50, 0.8).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	tween.tween_callback(label.queue_free)