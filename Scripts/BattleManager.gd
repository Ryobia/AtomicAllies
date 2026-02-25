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

# --- Signals for UI Decoupling ---
signal log_event(text)
signal hud_update_atb(is_player, index, value)
signal hud_update_hp(is_player, index, new_hp, max_hp)
signal hud_highlight_unit(is_player, index)

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
		battle_hud.inspect_unit.connect(_on_inspect_unit)
		
		# Connect Manager -> HUD signals
		log_event.connect(battle_hud.log_message)
		hud_update_atb.connect(battle_hud.update_speed_bar)
		hud_update_hp.connect(battle_hud.update_hp)
		hud_highlight_unit.connect(battle_hud.highlight_active_unit)
	else:
		push_warning("BattleManager: BattleHUD not found or assigned!")

	var resource_header = find_child("ResourceHeader", true, false)
	if resource_header:
		resource_header.visible = false

	# --- Sanity Checks for Scene Setup ---
	if monster_scene == null:
		push_error("BattleManager: 'monster_scene' is not assigned in the Inspector!")
		return
	if player_spawn_points.is_empty() or enemy_spawn_points.is_empty():
		push_error("BattleManager: 'player_spawn_points' or 'enemy_spawn_points' are not assigned in the Inspector!")
		return
	
	# If we are running this scene directly (for testing), generate a battle.
	# In the full game, SceneManager or MainMenu would call start_battle().
	
	# Check for pending battle data from BattlePrepare
	if not PlayerData.pending_enemy_team.is_empty():
		start_battle(PlayerData.pending_enemy_team)
	elif PlayerData.owned_monsters.size() > 0:
		# Fallback: Generate 3 Void Enemies for testing
		start_battle(generate_void_enemies(3))

func _process(delta):
	if current_state == BattleState.COUNTING:
		process_atb(delta)

func process_atb(delta):
	var anyone_ready = false
	
	for unit in all_monsters:
		if unit.is_dead and not unit.is_player: continue
		
		# Delegate math to the monster
		unit.update_atb(delta, 2.5)
		
		# Update HUD Speed Bar
		var index = -1
		if unit.is_player:
			index = active_player_monsters.find(unit)
		else:
			index = active_enemy_monsters.find(unit)
		
		if index != -1:
			hud_update_atb.emit(unit.is_player, index, unit.atb_value)
		
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
	# Use active_team if set, otherwise fallback to owned_monsters
	var player_roster = PlayerData.active_team
	if player_roster.is_empty():
		player_roster = PlayerData.owned_monsters
	
	benched_player_monsters.clear()
	
	# Mapping for 3v3 Triangle: 
	# Team Index 0 (Vanguard) -> Spawn Point 1 (Center)
	# Team Index 1 (Flank)    -> Spawn Point 0 (Left)
	# Team Index 2 (Flank)    -> Spawn Point 2 (Right)
	var spawn_map = [1, 0, 2]
	
	for i in range(player_roster.size()):
		var unit_data = player_roster[i]
		if unit_data == null: continue
		
		if i < 3:
			var spawn_idx = i
			if player_spawn_points.size() >= 3:
				spawn_idx = spawn_map[i]
			
			if spawn_idx < player_spawn_points.size():
				spawn_unit(unit_data, player_spawn_points[spawn_idx], true)
		else:
			benched_player_monsters.append(unit_data)
		
	# 2. Spawn Enemy Team
	var enemy_count = min(enemy_data_list.size(), enemy_spawn_points.size())
	
	for i in range(enemy_count):
		var spawn_idx = i
		if i < 3 and enemy_spawn_points.size() >= 3:
			spawn_idx = spawn_map[i]
			
		if spawn_idx < enemy_spawn_points.size():
			spawn_unit(enemy_data_list[i], enemy_spawn_points[spawn_idx], false)
		
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
		unit.log_action.connect(func(text): log_event.emit(text))
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

func generate_void_enemies(count: int) -> Array[MonsterData]:
	var enemies: Array[MonsterData] = []
	
	# Define available enemy types
	var enemy_paths = [
		"res://data/Enemies/NullGrunt.tres",
		"res://data/Enemies/NullTank.tres",
		"res://data/Enemies/NullCommander.tres"
	]
	
	# Determine scaling level
	var scaling_level = 1
	if not PlayerData.owned_monsters.is_empty():
		scaling_level = PlayerData.owned_monsters[0].level
	
	for i in range(count):
		# Pick a random enemy type
		var path = enemy_paths.pick_random()
		if ResourceLoader.exists(path):
			var base = load(path)
			var enemy = base.duplicate()
			
			# Scale level with some variance
			enemy.level = max(1, scaling_level + randi_range(-1, 1))
			
			enemies.append(enemy)
		else:
			push_warning("BattleManager: Could not load enemy at " + path)
		
	return enemies

# --- Turn Logic ---

func start_turn():
	current_state = BattleState.ACTION_SELECTION
	current_acting_unit = turn_queue.pop_front()
	
	# Handle dead unit turn (Force Swap)
	if current_acting_unit.is_dead:
		if current_acting_unit.is_player:
			if benched_player_monsters.is_empty():
				end_turn()
				return
			
			log_event.emit("%s has fallen! Choose a replacement!" % current_acting_unit.data.monster_name)
			var index = active_player_monsters.find(current_acting_unit)
			hud_highlight_unit.emit(true, index)
			if battle_hud:
				battle_hud.show_swap_options(benched_player_monsters, true)
			return
		else:
			end_turn()
			return

	current_acting_unit.on_turn_start()
	
	# Check if unit died from start-of-turn effects (like Corrosion)
	if current_acting_unit.is_dead:
		if current_acting_unit.is_player and not benched_player_monsters.is_empty():
			log_event.emit("%s has fallen! Choose a replacement!" % current_acting_unit.data.monster_name)
			if battle_hud:
				battle_hud.show_swap_options(benched_player_monsters, true)
			return
		end_turn()
		return
		
	print("Turn Start: ", current_acting_unit.data.monster_name)
	
	# Highlight the active unit
	var index = active_player_monsters.find(current_acting_unit) if current_acting_unit.is_player else active_enemy_monsters.find(current_acting_unit)
	hud_highlight_unit.emit(current_acting_unit.is_player, index)
	
	if current_acting_unit.is_player:
		# Enable UI
		log_event.emit("It's %s's turn!" % current_acting_unit.data.monster_name)
		if battle_hud:
			battle_hud.show_actions()
	else:
		# AI Turn
		log_event.emit("Enemy %s is attacking!" % current_acting_unit.data.monster_name)
		
		# Simple AI: Wait a second then attack random player
		await get_tree().create_timer(1.0).timeout
		execute_ai_turn()

func execute_ai_turn():
	# Pick a random living player target
	var targets = active_player_monsters.filter(func(m): return not m.is_dead)
	
	# Check for Taunt
	var taunt_targets = targets.filter(func(m): return m.has_status("taunt"))
	if not taunt_targets.is_empty():
		targets = taunt_targets
		
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
		# Load moves via CombatManager (handles defaults)
		var moves = CombatManager.get_active_moves(current_acting_unit.data)
		
		if moves.is_empty():
			log_event.emit("%s has no moves!" % current_acting_unit.data.monster_name)
			return
		
		if battle_hud:
			battle_hud.show_moves(moves)
	elif action_type == "swap":
		if benched_player_monsters.is_empty():
			log_event.emit("No monsters to swap with!")
			return
		if battle_hud:
			battle_hud.show_swap_options(benched_player_monsters)

func _on_move_selected(move: MoveData):
	if current_state != BattleState.ACTION_SELECTION: return
	
	selected_move = move
	current_state = BattleState.TARGET_SELECTION
	
	# Handle Self-Targeting immediately
	if move.target_type == MoveData.TargetType.SELF:
		perform_move(current_acting_unit, current_acting_unit, move)
		return
	
	# --- Calculate Valid Targets ---
	var valid_targets = []
	var target_allies = (move.target_type == MoveData.TargetType.ALLY)
	
	if target_allies:
		# Ally Targeting
		for i in range(active_player_monsters.size()):
			var ally = active_player_monsters[i]
			if not ally.is_dead:
				# Optional: Prevent targeting self with ally moves if desired, 
				# but usually "Ally" moves can target self too in many games.
				# For now, allow all living team members.
				valid_targets.append(i)
	else:
		# Enemy Targeting
		# Check for Taunt
		var taunt_targets = []
		for i in range(active_enemy_monsters.size()):
			var enemy = active_enemy_monsters[i]
			if not enemy.is_dead and enemy.has_status("taunt"):
				taunt_targets.append(i)
				
		if not taunt_targets.is_empty():
			valid_targets = taunt_targets
		else:
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
	battle_hud.set_targeting_mode(true, valid_targets, target_allies)
	log_event.emit("Select a target for %s..." % move.name)

func _on_cancel_targeting():
	# This is triggered by right-click or Esc in the HUD.
	# We only care about it if we are currently selecting a target.
	if current_state != BattleState.TARGET_SELECTION: return
	
	# Revert to the move selection screen
	current_state = BattleState.ACTION_SELECTION
	selected_move = null
	
	battle_hud.set_targeting_mode(false)
	battle_hud.move_container.visible = true # Re-show the move list
	log_event.emit("It's %s's turn!" % current_acting_unit.data.monster_name)

func _on_target_selected(index: int):
	if current_state != BattleState.TARGET_SELECTION: return
	
	var defender = null
	if selected_move.target_type == MoveData.TargetType.ALLY:
		defender = active_player_monsters[index]
	else:
		defender = active_enemy_monsters[index]
	
	# --- Target Validation ---
	if defender.is_dead:
		log_event.emit("Target is already defeated!")
		return # Stay in targeting mode
	
	# Enemy-specific validation (Taunt/Vanguard)
	if selected_move.target_type == MoveData.TargetType.ENEMY:
		# Check Taunt
		var taunt_active = false
		for enemy in active_enemy_monsters:
			if not enemy.is_dead and enemy.has_status("taunt"):
				taunt_active = true
				break
				
		if taunt_active:
			if not defender.has_status("taunt"):
				log_event.emit("Must attack the taunting unit!")
				return
		else:
			# Vanguard logic: The monster at index 0 is the vanguard.
			var vanguard = active_enemy_monsters[0]
			if vanguard and not vanguard.is_dead and defender != vanguard:
				if not selected_move.is_snipe:
					log_event.emit("Must attack the vanguard first!")
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

func _on_inspect_unit(index: int, is_player: bool):
	var unit = null
	if is_player:
		if index < active_player_monsters.size():
			unit = active_player_monsters[index]
	else:
		if index < active_enemy_monsters.size():
			unit = active_enemy_monsters[index]
			
	if unit and battle_hud:
		battle_hud.show_stat_popup(unit)

func perform_swap(active_unit: BattleMonster, new_data: MonsterData, bench_index: int):
	current_state = BattleState.EXECUTING
	
	log_event.emit("%s retreats!" % active_unit.data.monster_name)
	await active_unit.play_move()
		
	await get_tree().create_timer(1.0).timeout
	
	# Swap data: Active goes to bench, Bench goes to active
	benched_player_monsters.remove_at(bench_index)
	benched_player_monsters.append(active_unit.data)
	
	# Swap physical unit
	var marker = active_unit.get_parent()
	var index = active_player_monsters.find(active_unit)
	
	all_monsters.erase(active_unit)
	active_unit.queue_free()
	
	log_event.emit("Go! %s!" % new_data.monster_name)
		
	spawn_unit(new_data, marker, true)
	
	# The new unit is the last added to active_player_monsters by spawn_unit
	var new_unit = active_player_monsters.pop_back()
	
	# Place new unit in the correct index to maintain formation (Vanguard/Flank)
	if index != -1:
		active_player_monsters[index] = new_unit
	else:
		active_player_monsters.append(new_unit)
	
	new_unit.atb_value = 0 # Start fresh
	new_unit.play_move() # Play enter animation
	
	# Refresh HUD visuals (Sprites/Names) and restore Bars
	if battle_hud:
		var player_data_list = []
		for unit in active_player_monsters:
			player_data_list.append(unit.data)
		var enemy_data_list = []
		for unit in active_enemy_monsters:
			enemy_data_list.append(unit.data)
			
		battle_hud.setup_ui(player_data_list, enemy_data_list)
		
		# Restore HP/ATB values on HUD since setup_ui resets them to max/zero
		for i in range(active_player_monsters.size()):
			var u = active_player_monsters[i]
			battle_hud.update_hp(true, i, u.current_hp, u.max_hp)
			battle_hud.update_speed_bar(true, i, u.atb_value)
			
		for i in range(active_enemy_monsters.size()):
			var u = active_enemy_monsters[i]
			battle_hud.update_hp(false, i, u.current_hp, u.max_hp)
			battle_hud.update_speed_bar(false, i, u.atb_value)
	
	await get_tree().create_timer(1.0).timeout
	end_turn()

func perform_move(attacker: BattleMonster, defender: BattleMonster, move: MoveData):
	current_state = BattleState.EXECUTING
	
	log_event.emit("%s used %s!" % [attacker.data.monster_name, move.name])
	await attacker.play_attack()
	
	# Calculate Damage using CombatManager
	var result = CombatManager.execute_move(attacker, defender, move)
	
	if not result.success:
		# Missed
		for msg in result.messages:
			log_event.emit(msg)
	else:
		# Hit
		if result.damage > 0:
			defender.take_damage(result.damage)
			log_event.emit("Dealt %d damage!" % result.damage)
			
		# Log other messages (status effects etc)
		for i in range(result.messages.size()):
			# Skip the damage message if we already logged it manually or just log all
			if "damage" not in result.messages[i]:
				log_event.emit(result.messages[i])
				
		# Apply result.effects to BattleMonster nodes
		for effect in result.effects:
			var target_unit = effect.target
			if target_unit and is_instance_valid(target_unit):
				target_unit.apply_effect(effect)
	
	# Wait for animation/text
	await get_tree().create_timer(1.0).timeout
	
	end_turn()

func end_turn():
	if is_instance_valid(current_acting_unit):
		current_acting_unit.on_turn_end()
		current_acting_unit.atb_value = 0
		
		# Reset HUD bar for this unit
		var index = active_player_monsters.find(current_acting_unit) if current_acting_unit.is_player else active_enemy_monsters.find(current_acting_unit)
		if index != -1:
			hud_update_atb.emit(current_acting_unit.is_player, index, 0)
				
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
	
	var rewards = {}
	if player_won:
		var total_xp = 0
		var total_be = 0
		for unit in active_enemy_monsters:
			# XP Calculation: Base 50 + (Level * 10)
			total_xp += 50 + (unit.data.level * 10)
			# Binding Energy: Base 10 + (Level * 2)
			total_be += 10 + (unit.data.level * 2)
		
		rewards["xp"] = total_xp
		rewards["binding_energy"] = total_be
		# Add to global pool
		if PlayerData:
			PlayerData.add_resource("experience", total_xp)
			PlayerData.add_resource("binding_energy", total_be)

	# Notify CampaignManager (if it exists as an Autoload)
	if CampaignManager:
		CampaignManager.on_battle_ended(player_won)

	if battle_hud:
		battle_hud.show_result(player_won, rewards)

func _on_monster_death(_monster: BattleMonster):
	# Death animation is handled in BattleMonster.die(), so we just check win condition
	check_win_condition()

func check_win_condition():
	if current_state == BattleState.END: return

	var player_team_defeated = true
	for m in active_player_monsters:
		if not m.is_dead:
			player_team_defeated = false
			break
	if player_team_defeated and benched_player_monsters.is_empty():
		end_battle(false)

	var enemy_team_defeated = true
	for m in active_enemy_monsters:
		if not m.is_dead:
			enemy_team_defeated = false
			break
	if enemy_team_defeated:
		end_battle(true)

func _on_unit_hp_changed(unit: BattleMonster, new_hp: int, max_hp: int):
	var index = -1
	if unit.is_player:
		index = active_player_monsters.find(unit)
	else:
		index = active_enemy_monsters.find(unit)
	
	if index != -1:
		hud_update_hp.emit(unit.is_player, index, new_hp, max_hp)
