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
var turn_timer: Timer


# --- Godot Functions ---
func _ready():
	# Create the timer programmatically if it doesn't exist in the scene
	turn_timer = find_child("TurnTimer", true, false)
	if not turn_timer:
		turn_timer = Timer.new()
		turn_timer.name = "TurnTimer"
		turn_timer.one_shot = true # We only want it to fire once per turn
		turn_timer.wait_time = 1.0 # 1 second delay between turns
		add_child(turn_timer)

	# Connect the button's "pressed" signal to our function
	attack_button.pressed.connect(_on_attack_button_pressed)
	
	if not turn_timer.timeout.is_connected(enemy_turn):
		turn_timer.timeout.connect(enemy_turn)
	
	# Connect the Back Button automatically
	var back_btn = find_child("BackButton", true, false)
	if back_btn:
		back_btn.z_index = 10 # Force button to render on top of everything else
		back_btn.move_to_front() # Reorder node to be drawn last (on top)
		if not back_btn.pressed.is_connected(_on_back_button_pressed):
			back_btn.pressed.connect(_on_back_button_pressed)
	
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
	
	# Set sprites (assuming your MonsterData has a texture property)
	player_monster_sprite.texture = player_monster_data.texture
	enemy_monster_sprite.texture = enemy_monster_data.texture
	
	turn_result_label.text = "Battle Start!"

func _on_attack_button_pressed():
	# --- Player's Turn ---
	attack_button.disabled = true # Disable button during the turn sequence
	
	# 1. Call the global CombatManager to get the damage result
	var result = CombatManager.calculate_damage(player_monster_data, enemy_monster_data)
	
	# 2. Apply the result
	enemy_current_health -= result.damage
	enemy_health_bar.value = enemy_current_health
	turn_result_label.text = "You dealt %d damage!" % round(result.damage)
	
	if enemy_current_health <= 0:
		turn_result_label.text = "You Win!"
		# No need to do anything else, battle is over
		return
	
	# 4. Wait a moment, then trigger enemy's turn
	turn_timer.start()

func enemy_turn():
	# --- Enemy's Turn ---
	turn_result_label.text = "Enemy is attacking..."
	
	var result = CombatManager.calculate_damage(enemy_monster_data, player_monster_data)
	player_current_health -= result.damage
	player_health_bar.value = player_current_health
	turn_result_label.text = "Enemy dealt %d damage!" % round(result.damage)
	
	if player_current_health <= 0:
		turn_result_label.text = "You Lose!"
		return

	# It's the player's turn again
	attack_button.disabled = false


func _on_back_button_pressed() -> void:
	GlobalManager.switch_scene("main_menu")
