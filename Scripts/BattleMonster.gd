extends Node2D
class_name BattleMonster

signal died(monster)
signal hp_changed(new_hp, max_hp)
signal log_action(text)

# --- Data ---
var data: MonsterData
var is_player: bool
var current_hp: int
var max_hp: int
var stats: Dictionary = {}

# List of active effects (buffs, debuffs, status ailments)
var active_effects: Array = []

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
	# Duplicate so we can modify stats in battle without changing the resource
	stats = data.get_current_stats().duplicate()
	max_hp = stats.max_hp
	current_hp = max_hp

func update_atb(delta: float, tuning_factor: float = 0.5) -> float:
	if is_dead: return 0.0
	
	# Stun check
	if has_status("stun"): return atb_value
	
	var speed = stats.get("speed", 10)
	atb_value += speed * delta * tuning_factor
	return atb_value

func take_damage(amount: int, color: Color = Color("#ff4d4d")):
	if has_status("invulnerable"): amount = 0
	if has_status("vulnerable"): amount = int(amount * 1.5)
	
	current_hp = max(0, current_hp - amount)
	hp_changed.emit(current_hp, max_hp)
	
	# Hit Flash
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(10, 10, 10), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)
	_spawn_damage_number(amount, color)
	
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

func _spawn_damage_number(amount: int, color: Color):
	var label = Label.new()
	label.text = str(amount)
	label.z_index = 20 # Ensure it appears above other sprites
	label.add_theme_color_override("font_color", color)
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

func heal(amount: int):
	if is_dead: return
	current_hp = min(max_hp, current_hp + amount)
	hp_changed.emit(current_hp, max_hp)
	_spawn_damage_number(amount, Color("#2ecc71")) # Green for heals

# --- Effect Management ---

func apply_effect(effect: Dictionary):
	# 1. Immediate Effects
	if "effect" in effect:
		match effect.effect:
			"heal":
				heal(effect.amount)
			"recoil":
				take_damage(effect.amount, Color("#e67e22")) # Orange for recoil
			"cleanse":
				cleanse_negative_effects()
			"swap_stats":
				_apply_stat_swap(effect)
				
	# 2. Status Effects (Flags & DoTs)
	elif "status" in effect:
		active_effects.append({
			"type": "status",
			"name": effect.status,
			"duration": effect.duration,
			"damage": effect.get("damage", 0) # For DoT like corrosion
		})
		
	# 3. Stat Modifiers
	elif "stat" in effect:
		_apply_stat_mod(effect)

func _apply_stat_mod(effect: Dictionary):
	# Apply the mod immediately to current stats
	if effect.stat in stats:
		stats[effect.stat] += effect.amount
		
		# Store it to revert later
		active_effects.append({
			"type": "stat_mod",
			"stat": effect.stat,
			"amount": effect.amount,
			"duration": effect.duration
		})

func _apply_stat_swap(effect: Dictionary):
	var s1 = effect.stats[0]
	var s2 = effect.stats[1]
	
	if s1 in stats and s2 in stats:
		# Swap current values
		var v1 = stats[s1]
		var v2 = stats[s2]
		stats[s1] = v2
		stats[s2] = v1
		
		active_effects.append({
			"type": "swap_stats",
			"stats": [s1, s2],
			"duration": effect.duration
		})

func has_status(status_name: String) -> bool:
	for effect in active_effects:
		if effect.type == "status" and effect.name == status_name:
			return true
	return false

func cleanse_negative_effects():
	var new_effects = []
	for effect in active_effects:
		var is_negative = false
		
		if effect.type == "status":
			if effect.name in ["stun", "corrosion", "silence_special", "marked_covalent", "vulnerable"]:
				is_negative = true
		elif effect.type == "stat_mod":
			if effect.amount < 0:
				is_negative = true
				stats[effect.stat] -= effect.amount # Revert immediately
				
		if not is_negative:
			new_effects.append(effect)
			
	active_effects = new_effects

func on_turn_start():
	for effect in active_effects:
		if effect.type == "status" and effect.name == "corrosion":
			take_damage(effect.damage)

func on_turn_end():
	var remaining_effects = []
	for effect in active_effects:
		effect.duration -= 1
		if effect.duration > 0:
			remaining_effects.append(effect)
		else:
			_remove_expired_effect(effect)
	active_effects = remaining_effects
	
	# Passive: Radioactive Decay (Actinides)
	if data.group == AtomicConfig.Group.ACTINIDE:
		# 20% chance to decay
		if randf() < 0.2:
			var decay_dmg = int(max_hp * 0.15)
			log_action.emit("%s is decaying!" % data.monster_name)
			take_damage(decay_dmg, Color("#ccff00")) # Radioactive Green

func _remove_expired_effect(effect: Dictionary):
	if effect.type == "stat_mod":
		stats[effect.stat] -= effect.amount
	elif effect.type == "swap_stats":
		var s1 = effect.stats[0]
		var s2 = effect.stats[1]
		var v1 = stats[s1]
		var v2 = stats[s2]
		stats[s1] = v2
		stats[s2] = v1