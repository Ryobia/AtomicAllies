extends Node2D

# --- Variables ---
# Drag your monster .tres files here in the Godot Inspector for easy testing
@export var player_monster_data: MonsterData
@export var enemy_monster_data: MonsterData

# Links to our UI nodes
@onready var player_monster_sprite = $PlayerMonsterSprite
@onready var enemy_monster_sprite = $EnemyMonsterSprite
@onready var player_health_bar = $UI/PlayerHealthBar
@onready var enemy_health_bar = $UI/EnemyHealthBar
@onready var attack_button = $UI/AttackButton
@onready var turn_result_label = $UI/TurnResultLabel

# In-battle stats
var player_current_health: float
var enemy_current_health: float
var player_has_surge: bool = false
var enemy_has_surge: bool = false


# --- Godot Functions ---
func _ready():
	# Connect the button's "pressed" signal to our function
	attack_button.pressed.connect(_on_attack_button_pressed)
	
	# Initialize the battle
	setup_battle()


# --- Battle Logic ---
func setup_battle():
	# Load monster data into the battle
	player_current_health = player_monster_data.base_health
	enemy_current_health = enemy_monster_data.base_health
	
	# Update the UI
	player_health_bar.max_value = player_monster_data.base_health
	player_health_bar.value = player_current_health
	enemy_health_bar.max_value = enemy_monster_data.base_health
	enemy_health_bar.value = enemy_current_health
	
	turn_result_label.text = "Battle Start!"

func _on_attack_button_pressed():
	# 1. Call the global CombatManager to get the damage result
	var result = CombatManager.calculate_damage(player_monster_data, enemy_monster_data, 10, player_has_surge)
	
	# 2. Apply the result
	enemy_current_health -= result.damage
	enemy_health_bar.value = enemy_current_health
	turn_result_label.text = "You dealt %s damage!" % result.damage
	
	# 3. Handle the Surge mechanic (this is a simplified version)
	enemy_has_surge = result.gives_surge
	player_has_surge = false # Attacking consumes your surge
	
	if enemy_current_health <= 0:
		turn_result_label.text = "You Win!"
		attack_button.disabled = true
