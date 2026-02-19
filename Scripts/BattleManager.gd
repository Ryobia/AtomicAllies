extends Node
class_name BattleManager

# --- Configuration ---
# Drag your 'BattleMonster.tscn' (the visual prefab) here in the Inspector
@export var monster_scene: PackedScene 
@export var battle_hud: Control # Assign your BattleHUD node here

const ATB_SPEED_SCALE = 10.0 # Multiplier to make the bars fill at a reasonable rate

# Assign Marker2D nodes from your scene tree here.
# These determine where the monsters stand.
@export var player_spawn_points: Array[Marker2D]
@export var enemy_spawn_points: Array[Marker2D]

# --- State ---
enum BattleState { SETUP, COUNTING, ACTION_SELECTION, TARGET_SELECTION, EXECUTING, END }
var current_state = BattleState.SETUP

var active_player_monsters: Array = []
var active_enemy_monsters: Array = []
var all_monsters: Array = [] # Combined list for ATB processing
var benched_player_monsters: Array[MonsterData] = []

var turn_queue: Array = []
var current_acting_unit: BattleMonster = null
var selected_move: MoveData = null

func _ready():
	if not battle_hud:
		battle_hud = find_child("BattleHUD", true, false)

	if battle_hud:
		# Connect HUD signals
		battle_hud.action_selected.connect(_on_action_selected)
		battle_hud.move_selected.connect(_on_move_selected)
		battle_hud.target_selected.connect(_on_target_selected)
		battle_hud.cancel_targeting.connect(_on_cancel_targeting)
		battle_hud.swap_selected.connect(_on_swap_selected)
	else:
		push_warning("BattleManager: BattleHUD not found or assigned!")

	# --- Sanity Checks for Scene Setup ---
	if monster_scene == null:
		push_error("BattleManager: 'monster_scene' is not assigned in the Inspector!")
		return
	if player_spawn_points.is_empty() or enemy_spawn_points.is_empty():
		push_error("BattleManager: 'player_spawn_points' or 'enemy_spawn_points' are not assigned in the Inspector!")
		return
	
	# If we are running this scene directly (for testing), generate a battle.
	# In the full game, SceneManager or MainMenu would call start_battle().
	if PlayerData.owned_monsters.size() > 0:
		# Generate 3 random enemies for a 3v3 setup
		var enemies = generate_random_enemies(3)
		start_battle(enemies)

func _process(delta):
	if current_state == BattleState.COUNTING:
		process_atb(delta)

func process_atb(delta):
	var anyone_ready = false
	
	for unit in all_monsters:
		if unit.is_dead: continue
		
		# ATB Formula: Speed * Delta * Scale
		var speed = unit.stats.get("speed", 10)
		unit.atb_value += speed * delta * 0.5 # 0.5 is a tuning factor
		
		# Update HUD Stability Bar
		if battle_hud:
			var index = -1
			if unit.is_player:
				index = active_player_monsters.find(unit)
			else:
				index = active_enemy_monsters.find(unit)
			
			if index != -1:
				battle_hud.update_stability(unit.is_player, index, unit.atb_value)
		
		if unit.atb_value >= 100.0:
			unit.atb_value = 100.0
			if unit not in turn_queue:
				turn_queue.append(unit)
			anyone_ready = true
	
	if anyone_ready and not turn_queue.is_empty():
		start_turn()

func start_battle(enemy_data_list: Array[MonsterData]):
	print("BattleManager: Initializing battle...")
	current_state = BattleState.SETUP
	clear_battlefield()
	
	# 1. Spawn Player Team
	# We take the first N monsters from the player's collection, 
	# where N is the number of available spawn points (e.g., 3).
	var player_roster = PlayerData.owned_monsters
	benched_player_monsters.clear()
	
	for i in range(player_roster.size()):
		if i < player_spawn_points.size():
			spawn_unit(player_roster[i], player_spawn_points[i], true)
		else:
			benched_player_monsters.append(player_roster[i])
		
	# 2. Spawn Enemy Team
	var enemy_count = min(enemy_data_list.size(), enemy_spawn_points.size())
	
	for i in range(enemy_count):
		spawn_unit(enemy_data_list[i], enemy_spawn_points[i], false)
		
	var player_count = active_player_monsters.size()
	print("BattleManager: Battle started with %d vs %d units." % [player_count, enemy_count])
	
	# Setup the HUD with the monster data
	if battle_hud:
		var player_data_list = []
		for unit in active_player_monsters:
			player_data_list.append(unit.data)
		# The setup_ui function expects a list of MonsterData, not BattleMonster nodes
		battle_hud.setup_ui(player_data_list, enemy_data_list)

	# Start the clock
	current_state = BattleState.COUNTING

func spawn_unit(data: MonsterData, spawn_marker: Marker2D, is_player: bool):
	if not monster_scene:
		push_error("BattleManager: Monster Scene is not assigned in Inspector!")
		return
		
	var unit = monster_scene.instantiate()
	spawn_marker.add_child(unit)
	unit.position = Vector2.ZERO # Center on the marker
	
	# Initialize the unit's visuals and stats.
	# We assume the root script of monster_scene has a 'setup' function.
	if unit.has_method("setup"):
		unit.setup(data, is_player)
		unit.died.connect(_on_monster_death)
		unit.hp_changed.connect(func(new_hp, max_hp): _on_unit_hp_changed(unit, new_hp, max_hp))
	else:
		push_warning("BattleManager: Spawned unit is missing 'setup' method.")
	
	if is_player:
		active_player_monsters.append(unit)
	else:
		active_enemy_monsters.append(unit)
	all_monsters.append(unit)

func clear_battlefield():
	for unit in active_player_monsters:
		unit.queue_free()
	active_player_monsters.clear()
	
	for unit in active_enemy_monsters:
		unit.queue_free()
	active_enemy_monsters.clear()
	all_monsters.clear()

# --- Helper: Generate Random Enemies ---
func generate_random_enemies(count: int) -> Array[MonsterData]:
	var enemies: Array[MonsterData] = []
	var pool = PlayerData.starter_monster_paths
	
	if pool.is_empty():
		push_warning("BattleManager: No monster paths found in PlayerData.")
		return enemies
	
	for i in range(count):
		var random_path = pool.pick_random()
		var res = load(random_path)
		if res:
			var enemy = res.duplicate()
			
			# Scale enemy level based on the player's strongest monster (or first)
			var scaling_level = 1
			if not PlayerData.owned_monsters.is_empty():
				scaling_level = PlayerData.owned_monsters[0].level
			
			# Add some variance (-1 to +2 levels)
			enemy.level = max(1, scaling_level + randi_range(-1, 2))
			
			enemies.append(enemy)
			
	return enemies

# --- Turn Logic ---

func start_turn():
	current_state = BattleState.ACTION_SELECTION
	current_acting_unit = turn_queue.pop_front()
	
	print("Turn Start: ", current_acting_unit.data.monster_name)
	
	if current_acting_unit.is_player:
		# Enable UI
		if battle_hud:
			battle_hud.log_message("It's %s's turn!" % current_acting_unit.data.monster_name)
			battle_hud.show_actions()
	else:
		# AI Turn
		if battle_hud:
			battle_hud.log_message("Enemy %s is attacking!" % current_acting_unit.data.monster_name)
		
		# Simple AI: Wait a second then attack random player
		await get_tree().create_timer(1.0).timeout
		execute_ai_turn()

func execute_ai_turn():
	# Pick a random living player target
	var targets = active_player_monsters.filter(func(m): return not m.is_dead)
	if targets.is_empty():
		end_battle(false)
		return
		
	var target = targets.pick_random()
	
	# Create a dummy move for now (Basic Attack)
	var move = MoveData.new()
	move.name = "Tackle"
	move.power = 20
	
	perform_move(current_acting_unit, target, move)

# --- Player Input Handlers ---

func _on_action_selected(action_type):
	if not current_acting_unit:
		return

	if action_type == "attack":
		# For MVP, just load basic moves. Later, load from MonsterData.
		var moves = current_acting_unit.data.moves
		if moves.is_empty():
			if battle_hud: battle_hud.log_message("%s has no moves!" % current_acting_unit.data.monster_name)
			return
		
		if battle_hud:
			battle_hud.show_moves(moves)
	elif action_type == "swap":
		if benched_player_monsters.is_empty():
			if battle_hud: battle_hud.log_message("No monsters to swap with!")
			return
		if battle_hud:
			battle_hud.show_swap_options(benched_player_monsters)

func _on_move_selected(move: MoveData):
	if current_state != BattleState.ACTION_SELECTION: return
	
	selected_move = move
	current_state = BattleState.TARGET_SELECTION
	
	# --- Calculate Valid Targets ---
	var valid_targets = []
	var vanguard_alive = false
	if active_enemy_monsters.size() > 0 and not active_enemy_monsters[0].is_dead:
		vanguard_alive = true
	
	for i in range(active_enemy_monsters.size()):
		var enemy = active_enemy_monsters[i]
		if enemy.is_dead: continue
		
		# If Vanguard is alive and move is NOT Snipe, you can only target the Vanguard (Index 0)
		if vanguard_alive and not move.is_snipe:
			if i == 0: valid_targets.append(i)
		else:
			# Otherwise (Vanguard dead OR Snipe move), you can target anyone
			valid_targets.append(i)
	
	# Hide the move list and enable targeting mode on the HUD
	battle_hud.move_container.visible = false
	battle_hud.set_targeting_mode(true, valid_targets)
	battle_hud.log_message("Select a target for %s..." % move.name)

func _on_cancel_targeting():
	# This is triggered by right-click or Esc in the HUD.
	# We only care about it if we are currently selecting a target.
	if current_state != BattleState.TARGET_SELECTION: return
	
	# Revert to the move selection screen
	current_state = BattleState.ACTION_SELECTION
	selected_move = null
	
	battle_hud.set_targeting_mode(false)
	battle_hud.move_container.visible = true # Re-show the move list
	battle_hud.log_message("It's %s's turn!" % current_acting_unit.data.monster_name)

func _on_target_selected(index: int):
	if current_state != BattleState.TARGET_SELECTION: return
	
	var defender = active_enemy_monsters[index]
	
	# --- Target Validation ---
	if defender.is_dead:
		battle_hud.log_message("Target is already defeated!")
		return # Stay in targeting mode
		
	# Vanguard logic: The monster at index 0 is the vanguard.
	var vanguard = active_enemy_monsters[0]
	if vanguard and not vanguard.is_dead and defender != vanguard:
		if not selected_move.is_snipe:
			battle_hud.log_message("Must attack the vanguard first!")
			return # Stay in targeting mode

	battle_hud.set_targeting_mode(false)
	perform_move(current_acting_unit, defender, selected_move)

func _on_swap_selected(index: int):
	if current_state != BattleState.ACTION_SELECTION: return
	
	# Hide HUD options
	if battle_hud:
		battle_hud.move_container.visible = false
		
	var new_monster_data = benched_player_monsters[index]
	perform_swap(current_acting_unit, new_monster_data, index)

func perform_swap(active_unit: BattleMonster, new_data: MonsterData, bench_index: int):
	current_state = BattleState.EXECUTING
	
	if battle_hud:
		battle_hud.log_message("%s retreats!" % active_unit.data.monster_name)
		
	await get_tree().create_timer(1.0).timeout
	
	# Swap data: Active goes to bench, Bench goes to active
	benched_player_monsters.remove_at(bench_index)
	benched_player_monsters.append(active_unit.data)
	
	# Swap physical unit
	var marker = active_unit.get_parent()
	active_player_monsters.erase(active_unit)
	all_monsters.erase(active_unit)
	active_unit.queue_free()
	
	if battle_hud:
		battle_hud.log_message("Go! %s!" % new_data.monster_name)
		
	spawn_unit(new_data, marker, true)
	
	# The new unit is the last added to active_player_monsters
	var new_unit = active_player_monsters.back()
	new_unit.atb_value = 0 # Start fresh
	
	await get_tree().create_timer(1.0).timeout
	end_turn()

func perform_move(attacker: BattleMonster, defender: BattleMonster, move: MoveData):
	current_state = BattleState.EXECUTING
	
	if battle_hud:
		battle_hud.log_message("%s used %s!" % [attacker.data.monster_name, move.name])
	
	# Calculate Damage using the new calculator
	var calc_result = DamageCalculator.calculate_damage(attacker, defender, move)
	var damage = calc_result["damage"]
	
	if battle_hud:
		# Show effectiveness messages
		if calc_result["effectiveness"] > 1.0:
			battle_hud.log_message("It's super effective! (%s)" % calc_result["reaction"])
		elif calc_result["effectiveness"] < 1.0:
			battle_hud.log_message("It's not very effective... (%s)" % calc_result["reaction"])
			
		if calc_result["is_crit"]:
			battle_hud.log_message("Critical Hit!")
	
	defender.take_damage(damage)
	
	# Wait for animation/text
	await get_tree().create_timer(1.0).timeout
	
	end_turn()

func end_turn():
	if is_instance_valid(current_acting_unit):
		current_acting_unit.atb_value = 0
		
		# Reset HUD bar for this unit
		if battle_hud:
			var index = active_player_monsters.find(current_acting_unit) if current_acting_unit.is_player else active_enemy_monsters.find(current_acting_unit)
			if index != -1:
				battle_hud.update_stability(current_acting_unit.is_player, index, 0)
				
	current_acting_unit = null
	selected_move = null
	
	# Go back to counting or process next in queue
	if turn_queue.is_empty():
		current_state = BattleState.COUNTING
	else:
		start_turn()

func end_battle(player_won: bool):
	current_state = BattleState.END
	print("Battle Over. Player Won: ", player_won)
	if battle_hud:
		if player_won:
			battle_hud.log_message("VICTORY!")
		else:
			battle_hud.log_message("DEFEAT...")

func _on_monster_death(_monster: BattleMonster):
	# A small delay to let the death animation play out
	await get_tree().create_timer(0.6).timeout
	check_win_condition()

func check_win_condition():
	if current_state == BattleState.END: return

	var player_team_defeated = true
	for m in active_player_monsters:
		if not m.is_dead:
			player_team_defeated = false
			break
	if player_team_defeated:
		end_battle(false)

	var enemy_team_defeated = true
	for m in active_enemy_monsters:
		if not m.is_dead:
			enemy_team_defeated = false
			break
	if enemy_team_defeated:
		end_battle(true)

func _on_unit_hp_changed(unit: BattleMonster, new_hp: int, max_hp: int):
	if battle_hud:
		var index = -1
		if unit.is_player:
			index = active_player_monsters.find(unit)
		else:
			index = active_enemy_monsters.find(unit)
		
		if index != -1:
			battle_hud.update_hp(unit.is_player, index, new_hp, max_hp)
