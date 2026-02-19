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
@onready var sprite: Sprite2D = $Sprite2D

func setup(monster_data: MonsterData, player_team: bool):
	data = monster_data
	is_player = player_team
	
	# 1. Setup Visuals
	if data.icon:
		sprite.texture = data.icon
	
	if not is_player:
		sprite.flip_h = true
	
	# 2. Setup Stats
	stats = data.get_current_stats()
	max_hp = stats.max_hp
	current_hp = max_hp

func take_damage(amount: int):
	current_hp = max(0, current_hp - amount)
	hp_changed.emit(current_hp, max_hp)
	
	# Hit Flash
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(10, 10, 10), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.05)
	
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