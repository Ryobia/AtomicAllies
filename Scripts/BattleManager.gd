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
var selected_item_id: String = ""
var roster_hp_cache: Dictionary = {} # MonsterData -> int (HP)

# --- Signals for UI Decoupling ---
signal log_event(text)
signal hud_update_atb(is_player, index, value)
signal hud_update_hp(is_player, index, new_hp, max_hp)
signal hud_highlight_unit(is_player, index)
signal hud_update_shield(is_player, index, shield, max_hp)
signal hud_update_status(is_player, index, effects)

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
		battle_hud.item_selected.connect(_on_item_selected)
		
		# Connect Manager -> HUD signals
		log_event.connect(battle_hud.log_message)
		hud_update_atb.connect(battle_hud.update_speed_bar)
		hud_update_hp.connect(battle_hud.update_hp)
		hud_highlight_unit.connect(battle_hud.highlight_active_unit)
		hud_update_shield.connect(battle_hud.update_shield)
		hud_update_status.connect(battle_hud.update_status_effects)
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
	roster_hp_cache.clear()
	_update_team_passives()
	
	# Load initial state from CampaignManager if rogue run
	if CampaignManager and CampaignManager.is_rogue_run:
		for m in CampaignManager.run_team_state:
			roster_hp_cache[m] = CampaignManager.run_team_state[m]
	
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
	# AI Smarts: Sort enemies so the tankiest is in the Vanguard (Index 0)
	enemy_data_list.sort_custom(func(a, b):
		var stats_a = a.get_current_stats()
		var stats_b = b.get_current_stats()
		# Tank Score = Max HP + (Defense * 2)
		var score_a = stats_a.max_hp + (stats_a.defense * 2)
		var score_b = stats_b.max_hp + (stats_b.defense * 2)
		return score_a > score_b
	)
	
	var enemy_count = min(enemy_data_list.size(), enemy_spawn_points.size())
	
	for i in range(enemy_count):
		var spawn_idx = i
		if i < 3 and enemy_spawn_points.size() >= 3:
			spawn_idx = spawn_map[i]
			
		if spawn_idx < enemy_spawn_points.size():
			spawn_unit(enemy_data_list[i], enemy_spawn_points[spawn_idx], false)
		
	var player_count = active_player_monsters.size()
	print("BattleManager: Battle started with %d vs %d units." % [player_count, enemy_count])
	_update_team_passives()
	
	# Mastery: Alkali Metals (100% Stability) -> Free Turn at Start
	var all_units = active_player_monsters + active_enemy_monsters
	for unit in all_units:
		if unit.data.group == AtomicConfig.Group.ALKALI_METAL and unit.data.stability >= 100:
			unit.atb_value = 100.0
			log_event.emit("%s surges with instability! (Free Turn)" % unit.data.monster_name)
		
		# Mastery: Alkaline Earths (100% Stability) -> Start with 25% Shield
		if unit.data.group == AtomicConfig.Group.ALKALINE_EARTH and unit.data.stability >= 100:
			var shield_amt = int(unit.max_hp * 0.25)
			unit.set_meta("shield", shield_amt)
			_check_shield_update(unit)
			log_event.emit("%s hardens its crust! (Shield)" % unit.data.monster_name)
			
		# Mastery: Halogens (100% Stability) -> Randomly poison 1 enemy
		if unit.data.group == AtomicConfig.Group.HALOGEN and unit.data.stability >= 100:
			var targets = active_enemy_monsters if unit.is_player else active_player_monsters
			var living_targets = targets.filter(func(m): return not m.is_dead)
			
			if not living_targets.is_empty():
				var target = living_targets.pick_random()
				# Halogen poison is 10% Max HP (handled by _process_status_damage)
				# We apply it with damage_percent to be safe
				target.apply_effect({ "status": "poison", "duration": 3, "damage_percent": 0.1, "type": "status" })
				_refresh_unit_status(target)
				log_event.emit("%s leaks toxic gas! %s is poisoned!" % [unit.data.monster_name, target.data.monster_name])
				_show_damage_number(target, 0, "poison") # Visual cue
	
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
		
		if is_player:
			# Apply cached HP if exists (Persistence)
			if roster_hp_cache.has(data):
				var cached_hp = roster_hp_cache[data]
				unit.current_hp = cached_hp
				if cached_hp <= 0:
					unit.is_dead = true
					# If unit spawns dead, BattleManager logic will handle forcing a swap/loss
			else:
				roster_hp_cache[data] = unit.max_hp
			
			# Apply Rogue Run Buffs
			if CampaignManager and CampaignManager.is_rogue_run:
				for stat in CampaignManager.run_buffs:
					if unit.stats.has(stat):
						unit.stats[stat] += CampaignManager.run_buffs[stat]
		
		unit.died.connect(_on_monster_death)
		unit.hp_changed.connect(func(new_hp, max_hp): _on_unit_hp_changed(unit, new_hp, max_hp))
		unit.log_action.connect(func(text): log_event.emit(text))
		if unit.has_signal("effects_changed"): unit.effects_changed.connect(func(effects): _on_unit_effects_changed(unit, effects))
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
			
			# Randomize stability for variety (40-70%)
			enemy.stability = randi_range(40, 70)
			
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
	
	for i in range(count):
		# Pick a random enemy type
		var path = enemy_paths.pick_random()
		if ResourceLoader.exists(path):
			var base = load(path)
			var enemy = base.duplicate()
			
			# Randomize stability for variety (40-70%)
			enemy.stability = randi_range(40, 70)
			
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
				battle_hud.show_swap_options(_get_swap_options(), true)
			return
		else:
			end_turn()
			return

	current_acting_unit.on_turn_start()
	_process_status_damage(current_acting_unit)
	_process_radiation(current_acting_unit)
	_apply_turn_start_passives(current_acting_unit)
	
	if current_acting_unit.data.stability >= 100:
		_apply_mastery_turn_start(current_acting_unit)
	
	# Check if unit died from start-of-turn effects (like Corrosion)
	if current_acting_unit.is_dead:
		if current_acting_unit.is_player and not benched_player_monsters.is_empty():
			log_event.emit("%s has fallen! Choose a replacement!" % current_acting_unit.data.monster_name)
			if battle_hud:
				battle_hud.show_swap_options(_get_swap_options(), true)
			return
		end_turn()
		return
		
	# Check Stun
	if current_acting_unit.has_status("stun"):
		log_event.emit("%s is stunned!" % current_acting_unit.data.monster_name)
		await get_tree().create_timer(1.0).timeout
		end_turn()
		return
		
	print("Turn Start: ", current_acting_unit.data.monster_name)
	
	# Highlight the active unit
	var index = active_player_monsters.find(current_acting_unit) if current_acting_unit.is_player else active_enemy_monsters.find(current_acting_unit)
	hud_highlight_unit.emit(current_acting_unit.is_player, index)
	
	if current_acting_unit.is_player:
		# Enable UI
		_refresh_unit_status(current_acting_unit)
		log_event.emit("It's %s's turn!" % current_acting_unit.data.monster_name)
		if battle_hud:
			battle_hud.show_actions()
	else:
		# AI Turn
		log_event.emit("Enemy %s is attacking!" % current_acting_unit.data.monster_name)
		
		# Simple AI: Wait a second then attack random player
		await get_tree().create_timer(1.5).timeout
		execute_ai_turn()

func execute_ai_turn():
	# 1. Select a Move
	var moves = CombatManager.get_active_moves(current_acting_unit.data)
	var move = null
	if not moves.is_empty():
		move = moves.pick_random()
	else:
		# Fallback move
		move = MoveData.new()
		move.name = "Struggle"
		move.power = 10
	
	# 2. Determine Valid Targets
	# Handle Self/Ally targeting for AI
	if move.target_type == MoveData.TargetType.SELF:
		perform_move(current_acting_unit, current_acting_unit, move)
		return
	elif move.target_type == MoveData.TargetType.ALLY:
		# AI heals/buffs random living ally
		var allies = active_enemy_monsters.filter(func(m): return not m.is_dead)
		if not allies.is_empty():
			perform_move(current_acting_unit, allies.pick_random(), move)
		return
	
	# Enemy Targeting (Player Team)
	var potential_targets = active_player_monsters.filter(func(m): return not m.is_dead)
	
	if potential_targets.is_empty():
		end_battle(false)
		return

	var valid_targets = []
	
	# Check Taunt
	var taunt_targets = potential_targets.filter(func(m): return m.has_status("taunt"))
	if not taunt_targets.is_empty():
		valid_targets = taunt_targets
	else:
		# Vanguard Logic: The monster at index 0 is the vanguard.
		var vanguard = active_player_monsters[0]
		var vanguard_alive = (vanguard and not vanguard.is_dead)
		
		if vanguard_alive and not move.is_snipe:
			# Must attack the vanguard
			valid_targets = [vanguard]
		else:
			# Can attack anyone (Vanguard dead OR Snipe move)
			valid_targets = potential_targets
	
	# AI Preference: Target weakest unit (Lowest HP + Def)
	if valid_targets.size() > 1:
		valid_targets.sort_custom(func(a, b):
			var score_a = a.current_hp + a.stats.get("defense", 0)
			var score_b = b.current_hp + b.stats.get("defense", 0)
			return score_a < score_b
		)
	
	var target = valid_targets[0]
	
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
			battle_hud.show_swap_options(_get_swap_options())

	elif action_type == "item":
		var battle_items = {}
		for item_id in PlayerData.inventory:
			if CombatManager.get_item_data(item_id).has("target"): # Check if it's a battle item
				battle_items[item_id] = PlayerData.inventory[item_id]
		
		if battle_items.is_empty():
			log_event.emit("No battle items!")
			return
			
		if battle_hud:
			battle_hud.show_items(battle_items)

func _on_move_selected(move: MoveData):
	if current_state != BattleState.ACTION_SELECTION: return
	
	selected_move = move
	current_state = BattleState.TARGET_SELECTION
	
	# Handle Self-Targeting immediately
	if move.target_type == MoveData.TargetType.SELF:
		if battle_hud and battle_hud.move_container: battle_hud.move_container.visible = false
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
	
	# Show move details and enable targeting mode on the HUD
	battle_hud.show_move_details(move)
	battle_hud.set_targeting_mode(true, valid_targets, target_allies)
	log_event.emit("Select a target for %s..." % move.name)

func _on_item_selected(item_id: String):
	if current_state != BattleState.ACTION_SELECTION: return
	
	selected_item_id = item_id
	selected_move = null
	current_state = BattleState.TARGET_SELECTION
	
	var data = CombatManager.get_item_data(item_id)
	var target_allies = (data.get("target", "Ally") == "Ally")
	var valid_targets = []
	
	# Items currently only target allies (healing/buffs)
	if target_allies:
		for i in range(active_player_monsters.size()):
			if not active_player_monsters[i].is_dead:
				valid_targets.append(i)
	
	battle_hud.move_container.visible = false
	battle_hud.set_targeting_mode(true, valid_targets, target_allies)
	log_event.emit("Select target for %s..." % data.name)

func _on_cancel_targeting():
	# This is triggered by right-click or Esc in the HUD.
	# We only care about it if we are currently selecting a target.
	if current_state != BattleState.TARGET_SELECTION: return
	
	var was_move = (selected_move != null)
	var was_item = (selected_item_id != "")
	
	# Revert to the move selection screen
	current_state = BattleState.ACTION_SELECTION
	selected_move = null
	selected_item_id = ""
	
	battle_hud.set_targeting_mode(false)
	
	if was_move:
		var moves = CombatManager.get_active_moves(current_acting_unit.data)
		battle_hud.show_moves(moves)
	elif was_item:
		var battle_items = {}
		for item_id in PlayerData.inventory:
			if CombatManager.get_item_data(item_id).has("target"):
				battle_items[item_id] = PlayerData.inventory[item_id]
		battle_hud.show_items(battle_items)
	else:
		battle_hud.show_actions()
		
	log_event.emit("It's %s's turn!" % current_acting_unit.data.monster_name)

func _on_target_selected(index: int):
	if current_state != BattleState.TARGET_SELECTION: return
	
	if selected_item_id != "":
		var data = CombatManager.get_item_data(selected_item_id)
		var target_allies = (data.get("target", "Ally") == "Ally")
		var target_unit = active_player_monsters[index] if target_allies else active_enemy_monsters[index]
		
		battle_hud.set_targeting_mode(false)
		perform_item(current_acting_unit, target_unit, selected_item_id)
		selected_item_id = ""
		return
	
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
	if battle_hud and battle_hud.move_container: battle_hud.move_container.visible = false
	perform_move(current_acting_unit, defender, selected_move)

func _on_swap_selected(index: int):
	if current_state != BattleState.ACTION_SELECTION: return
	
	# Hide HUD options
	if battle_hud:
		battle_hud.move_container.visible = false
		
	var new_monster_data = benched_player_monsters[index]
	
	if roster_hp_cache.has(new_monster_data) and roster_hp_cache[new_monster_data] <= 0:
		log_event.emit("That unit is unable to battle!")
		if battle_hud: battle_hud.show_actions()
		return
		
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
		
	await get_tree().create_timer(2.0).timeout
	
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
	
	_update_team_passives()
	
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
			_refresh_unit_status(u)
			battle_hud.update_speed_bar(true, i, u.atb_value)
			
		for i in range(active_enemy_monsters.size()):
			var u = active_enemy_monsters[i]
			battle_hud.update_hp(false, i, u.current_hp, u.max_hp)
			_refresh_unit_status(u)
			battle_hud.update_speed_bar(false, i, u.atb_value)
	
	await get_tree().create_timer(1.5).timeout
	end_turn()

func perform_move(attacker: BattleMonster, defender: BattleMonster, move: MoveData):
	current_state = BattleState.EXECUTING
	
	# Reactive Vapor Hazard Check
	if attacker.has_status("reactive_vapor") and move.target_type == MoveData.TargetType.ENEMY:
		var hazard_dmg = int(attacker.max_hp * 0.15) # 15% Max HP damage
		attacker.take_damage(hazard_dmg)
		log_event.emit("%s reacts with the vapor! (%d dmg)" % [attacker.data.monster_name, hazard_dmg])
		_show_damage_number(attacker, hazard_dmg, "poison")
		_play_vapor_reaction(attacker)
		_check_shield_update(attacker)
		
		if attacker.is_dead:
			await get_tree().create_timer(1.5).timeout
			end_turn()
			return
	
	log_event.emit("%s used %s!" % [attacker.data.monster_name, move.name])
	await attacker.play_attack(move.type == "Physical")
	
	# Calculate Damage using CombatManager
	var result = CombatManager.execute_move(attacker, defender, move)
	
	if not result.success:
		# Missed
		for msg in result.messages:
			log_event.emit(msg)
	else:
		# Hit
		if result.damage > 0:
			if defender.has_status("invulnerable"):
				log_event.emit("%s is invulnerable!" % defender.data.monster_name)
			else:
				var damage = result.damage
				
				# Reflection Check
				if defender.has_status("static_reflection") and move.target_type == MoveData.TargetType.ENEMY:
					var reflect_dmg = int(damage * 0.3)
					if reflect_dmg > 0:
						attacker.take_damage(reflect_dmg)
						_show_damage_number(attacker, reflect_dmg, "damage")
						log_event.emit("Static discharge hits %s!" % attacker.data.monster_name)
						_check_shield_update(attacker)
				
				var shield = defender.get_meta("shield", 0)
				
				if shield > 0:
					var absorbed = min(damage, shield)
					shield -= absorbed
					damage -= absorbed
					defender.set_meta("shield", shield)
					_check_shield_update(defender)
				
				if damage > 0:
					defender.take_damage(damage)
					_show_damage_number(defender, damage, "damage")
					log_event.emit("Dealt %d damage!" % result.damage)
					await get_tree().create_timer(1.2).timeout
			
		# Log other messages (status effects etc)
		for i in range(result.messages.size()):
			# Skip the damage message if we already logged it manually or just log all
			if "damage" not in result.messages[i]:
				log_event.emit(result.messages[i])
				await get_tree().create_timer(1.2).timeout
				
		# Apply result.effects to BattleMonster nodes
		for effect in result.effects:
			if effect.get("effect") == "add_shield":
				var target = effect.get("target")
				var amount = effect.get("amount", 0)
				var current = target.get_meta("shield", 0)
				target.set_meta("shield", current + amount)
				_check_shield_update(target)
				continue
			
			if effect.get("effect") == "heal_overflow_shield":
				var target = effect.get("target")
				var amount = effect.get("amount", 0)
				if target and is_instance_valid(target):
					var missing = target.max_hp - target.current_hp
					var heal_val = min(amount, missing)
					var shield_val = max(0, amount - missing)
					
					if heal_val > 0:
						target.heal(heal_val)
						_show_damage_number(target, heal_val, "heal")
						
						# Mastery: Post-Transition (100% Stability) -> Heal deals damage
						if attacker.data.group == AtomicConfig.Group.POST_TRANSITION and attacker.data.stability >= 100:
							_apply_post_transition_mastery_damage(attacker, heal_val)
						
					if shield_val > 0:
						var current = target.get_meta("shield", 0)
						target.set_meta("shield", current + shield_val)
						_check_shield_update(target)
						log_event.emit("%s gains %d shield!" % [target.data.monster_name, shield_val])
					
					_refresh_unit_status(target)
				continue
			
			if effect.get("effect") == "meltdown":
				var amount = effect.get("amount", 0)
				var all_units = active_player_monsters + active_enemy_monsters
				for unit in all_units:
					if unit != attacker and not unit.is_dead:
						unit.take_damage(amount)
						_show_damage_number(unit, amount, "damage")
				log_event.emit("Meltdown irradiates the battlefield!")
				continue
			
			if effect.get("effect") == "scramble_team":
				var target = effect.get("target")
				if target:
					_scramble_team(target.is_player)
				log_event.emit("Positions shuffled!")
				continue
			
			if effect.get("effect") == "call_reinforcements":
				_handle_reinforcements(attacker)
				continue
			
			if effect.get("effect") == "pheromones":
				var allies = active_enemy_monsters if not attacker.is_player else active_player_monsters
				for unit in allies:
					if not unit.is_dead:
						var atk_amt = int(unit.stats.attack * 0.15)
						var spd_amt = int(unit.stats.speed * 0.15)
						unit.apply_effect({ "target": unit, "stat": "attack", "amount": atk_amt, "duration": 3, "type": "stat_mod" })
						unit.apply_effect({ "target": unit, "stat": "speed", "amount": spd_amt, "duration": 3, "type": "stat_mod" })
						_refresh_unit_status(unit)
				log_event.emit("The swarm is frenzied!")
				continue
			
			if effect.get("effect") == "madness_aura":
				var targets = active_enemy_monsters if attacker.is_player else active_player_monsters
				var debuffs = ["poison", "stun", "vulnerable", "refracted", "insanity", "stat_drop"]
				
				for unit in targets:
					if not unit.is_dead:
						if unit.has_status("invulnerable"):
							log_event.emit("%s is invulnerable!" % unit.data.monster_name)
							continue
						
						var choice = debuffs.pick_random()
						if choice == "stat_drop":
							var stats = ["attack", "defense", "speed"]
							var s = stats.pick_random()
							var drop_amt = int(unit.stats.get(s, 10) * 0.25)
							unit.apply_effect({ "target": unit, "stat": s, "amount": -drop_amt, "duration": 3, "type": "stat_mod" })
							log_event.emit("%s's %s fell!" % [unit.data.monster_name, s.capitalize()])
						else:
							var duration = 3
							if choice == "stun": duration = 1
							
							var new_effect = { "target": unit, "status": choice, "duration": duration, "type": "status" }
							if choice == "poison": new_effect["damage_percent"] = 0.1
							
							unit.apply_effect(new_effect)
							log_event.emit("%s is affected by %s!" % [unit.data.monster_name, choice.capitalize()])
						
						_refresh_unit_status(unit)
				continue
			
			if effect.get("effect") == "cleanse":
				_handle_cleanse(effect.get("target"))
				continue
			
			if effect.get("effect") == "swap_stats":
				_handle_swap_stats(effect)
				continue
			
			if effect.get("effect") == "remove_status":
				_handle_remove_status(effect)
				continue
			
			if effect.get("effect") == "team_status":
				_handle_team_status(attacker, effect)
				continue
			
			if effect.get("effect") == "recoil":
				var target = effect.get("target")
				var amount = effect.get("amount", 0)
				if target and is_instance_valid(target):
					target.take_damage(amount)
					_show_damage_number(target, amount, "damage")
					log_event.emit("%s takes %d recoil damage!" % [target.data.monster_name, amount])
					_check_shield_update(target)
				continue
				
			var target_unit = effect.get("target")
			
			# Check Invulnerability for negative effects
			if target_unit and target_unit.has_status("invulnerable"):
				var is_harmful = false
				if effect.get("type") == "status":
					var s = effect.get("status")
					if s in ["poison", "stun", "silence_special", "marked_covalent", "vulnerable", "corrosion", "reactive_vapor", "insanity"]:
						is_harmful = true
				elif effect.get("type") == "stat_mod" and effect.get("amount", 0) < 0:
					is_harmful = true
				elif effect.get("effect") == "swap_stats":
					is_harmful = true
				
				if is_harmful:
					log_event.emit("%s blocked the effect!" % target_unit.data.monster_name)
					continue
			
			if target_unit and is_instance_valid(target_unit):
				# Mastery: Post-Transition (100% Stability) -> Heal deals damage
				if effect.get("effect") == "heal":
					var amount = effect.get("amount", 0)
					var actual_heal = min(amount, target_unit.max_hp - target_unit.current_hp)
					if actual_heal > 0 and attacker.data.group == AtomicConfig.Group.POST_TRANSITION and attacker.data.stability >= 100:
						_apply_post_transition_mastery_damage(attacker, actual_heal)

				target_unit.apply_effect(effect)
				_refresh_unit_status(target_unit)
				
		# Handle Chain Reaction (Nonmetal Passive)
		for effect in result.effects:
			if effect.get("effect") == "chain_reaction":
				var enemies = active_enemy_monsters if attacker.is_player else active_player_monsters
				var living = enemies.filter(func(m): return not m.is_dead and m != defender)
				if not living.is_empty():
					var secondary = living.pick_random()
					_play_chain_reaction_effect(defender.global_position, secondary.global_position)
					secondary.take_damage(int(effect.amount * 0.5)) # 50% damage to secondary
					_show_damage_number(secondary, int(effect.amount * 0.5), "damage")
					log_event.emit("Chain Reaction hits %s!" % secondary.data.monster_name)
					
					# Mastery: Copy Status Effects
					if effect.get("copy_status", false):
						for other_effect in result.effects:
							if other_effect.get("type") == "status" and other_effect.get("target") == defender:
								var new_status = other_effect.duplicate()
								new_status["target"] = secondary
								secondary.apply_effect(new_status)
								_refresh_unit_status(secondary)
								log_event.emit("Status spreads to %s!" % secondary.data.monster_name)
	
	# Wait for animation/text
	await get_tree().create_timer(1.0).timeout # Short final wait since we waited during messages
	
	end_turn()

func perform_item(user: BattleMonster, target: BattleMonster, item_id: String):
	current_state = BattleState.EXECUTING
	var data = CombatManager.get_item_data(item_id)
	var item_name = data.get("name", "Item")
	
	log_event.emit("%s used %s!" % [user.data.monster_name, item_name])
	await user.play_move() # Or specific item animation
	
	if data.get("effect") == "heal_percent":
		var amount = int(target.max_hp * data.get("amount", 0))
		_show_damage_number(target, amount, "heal")
	
	CombatManager.apply_item_effect(target, item_id)
	PlayerData.consume_item(item_id, 1)
	_check_shield_update(target)
	
	await get_tree().create_timer(2.0).timeout
	end_turn()

func end_turn():
	if is_instance_valid(current_acting_unit):
		current_acting_unit.on_turn_end()
		current_acting_unit.atb_value = 0
		_refresh_unit_status(current_acting_unit)
		
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
		var total_be = 0
		
		if CampaignManager and CampaignManager.is_rogue_run:
			var target_z = CampaignManager.current_run_target_z
			var run_cost = AtomicConfig.calculate_fusion_cost(target_z)
			# Estimate total enemies in a run (3 waves * ~4 enemies) to distribute reward
			var estimated_enemies = CampaignManager.max_run_waves * 4
			var be_per_enemy = float(run_cost) / float(estimated_enemies)
			total_be = int(be_per_enemy * active_enemy_monsters.size())
			if total_be < 1: total_be = 1
		else:
			for unit in active_enemy_monsters:
				# Binding Energy: Base 10 + (Atomic Number * 2)
				total_be += 10 + (unit.data.atomic_number * 2)

		rewards["binding_energy"] = total_be
		# Add to global pool
		if PlayerData:
			
			# Only add Binding Energy immediately if NOT in a rogue run
			# CampaignManager handles the "Stash" logic
			if not CampaignManager or not CampaignManager.is_rogue_run:
				PlayerData.add_resource("binding_energy", total_be)

	# Notify CampaignManager (if it exists as an Autoload)
	if CampaignManager:
		# Pass rewards so CampaignManager can stash them
		CampaignManager.on_battle_ended(player_won, rewards, roster_hp_cache)
		
		# If this was part of a run, show the total accumulated loot instead of just this battle's
		if player_won and CampaignManager.current_run_energy > 0:
			rewards["binding_energy"] = CampaignManager.current_run_energy

	if battle_hud:
		battle_hud.show_result(player_won, rewards)

func _on_monster_death(dead_unit: BattleMonster):
	# Death animation is handled in BattleMonster.die(), so we just check win condition
	
	# Lanthanide Passive: Absorb 10% of stats of fallen enemies
	var all_active = active_player_monsters + active_enemy_monsters
	for unit in all_active:
		if not unit.is_dead and unit.data.group == AtomicConfig.Group.LANTHANIDE:
			var should_absorb = false
			# Default: Absorb from enemies
			if unit.is_player != dead_unit.is_player:
				should_absorb = true
			# Mastery: Lanthanides (100% Stability) -> Absorb from allies too
			elif unit.data.stability >= 100 and unit.is_player == dead_unit.is_player:
				should_absorb = true
			
			if should_absorb:
				var absorb_atk = int(dead_unit.stats.attack * 0.1)
				var absorb_def = int(dead_unit.stats.defense * 0.1)
				var absorb_spd = int(dead_unit.stats.speed * 0.1)
				
				# Apply permanent buffs for this battle
				unit.apply_effect({ "target": unit, "stat": "attack", "amount": absorb_atk, "duration": 99, "type": "stat_mod" })
				unit.apply_effect({ "target": unit, "stat": "defense", "amount": absorb_def, "duration": 99, "type": "stat_mod" })
				unit.apply_effect({ "target": unit, "stat": "speed", "amount": absorb_spd, "duration": 99, "type": "stat_mod" })
				
				log_event.emit("%s absorbs power from %s!" % [unit.data.monster_name, dead_unit.data.monster_name])
	
	# If player unit dies, fill ATB to trigger immediate swap turn
	if dead_unit.is_player:
		dead_unit.atb_value = 100.0
	
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
		
	if unit.is_player:
		roster_hp_cache[unit.data] = new_hp

func _check_shield_update(unit: BattleMonster):
	var index = active_player_monsters.find(unit) if unit.is_player else active_enemy_monsters.find(unit)
	if index != -1:
		var shield = unit.get_meta("shield", 0)
		# We pass max_hp so the bar can scale correctly relative to health
		hud_update_shield.emit(unit.is_player, index, shield, unit.max_hp)

func _on_unit_effects_changed(unit: BattleMonster, effects: Array):
	_refresh_unit_status(unit)

func _refresh_unit_status(unit: BattleMonster):
	var index = active_player_monsters.find(unit) if unit.is_player else active_enemy_monsters.find(unit)
	if index != -1:
		# Assuming BattleMonster has 'active_effects' property
		if "active_effects" in unit:
			hud_update_status.emit(unit.is_player, index, unit.active_effects)
			_update_status_visuals(unit)

func _get_swap_options() -> Array:
	var options = []
	for m in benched_player_monsters:
		var is_dead = false
		if roster_hp_cache.has(m) and roster_hp_cache[m] <= 0:
			is_dead = true
		options.append({ "monster": m, "is_dead": is_dead })
	return options

func _update_team_passives():
	# Apply Team Auras (Passives)
	var nonmetal_count_p = 0
	for u in active_player_monsters:
		if not u.is_dead:
			if u.data.group == AtomicConfig.Group.NONMETAL: nonmetal_count_p += 1
			
	for u in active_player_monsters:
		# Nonmetal Aura: Allies gain 5% attack per Nonmetal
		if nonmetal_count_p > 0:
			u.apply_effect({ "target": u, "stat": "attack", "amount": int(u.stats.attack * (0.05 * nonmetal_count_p)), "duration": 99, "type": "stat_mod" })

	var nonmetal_count_e = 0
	for u in active_enemy_monsters:
		if not u.is_dead:
			if u.data.group == AtomicConfig.Group.NONMETAL: nonmetal_count_e += 1
			
	for u in active_enemy_monsters:
		if nonmetal_count_e > 0:
			u.apply_effect({ "target": u, "stat": "attack", "amount": int(u.stats.attack * (0.05 * nonmetal_count_e)), "duration": 99, "type": "stat_mod" })

func _apply_turn_start_passives(unit: BattleMonster):
	var group = unit.data.group
	
	match group:
		AtomicConfig.Group.ALKALINE_EARTH:
			# Passive: +5% Def every turn
			unit.apply_effect({ "target": unit, "stat": "defense", "amount": int(unit.stats.defense * 0.05), "duration": 3, "type": "stat_mod" })
			
		AtomicConfig.Group.NOBLE_GAS:
			# Passive: Restore 5% HP
			var pct = 0.05
			# Mastery: Noble Gases (100% Stability) -> Double healing (10%)
			if unit.data.stability >= 100:
				pct = 0.10
			
			var heal_amount = int(unit.max_hp * pct)
			unit.heal(heal_amount)
			_show_damage_number(unit, heal_amount, "heal")
			
		AtomicConfig.Group.POST_TRANSITION:
			# Passive: Gain +1 to all stats each turn
			unit.apply_effect({ "target": unit, "stat": "attack", "amount": 1, "duration": 99, "type": "stat_mod" })
			unit.apply_effect({ "target": unit, "stat": "defense", "amount": 1, "duration": 99, "type": "stat_mod" })
			unit.apply_effect({ "target": unit, "stat": "speed", "amount": 1, "duration": 99, "type": "stat_mod" })
			
		AtomicConfig.Group.ACTINIDE:
			# Passive: Lose 10% HP
			var loss_pct = 0.1
			# Mastery: Actinides (100% Stability) -> Reduce decay to 5%
			if unit.data.stability >= 100:
				loss_pct = 0.05
			
			var loss = int(unit.max_hp * loss_pct)
			unit.take_damage(loss)
			log_event.emit("%s decays!" % unit.data.monster_name)
			_check_shield_update(unit)
			
			# Apply Radiation to enemies
			var targets = active_enemy_monsters if unit.is_player else active_player_monsters
			var applied = false
			for target in targets:
				if not target.is_dead:
					# Only apply if not already present (to avoid resetting the ramp-up)
					var has_rad = false
					if "active_effects" in target:
						for eff in target.active_effects:
							if eff.get("status") == "radiation":
								has_rad = true
								break
					
					if not has_rad:
						target.apply_effect({ "status": "radiation", "duration": 3, "damage_percent": 0.05, "type": "status" })
						_refresh_unit_status(target)
						applied = true
			if applied:
				log_event.emit("%s emits radiation!" % unit.data.monster_name)
			
			# Full Set Bonus: Gain +3% Speed every turn
			var act_count = PlayerData.class_resonance.get(AtomicConfig.Group.ACTINIDE, 0)
			var total_act = 0
			if MonsterManifest:
				for m in MonsterManifest.all_monsters:
					if m.group == AtomicConfig.Group.ACTINIDE:
						total_act += 1
			
			if act_count >= total_act and total_act > 0:
				var spd_gain = max(1, int(unit.stats.speed * 0.03))
				unit.apply_effect({ "target": unit, "stat": "speed", "amount": spd_gain, "duration": 99, "type": "stat_mod" })
				log_event.emit("%s accelerates! (Full Set)" % unit.data.monster_name)

func _apply_mastery_turn_start(unit: BattleMonster):
	# Framework for 100% Stability Bonuses (Turn Start)
	match unit.data.group:
		# Add other groups as needed...
		_: pass

func _apply_post_transition_mastery_damage(attacker: BattleMonster, amount: int):
	var enemies = active_enemy_monsters if attacker.is_player else active_player_monsters
	var living = enemies.filter(func(m): return not m.is_dead)
	
	if not living.is_empty():
		var target = living.pick_random()
		target.take_damage(amount)
		_show_damage_number(target, amount, "damage")
		log_event.emit("%s's healing energy strikes %s!" % [attacker.data.monster_name, target.data.monster_name])

func _scramble_team(is_player: bool):
	var team = active_player_monsters if is_player else active_enemy_monsters
	var spawn_points = player_spawn_points if is_player else enemy_spawn_points
	
	# Shuffle the array in place
	team.shuffle()
	
	# Re-assign physical positions based on new index
	# Mapping for 3v3 Triangle: 0->Center, 1->Left, 2->Right
	var spawn_map = [1, 0, 2]
	
	for i in range(team.size()):
		var unit = team[i]
		var spawn_idx = i
		if i < 3 and spawn_points.size() >= 3:
			spawn_idx = spawn_map[i]
			
		if spawn_idx < spawn_points.size():
			var marker = spawn_points[spawn_idx]
			# Reparent to the new marker
			if unit.get_parent() != marker:
				unit.get_parent().remove_child(unit)
				marker.add_child(unit)
				unit.position = Vector2.ZERO
	
	# Update HUD to reflect new order
	if battle_hud:
		var player_data = []
		for u in active_player_monsters: player_data.append(u.data)
		var enemy_data = []
		for u in active_enemy_monsters: enemy_data.append(u.data)
		
		battle_hud.setup_ui(player_data, enemy_data)
		
		# Restore Bars and Status for the shuffled team
		for i in range(team.size()):
			var u = team[i]
			hud_update_hp.emit(is_player, i, u.current_hp, u.max_hp)
			hud_update_atb.emit(is_player, i, u.atb_value)
			_refresh_unit_status(u)
			_check_shield_update(u)

func _handle_reinforcements(caller: BattleMonster):
	if caller.is_player: return # Only enemies call reinforcements for now
	
	var spawn_points = enemy_spawn_points
	var target_marker: Marker2D = null
	var unit_to_replace: BattleMonster = null
	
	# 1. Look for empty slot
	for marker in spawn_points:
		if marker.get_child_count() == 0:
			target_marker = marker
			break
			
	# 2. If full, look for dead unit to replace
	if not target_marker:
		for unit in active_enemy_monsters:
			if unit.is_dead:
				target_marker = unit.get_parent()
				unit_to_replace = unit
				break
	
	if target_marker:
		var replace_idx = -1
		if unit_to_replace:
			replace_idx = active_enemy_monsters.find(unit_to_replace)
			active_enemy_monsters.remove_at(replace_idx)
			all_monsters.erase(unit_to_replace)
			unit_to_replace.queue_free()
			
		# Spawn Brood Grunt
		var grunt_path = "res://data/Enemies/BroodGrunt.tres"
		if ResourceLoader.exists(grunt_path):
			var grunt_data = load(grunt_path).duplicate()
			grunt_data.stability = caller.data.stability
			
			spawn_unit(grunt_data, target_marker, false)
			
			# If we replaced a unit, move the new unit (which was appended) to the old index
			# to maintain formation logic (Vanguard at index 0)
			if replace_idx != -1:
				var new_u = active_enemy_monsters.pop_back()
				active_enemy_monsters.insert(replace_idx, new_u)
			
			log_event.emit("Reinforcements arrive!")
	else:
		log_event.emit("No room for reinforcements!")

func _play_chain_reaction_effect(start_pos: Vector2, end_pos: Vector2):
	var parent = self
	# If BattleManager is just a Node, we need a CanvasItem parent to draw
	if not (parent is CanvasItem) and not player_spawn_points.is_empty():
		parent = player_spawn_points[0].get_parent()

	var line = Line2D.new()
	line.top_level = true
	line.width = 5.0
	line.default_color = Color("#60fafc") # Cyan
	
	var points = []
	var segments = 8
	for i in range(segments + 1):
		var t = float(i) / float(segments)
		var pos = start_pos.lerp(end_pos, t)
		if i > 0 and i < segments:
			pos += Vector2(randf_range(-20, 20), randf_range(-20, 20))
		points.append(pos)
	line.points = points
	
	parent.add_child(line)
	
	var tween = create_tween()
	tween.tween_property(line, "width", 20.0, 0.1).from(2.0)
	tween.parallel().tween_property(line, "modulate:a", 0.0, 0.4)
	tween.tween_callback(line.queue_free)

func _handle_cleanse(unit: BattleMonster):
	if not "active_effects" in unit: return
	
	var effects = unit.active_effects
	var cleaned_count = 0
	
	# Iterate backwards to safely remove
	for i in range(effects.size() - 1, -1, -1):
		var effect = effects[i]
		var is_debuff = false
		
		if effect.get("type") == "stat_mod":
			if effect.get("amount", 0) < 0:
				is_debuff = true
		elif effect.has("status"):
			var s = effect.get("status")
			if s in ["poison", "stun", "silence_special", "marked_covalent", "vulnerable", "corrosion"]:
				is_debuff = true
		elif effect.get("type") == "swap_stats":
			is_debuff = true
		
		if is_debuff:
			effects.remove_at(i)
			cleaned_count += 1
			
			# Revert Stat Mods immediately
			if effect.get("type") == "stat_mod":
				var stat = effect.get("stat")
				var amount = effect.get("amount", 0)
				if unit.stats.has(stat):
					unit.stats[stat] -= amount
			
			# Revert Swap Stats immediately
			if effect.get("type") == "swap_stats":
				var stats_swapped = effect.get("stats", [])
				if stats_swapped.size() == 2:
					var s1 = stats_swapped[0]
					var s2 = stats_swapped[1]
					var v1 = unit.stats.get(s1, 0)
					var v2 = unit.stats.get(s2, 0)
					unit.stats[s1] = v2
					unit.stats[s2] = v1
	
	if cleaned_count > 0:
		log_event.emit("Cleansed %d debuffs from %s!" % [cleaned_count, unit.data.monster_name])
		_refresh_unit_status(unit)
	else:
		log_event.emit("%s is already stable." % unit.data.monster_name)

func _handle_swap_stats(effect: Dictionary):
	var target = effect.get("target")
	var stats_to_swap = effect.get("stats", [])
	var duration = effect.get("duration", 2)
	
	if stats_to_swap.size() != 2: return
	
	var stat_a = stats_to_swap[0]
	var stat_b = stats_to_swap[1]
	
	var val_a = target.stats.get(stat_a, 0)
	var val_b = target.stats.get(stat_b, 0)
	
	# Apply the swap
	target.stats[stat_a] = val_b
	target.stats[stat_b] = val_a
	
	# Add tracking effect
	var swap_effect = {
		"type": "swap_stats",
		"stats": [stat_a, stat_b],
		"duration": duration,
		"name": "Stat Swap"
	}
	
	target.active_effects.append(swap_effect)
	_refresh_unit_status(target)

func _handle_remove_status(effect: Dictionary):
	var unit = effect.get("target")
	var status_name = effect.get("status")
	if not unit or not status_name: return
	
	if "active_effects" in unit:
		var effects = unit.active_effects
		for i in range(effects.size() - 1, -1, -1):
			if effects[i].get("status") == status_name:
				effects.remove_at(i)
		_refresh_unit_status(unit)

func _handle_team_status(attacker: BattleMonster, effect: Dictionary):
	var targets = []
	if attacker.is_player:
		targets = active_enemy_monsters
	else:
		targets = active_player_monsters
	
	var status_name = effect.get("status", "")
	if status_name == "": return
	var duration = effect.get("duration", 3)
	var pct = effect.get("damage_percent", 0.0)
	var applied_count = 0
	
	for unit in targets:
		if not unit.is_dead:
			if unit.has_status("invulnerable"):
				log_event.emit("%s is invulnerable!" % unit.data.monster_name)
				continue
				
			var dmg = 0
			if pct > 0:
				dmg = int(unit.max_hp * pct)
			
			var new_effect = {
				"target": unit,
				"status": status_name,
				"duration": duration,
				"type": "status"
			}
			if dmg > 0: new_effect["damage"] = dmg
			
			unit.apply_effect(new_effect)
			_refresh_unit_status(unit)
			applied_count += 1
			
	if applied_count > 0:
		log_event.emit("The entire team is affected!")

func _update_status_visuals(unit: BattleMonster):
	var has_vapor = false
	if "active_effects" in unit:
		for effect in unit.active_effects:
			if effect.get("status") == "reactive_vapor":
				has_vapor = true
				break
	
	var cloud = unit.find_child("VaporCloud", false, false)
	if has_vapor and not cloud:
		_create_vapor_cloud(unit)
	elif not has_vapor and cloud:
		cloud.queue_free()

func _create_vapor_cloud(parent: Node):
	var particles = CPUParticles2D.new()
	particles.name = "VaporCloud"
	particles.amount = 20
	particles.lifetime = 1.5
	particles.preprocess = 1.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 40.0
	particles.gravity = Vector2(0, -15)
	particles.scale_amount_min = 5.0
	particles.scale_amount_max = 10.0
	
	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.6, 0.1, 0.8, 0.5)) # Purple vapor
	gradient.set_color(1, Color(0.6, 0.1, 0.8, 0.0))
	particles.color_ramp = gradient
	
	parent.add_child(particles)

func _play_vapor_reaction(unit: BattleMonster):
	var tween = create_tween()
	tween.tween_property(unit, "modulate", Color(0.8, 0.2, 1.0), 0.1)
	tween.tween_property(unit, "modulate", Color.WHITE, 0.1)
	
	var base_pos = unit.position
	for i in range(5):
		var offset = Vector2(randf_range(-5, 5), randf_range(-5, 5))
		tween.tween_property(unit, "position", base_pos + offset, 0.05)
	tween.tween_property(unit, "position", base_pos, 0.05)

func _process_radiation(unit: BattleMonster):
	if unit.is_dead: return
	
	var rad_effect = null
	if "active_effects" in unit:
		for effect in unit.active_effects:
			if effect.get("status") == "radiation":
				rad_effect = effect
				break
	
	if rad_effect:
		var pct = rad_effect.get("damage_percent", 0.05)
		var dmg = int(unit.max_hp * pct)
		unit.take_damage(dmg)
		_show_damage_number(unit, dmg, "poison")
		log_event.emit("%s takes %d radiation damage!" % [unit.data.monster_name, dmg])
		_check_shield_update(unit)
		
		# Ramp up for next turn
		rad_effect["damage_percent"] = pct + 0.05

func _process_status_damage(unit: BattleMonster):
	if unit.is_dead: return
	
	# Check invulnerability manually to avoid potential issues with has_status()
	var is_invulnerable = false
	if "active_effects" in unit:
		for effect in unit.active_effects:
			if str(effect.get("status", "")).to_lower() == "invulnerable":
				is_invulnerable = true
				break
	
	if is_invulnerable: return
	
	# Handle Poison
	var total_dmg = 0
	if "active_effects" in unit:
		for effect in unit.active_effects:
			if str(effect.get("status", "")).to_lower() == "poison":
				var dmg = 0
				var pct = float(effect.get("damage_percent", 0.0))
				if pct > 0:
					dmg = int(unit.max_hp * pct)
				else:
					dmg = int(effect.get("damage", 0))
				
				if dmg <= 0:
					dmg = int(unit.max_hp * 0.1) # Fallback: 10% Max HP
					if dmg <= 0: dmg = 1 # Absolute fallback
				total_dmg += dmg
	
	if total_dmg > 0:
		unit.take_damage(total_dmg)
		_show_damage_number(unit, total_dmg, "poison")
		log_event.emit("%s takes poison damage!" % unit.data.monster_name)
		_check_shield_update(unit)

func _show_damage_number(unit: Node2D, amount: int, type: String = "damage"):
	var label = Label.new()
	label.z_index = 20 # On top of units
	
	var color = Color("#ff4d4d") # Red
	var scale_factor = 1.0
	var prefix = ""
	
	match type:
		"heal":
			color = Color("#2ecc71") # Green
			prefix = "+"
		"poison":
			color = Color("#802680") # Purple
		"crit":
			color = Color("#ffd700") # Gold
			scale_factor = 1.5
			
	label.text = prefix + str(amount)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 80)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	unit.add_child(label)
	label.position = Vector2(-50, -120) # Above unit
	label.custom_minimum_size = Vector2(100, 50)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 60, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	if scale_factor > 1.0:
		label.scale = Vector2(0.5, 0.5)
		tween.tween_property(label, "scale", Vector2(scale_factor, scale_factor), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	tween.chain().tween_callback(label.queue_free)
