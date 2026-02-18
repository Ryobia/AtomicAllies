extends Control

# --- Variables ---
# We now use Arrays for 3v3
var player_team: Array[MonsterData] = []
var enemy_team: Array[MonsterData] = []

# In-battle state for all 6 monsters
var player_battle_state: Array = []
var enemy_battle_state: Array = []

# Reference to the HUD scene
@onready var hud = find_child("BattleHUD", true, false)

# Battle State
var active_player_index = 0 # Which of the 3 monsters is acting?
var turn_timer: Timer


# --- Godot Functions ---
func _ready():
	# DEBUG: Load dummy data if empty
	if player_team.is_empty():
		_debug_load_teams()
	
	if hud:
		hud.setup_ui(player_team, enemy_team)
		hud.action_selected.connect(_on_player_action)
		hud.move_selected.connect(_on_move_selected)
		hud.log_message("Battle Start!")
	
	# Initialize the battle
	setup_battle()


# --- Battle Logic ---
func setup_battle():
	# Initialize HP and effects trackers for 3v3
	player_battle_state.clear()
	enemy_battle_state.clear()

	for monster in player_team:
		player_battle_state.append({
			"data": monster,
			"current_hp": monster.base_health,
			"effects": []
		})
	
	for monster in enemy_team:
		enemy_battle_state.append({
			"data": monster,
			"current_hp": monster.base_health,
			"effects": []
		})

func _on_player_action(action_type: String):
	print("Player selected: ", action_type)
	
	if action_type == "attack":
		var active_monster = player_team[active_player_index]
		hud.show_moves(active_monster.moves)

func _on_move_selected(move: MoveData):
	# For now, player always controls monster at index 0
	perform_action(0, move)
	hud.show_actions() # Reset UI to main menu

func perform_action(player_idx: int, move: MoveData):
	# Simple 1v1 logic for MVP (Front vs Front)
	var attacker_state = player_battle_state[player_idx]
	var defender_state = enemy_battle_state[0] # Always target enemy front-liner
	
	if attacker_state and defender_state:
		var result = CombatManager.process_move(
			attacker_state.data, 
			defender_state.data, 
			move, 
			attacker_state.effects, 
			defender_state.effects
		)
		
		# Apply damage
		if result.damage > 0:
			defender_state.current_hp -= result.damage
			hud.log_message("%s used %s for %d damage!" % [attacker_state.data.monster_name, move.name, result.damage])
			hud.update_hp(false, 0, defender_state.current_hp, defender_state.data.base_health)
		
		# Apply effects
		for effect in result.effects:
			if effect.target == "self":
				attacker_state.effects.append(effect)
				hud.log_message("%s used %s!" % [attacker_state.data.monster_name, move.name])
			elif effect.target == "opponent":
				defender_state.effects.append(effect)

		# TODO: Decrement effect durations at end of turn

func _debug_load_teams():
	# Load some starters for testing
	var h = load("res://data/Monsters/Hydrogen.tres")
	var he = load("res://data/Monsters/Helium.tres")
	var li = load("res://data/Monsters/Lithium.tres")
	
	if h: player_team.append(h)
	if he: player_team.append(he)
	if li: player_team.append(li)
	
	# Clone for enemy
	if h: enemy_team.append(h)
	if he: enemy_team.append(he)
	if li: enemy_team.append(li)
