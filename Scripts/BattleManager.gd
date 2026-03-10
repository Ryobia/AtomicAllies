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
var tutorial_paused: bool = false
var is_tutorial_battle: bool = false

# --- Signals for UI Decoupling ---
signal log_event(text)
signal hud_update_atb(is_player, index, value)
signal hud_update_hp(is_player, index, new_hp, max_hp)
signal hud_highlight_unit(is_player, index)
signal hud_update_shield(is_player, index, shield, max_hp)
signal hud_update_status(is_player, index, effects)

func _ready():
	if AudioManager:
		var music = load("res://Assets/Sounds/Horizon of the Unseen.mp3")
		if music:
			if music is AudioStreamMP3:
				music.loop = true
			AudioManager.play_music(music)

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
		# Resume from tutorial pause if step advanced
		if tutorial_paused:
			if TutorialManager and PlayerData.tutorial_step >= TutorialManager.Step.BATTLE_RESUME:
				tutorial_paused = false
				resume_battle()
			return # Skip ATB processing while paused
			
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
	active_player_monsters = [null, null, null] # Initialize fixed slots
	is_tutorial_battle = false # Reset at start of every battle
	
	# Detect Tutorial Run (Lithium Discovery) - Persist across all waves
	if TutorialManager and CampaignManager and CampaignManager.is_rogue_run and \
	   CampaignManager.current_run_target_z == 3 and \
	   PlayerData.tutorial_step < TutorialManager.Step.COMPLETE:
		is_tutorial_battle = true
		
		# Force Null Grunt enemies for tutorial, overriding CampaignManager's generation
		enemy_data_list.clear()
		var count = 1
		# Last wave gets 2 enemies
		if CampaignManager.current_run_wave >= CampaignManager.max_run_waves:
			count = 2
			
		var grunt_path = "res://data/Enemies/NullGrunt.tres"
		if ResourceLoader.exists(grunt_path):
			var base = load(grunt_path)
			for k in range(count):
				var e = base.duplicate()
				e.stability = 50
				enemy_data_list.append(e)

	roster_hp_cache.clear()
	_update_team_passives()
	
	# Load initial state from CampaignManager if rogue run
	if CampaignManager and CampaignManager.is_rogue_run:
		for m in CampaignManager.run_team_state:
			var data = CampaignManager.run_team_state[m]
			if typeof(data) == TYPE_INT:
				roster_hp_cache[m] = { "hp": data, "stats": {} }
			elif typeof(data) == TYPE_DICTIONARY:
				roster_hp_cache[m] = data.duplicate(true)
	
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

		var is_dead = false
		if roster_hp_cache.has(unit_data):
			var state = roster_hp_cache[unit_data]
			var hp: int = 0
			if typeof(state) == TYPE_INT:
				hp = state
			elif typeof(state) == TYPE_DICTIONARY:
				var val = state.get("hp", 0)
				if typeof(val) == TYPE_INT or typeof(val) == TYPE_FLOAT:
					hp = int(val)
			if hp <= 0:
				is_dead = true
		
		if i < 3:
			if is_dead:
				benched_player_monsters.append(unit_data)
				continue

			var spawn_idx = i
			if player_spawn_points.size() >= 3:
				spawn_idx = spawn_map[i]
			
			if spawn_idx < player_spawn_points.size():
				spawn_unit(unit_data, player_spawn_points[spawn_idx], true, i)
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
		if not unit: continue
		if unit.data.group == AtomicConfig.Group.ALKALI_METAL and unit.data.stability >= 100:
			unit.atb_value = 100.0
			_show_mastery_trigger(unit, "Mastery: Free Turn!")
		
		# Mastery: Alkaline Earths (100% Stability) -> Start with 25% Shield
		if unit.data.group == AtomicConfig.Group.ALKALINE_EARTH and unit.data.stability >= 100:
			var shield_amt = int(unit.max_hp * 0.25)
			unit.set_meta("shield", shield_amt)
			_check_shield_update(unit)
			_show_mastery_trigger(unit, "Mastery: Shielded!")
			
		# Mastery: Halogens (100% Stability) -> Randomly poison 1 enemy
		if unit.data.group == AtomicConfig.Group.HALOGEN and unit.data.stability >= 100:
			var targets = active_enemy_monsters if unit.is_player else active_player_monsters
			var living_targets = targets.filter(func(m): return not m.is_dead)
			
			if not living_targets.is_empty():
				var target = living_targets.pick_random()
				target.apply_effect({ "status": "poison", "duration": 3, "damage_percent": 0.1, "type": "status" })
				_refresh_unit_status(target)
				_show_mastery_trigger(unit, "Mastery: Toxic Start!")
				_show_damage_number(target, 0, "poison") # Keep visual cue on target
	
	# Setup the HUD with the monster data
	if battle_hud:
		var player_data = []
		for unit in active_player_monsters:
			if unit: player_data.append(unit.data)
			else: player_data.append(null)
		# The setup_ui function expects a list of MonsterData, not BattleMonster nodes
		battle_hud.setup_ui(player_data, enemy_data_list)
		
		# Force update HUD with actual HP values (since setup_ui defaults to Max HP)
		for i in range(active_player_monsters.size()):
			var unit = active_player_monsters[i]
			if unit:
				hud_update_hp.emit(true, i, unit.current_hp, unit.max_hp)
				_refresh_unit_status(unit)
			
		for i in range(active_enemy_monsters.size()):
			var unit = active_enemy_monsters[i]
			hud_update_hp.emit(false, i, unit.current_hp, unit.max_hp)
			_refresh_unit_status(unit)

	# Tutorial Hook: Start Battle Tutorial
	if TutorialManager and PlayerData.tutorial_step == TutorialManager.Step.START_BATTLE:
		is_tutorial_battle = true
		# Advance from START_BATTLE (12) to BATTLE_INTRO (13)
		TutorialManager.advance_step()
		# Note: TutorialManager will handle the rest via advance_step calls

	# Start the clock
	current_state = BattleState.COUNTING

func spawn_unit(data: MonsterData, spawn_marker: Marker2D, is_player: bool, slot_index: int = -1):
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
				var state = roster_hp_cache[data]
				if typeof(state) == TYPE_INT:
					unit.current_hp = state
				elif typeof(state) == TYPE_DICTIONARY:
					var hp_val = state.get("hp", unit.max_hp)
					unit.current_hp = hp_val if (typeof(hp_val) == TYPE_INT or typeof(hp_val) == TYPE_FLOAT) else 0
					var saved_stats = state.get("stats", {})
					for stat in saved_stats:
						if unit.stats.has(stat):
							unit.stats[stat] = saved_stats[stat]
					
					var saved_meta = state.get("meta", {})
					for key in saved_meta:
						unit.set_meta(key, saved_meta[key])
					
					var saved_effects = state.get("effects", [])
					if not saved_effects.is_empty():
						unit.active_effects = saved_effects.duplicate(true)
						if unit.has_signal("effects_changed"): unit.effects_changed.emit(unit.active_effects)
				
				if unit.current_hp <= 0:
					unit.is_dead = true
					# If unit spawns dead, BattleManager logic will handle forcing a swap/loss
			
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
		if slot_index != -1:
			# Ensure array is large enough (safeguard against shrinking)
			while active_player_monsters.size() <= slot_index:
				active_player_monsters.append(null)
			active_player_monsters[slot_index] = unit
		else:
			active_player_monsters.append(unit)
	else:
		active_enemy_monsters.append(unit)
		# Track encounter for Codex
		if PlayerData:
			PlayerData.mark_enemy_seen(data.monster_name)
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
			var available_replacements = benched_player_monsters.filter(func(m):
				if roster_hp_cache.has(m):
					var state = roster_hp_cache[m]
					var hp: int = 0
					if typeof(state) == TYPE_INT:
						hp = state
					elif typeof(state) == TYPE_DICTIONARY:
						var val = state.get("hp", 0)
						if typeof(val) == TYPE_INT or typeof(val) == TYPE_FLOAT:
							hp = int(val)
					if hp <= 0:
						return false
				return true
			)
			
			if available_replacements.is_empty():
				_force_bench_dead_unit(current_acting_unit)
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
		var available_replacements = benched_player_monsters.filter(func(m):
			if roster_hp_cache.has(m):
				var state = roster_hp_cache[m]
				var hp: int = 0
				if typeof(state) == TYPE_INT:
					hp = state
				elif typeof(state) == TYPE_DICTIONARY:
					var val = state.get("hp", 0)
					if typeof(val) == TYPE_INT or typeof(val) == TYPE_FLOAT:
						hp = int(val)
				if hp <= 0:
					return false
			return true
		)
		
		if current_acting_unit.is_player and not available_replacements.is_empty():
			log_event.emit("%s has fallen! Choose a replacement!" % current_acting_unit.data.monster_name)
			if battle_hud:
				battle_hud.show_swap_options(_get_swap_options(), true)
			return
		elif current_acting_unit.is_player:
			_force_bench_dead_unit(current_acting_unit)
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
			var can_swap = false
			for m in benched_player_monsters:
				var hp = 1
				if roster_hp_cache.has(m):
					var state = roster_hp_cache[m]
					if typeof(state) == TYPE_INT:
						hp = state
					elif typeof(state) == TYPE_DICTIONARY:
						var val = state.get("hp", 1)
						if typeof(val) == TYPE_INT or typeof(val) == TYPE_FLOAT:
							hp = int(val)
						else:
							hp = 0
				
				if hp > 0:
					can_swap = true
					break
			
			battle_hud.set_swap_disabled(not can_swap)
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
	var potential_targets = active_player_monsters.filter(func(m): return m and not m.is_dead)
	
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
			battle_hud.show_moves(moves, current_acting_unit.move_cooldowns)
			
		if TutorialManager and PlayerData.tutorial_step == TutorialManager.Step.SELECT_ATTACK:
			TutorialManager.advance_step() # To SELECT_MOVE
			
	elif action_type == "swap":
		var can_swap = false
		for m in benched_player_monsters:
			if not (roster_hp_cache.has(m) and roster_hp_cache[m] <= 0):
				can_swap = true
				break
				
		if not can_swap:
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
	
	# --- Calculate Valid Targets ---
	var valid_targets = []
	var target_allies = (move.target_type == MoveData.TargetType.ALLY or move.target_type == MoveData.TargetType.SELF)
	
	if target_allies:
		if move.target_type == MoveData.TargetType.SELF:
			# Only the user can be the target
			var self_index = active_player_monsters.find(current_acting_unit)
			if self_index != -1:
				valid_targets.append(self_index)
		else: # It's an ALLY move
			# Ally Targeting
			for i in range(active_player_monsters.size()):
				var ally = active_player_monsters[i]
				if ally and not ally.is_dead:
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
	battle_hud.set_targeting_mode(true, valid_targets, target_allies or move.target_type == MoveData.TargetType.SELF)
	log_event.emit("Select a target for %s..." % move.name)
	
	if TutorialManager and PlayerData.tutorial_step == TutorialManager.Step.SELECT_MOVE:
		if move.name == "Electronegativity":
			TutorialManager.advance_step() # To EXPLAIN_TARGETING

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
			if active_player_monsters[i] and not active_player_monsters[i].is_dead:
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
	if selected_move.target_type == MoveData.TargetType.ALLY or selected_move.target_type == MoveData.TargetType.SELF:
		defender = active_player_monsters[index]
	else:
		defender = active_enemy_monsters[index]
	
	if not defender:
		log_event.emit("Invalid target!")
		return
	
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
	
	if TutorialManager and PlayerData.tutorial_step == TutorialManager.Step.EXPLAIN_TARGETING:
		TutorialManager.advance_step() # To INSPECT_ENEMY
	
	perform_move(current_acting_unit, defender, selected_move)

func _on_swap_selected(index: int):
	if current_state != BattleState.ACTION_SELECTION: return
	
	# Hide HUD options
	if battle_hud:
		battle_hud.move_container.visible = false
		
	var new_monster_data = benched_player_monsters[index]
	
	var is_dead = false
	if roster_hp_cache.has(new_monster_data):
		var state = roster_hp_cache[new_monster_data]
		var hp = state if typeof(state) == TYPE_INT else state.get("hp", 0)
		if hp <= 0: is_dead = true
		
	if is_dead:
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

	if TutorialManager and PlayerData.tutorial_step == TutorialManager.Step.INSPECT_ENEMY:
		TutorialManager.advance_step() # To CLOSE_INSPECT_ENEMY

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
	
	if index == -1:
		push_error("BattleManager: Active unit not found in roster during swap!")
		return
	
	# Save state of retreating unit
	_strip_temporary_buffs(active_unit)
	roster_hp_cache[active_unit.data] = { "hp": active_unit.current_hp, "stats": active_unit.stats.duplicate(), "effects": active_unit.active_effects.duplicate(true), "meta": _get_persistent_meta(active_unit) }
	
	all_monsters.erase(active_unit)
	active_unit.queue_free()
	
	log_event.emit("Go! %s!" % new_data.monster_name)
		
	spawn_unit(new_data, marker, true, index)
	
	# The new unit is the last added to active_player_monsters by spawn_unit
	var new_unit = active_player_monsters[index]
	
	new_unit.atb_value = 0 # Start fresh
	new_unit.play_move() # Play enter animation
	
	_update_team_passives()
	
	# Refresh HUD visuals (Sprites/Names) and restore Bars
	if battle_hud:
		var player_data_list = []
		for unit in active_player_monsters:
			if unit: player_data_list.append(unit.data)
			else: player_data_list.append(null)
		var enemy_data_list = []
		for unit in active_enemy_monsters:
			enemy_data_list.append(unit.data)
			
		battle_hud.setup_ui(player_data_list, enemy_data_list)
		
		# Restore HP/ATB values on HUD since setup_ui resets them to max/zero
		for i in range(active_player_monsters.size()):
			var u = active_player_monsters[i]
			if u:
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
					reflect_dmg = _calculate_final_damage(attacker, reflect_dmg)
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
				
				damage = _calculate_final_damage(defender, damage)
				
				if damage > 0:
					defender.take_damage(damage)
					_show_damage_number(defender, damage, "damage")
					log_event.emit("Dealt %d damage!" % damage)
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
					if unit != attacker and unit and not unit.is_dead:
						var final_amount = _calculate_final_damage(unit, amount)
						if final_amount > 0:
							unit.take_damage(final_amount)
							_show_damage_number(unit, final_amount, "damage")
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
					var final_amount = _calculate_final_damage(target, amount)
					if final_amount > 0:
						target.take_damage(final_amount)
						_show_damage_number(target, final_amount, "damage")
						log_event.emit("%s takes %d recoil damage!" % [target.data.monster_name, final_amount])
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
				var living = enemies.filter(func(m): return m and not m.is_dead and m != defender)
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
	if move.cooldown > 1:
		attacker.move_cooldowns[move.name] = move.cooldown
		
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
	
	if TutorialManager and PlayerData.tutorial_step == TutorialManager.Step.EXPLAIN_TARGETING:
		TutorialManager.advance_step() # To INSPECT_ENEMY
		
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
	
	if TutorialManager and PlayerData.tutorial_step == TutorialManager.Step.INSPECT_ENEMY:
		tutorial_paused = true
		current_state = BattleState.COUNTING # Ensure _process runs to check for resume
		return # Pause here for inspection tutorial
	
	# Go back to counting or process next in queue
	if turn_queue.is_empty():
		current_state = BattleState.COUNTING
	else:
		start_turn()

func resume_battle():
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
			
			# Neutron Dust: Common, flat amount
			if randf() < 0.5: # 50% chance
				var dust_amount = randi_range(100, 200)
				rewards["neutron_dust"] = dust_amount
			
			# Gems: Rare, small amount
			if randf() < 0.05: # 5% chance
				rewards["gems"] = 1
		else:
			for unit in active_enemy_monsters:
				# Binding Energy: Base 10 + (Atomic Number * 2)
				total_be += 10 + (unit.data.atomic_number * 2)
		
		# Save state of surviving active units
		for unit in active_player_monsters:
			if unit:
				_strip_temporary_buffs(unit)
				roster_hp_cache[unit.data] = { "hp": unit.current_hp, "stats": unit.stats.duplicate(), "effects": unit.active_effects.duplicate(true), "meta": _get_persistent_meta(unit) }

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
		if player_won and CampaignManager.current_run_dust > 0: rewards["neutron_dust"] = CampaignManager.current_run_dust
		if player_won and CampaignManager.current_run_gems > 0: rewards["gems"] = CampaignManager.current_run_gems

	if battle_hud:
		battle_hud.show_result(player_won, rewards)

func _on_monster_death(dead_unit: BattleMonster):
	# Death animation is handled in BattleMonster.die(), so we just check win condition
	
	# Lanthanide Passive: Absorb 10% of stats of fallen enemies
	var all_active = active_player_monsters + active_enemy_monsters
	for unit in all_active:
		if unit and not unit.is_dead and unit.data.group == AtomicConfig.Group.LANTHANIDE:
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
	
	# If player unit dies, handle replacement or removal
	if dead_unit.is_player:
		# If dying during start-of-turn checks, let start_turn handle it to avoid crashes
		if dead_unit == current_acting_unit and current_state == BattleState.ACTION_SELECTION:
			pass
		else:
			var available_replacements = benched_player_monsters.filter(func(m):
				if roster_hp_cache.has(m):
					var state = roster_hp_cache[m]
					var hp: int = 0
					if typeof(state) == TYPE_INT:
						hp = state
					elif typeof(state) == TYPE_DICTIONARY:
						var val = state.get("hp", 0)
						if typeof(val) == TYPE_INT or typeof(val) == TYPE_FLOAT:
							hp = int(val)
					if hp <= 0:
						return false
				return true
			)
			
			if available_replacements.is_empty():
				_force_bench_dead_unit(dead_unit)
			else:
				dead_unit.atb_value = 100.0
	
	check_win_condition()

func check_win_condition():
	if current_state == BattleState.END: return

	var player_team_defeated = true
	for m in active_player_monsters:
		if m and not m.is_dead:
			player_team_defeated = false
			break
			
	var bench_has_living = false
	for m in benched_player_monsters:
		# If not in cache, assume alive (fresh). If in cache and > 0, alive.
		var hp = 1
		if roster_hp_cache.has(m):
			var state = roster_hp_cache[m]
			if typeof(state) == TYPE_INT:
				hp = state
			else:
				var val = state.get("hp", 1)
				if typeof(val) == TYPE_INT or typeof(val) == TYPE_FLOAT:
					hp = val
				else:
					hp = 0
		if hp > 0:
			bench_has_living = true
			break
			
	if player_team_defeated and not bench_has_living:
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
		if not roster_hp_cache.has(unit.data) or typeof(roster_hp_cache[unit.data]) == TYPE_INT:
			roster_hp_cache[unit.data] = { "hp": new_hp, "stats": unit.stats.duplicate(), "effects": unit.active_effects.duplicate(true), "meta": _get_persistent_meta(unit) }
		else:
			roster_hp_cache[unit.data]["hp"] = new_hp

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
		if roster_hp_cache.has(m):
			var state = roster_hp_cache[m]
			var hp = state if typeof(state) == TYPE_INT else state.get("hp", 1)
			if typeof(hp) != TYPE_INT and typeof(hp) != TYPE_FLOAT: hp = 0
			if hp <= 0: is_dead = true
		options.append({ "monster": m, "is_dead": is_dead })
	return options

func _update_team_passives():
	# Apply Team Auras (Passives)
	var nonmetal_count_p = 0
	for u in active_player_monsters:
		if u and not u.is_dead and u.data.group == AtomicConfig.Group.NONMETAL:
			nonmetal_count_p += 1
			
	for u in active_player_monsters:
		if not u: continue
		# First, remove any existing nonmetal passive to prevent incorrect stacking on re-calc
		if "active_effects" in u:
			for i in range(u.active_effects.size() - 1, -1, -1):
				var effect = u.active_effects[i]
				if effect.get("source") == "nonmetal_passive":
					if u.stats.has(effect.get("stat")):
						u.stats[effect.get("stat")] -= effect.get("amount", 0)
					u.active_effects.remove_at(i)
		
		# Nonmetal Aura: Allies gain 5% attack per Nonmetal
		if nonmetal_count_p > 0:
			var buff_id = "persist_nonmetal_atk_fraction"
			var existing_fraction = u.get_meta(buff_id, 0.0)
			
			# Calculate buff based on base stats to prevent compounding with other in-battle buffs
			var base_attack = u.data.get_current_stats().attack
			var buff_value = (base_attack * (0.05 * nonmetal_count_p)) + existing_fraction
			
			var integer_part = int(buff_value)
			var fractional_part = buff_value - float(integer_part)
			
			u.set_meta(buff_id, fractional_part)
			
			if integer_part > 0:
				u.apply_effect({ "target": u, "stat": "attack", "amount": integer_part, "duration": 99, "type": "stat_mod", "source": "nonmetal_passive" })

	var nonmetal_count_e = 0
	for u in active_enemy_monsters:
		if not u.is_dead and u.data.group == AtomicConfig.Group.NONMETAL:
			nonmetal_count_e += 1
			
	for u in active_enemy_monsters:
		# Enemies don't persist, so no need for fractional logic, but we fix the compounding.
		if nonmetal_count_e > 0:
			var base_attack = u.data.get_current_stats().attack
			var amount = int(base_attack * (0.05 * nonmetal_count_e))
			if amount > 0:
				u.apply_effect({ "target": u, "stat": "attack", "amount": amount, "duration": 99, "type": "stat_mod", "source": "nonmetal_passive" })

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
			loss = _calculate_final_damage(unit, loss)
			if loss > 0:
				unit.take_damage(loss)
				_show_damage_number(unit, loss, "poison")
				log_event.emit("%s decays!" % unit.data.monster_name)
				_check_shield_update(unit)
			
			# Apply Radiation to enemies
			var targets = active_enemy_monsters if unit.is_player else active_player_monsters
			var applied = false
			for target in targets:
				if target and not target.is_dead:
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
	var living = enemies.filter(func(m): return m and not m.is_dead)
	
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
		if unit == null: continue
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
		for u in active_player_monsters: 
			if u: player_data.append(u.data)
			else: player_data.append(null)
		var enemy_data = []
		for u in active_enemy_monsters: enemy_data.append(u.data)
		
		battle_hud.setup_ui(player_data, enemy_data)
		
		# Restore Bars and Status for the shuffled team
		for i in range(team.size()):
			var u = team[i]
			if u:
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
			
			unit.active_effects.remove_at(i)
	
	if cleaned_count > 0:
		log_event.emit("Cleansed %d debuffs from %s!" % [cleaned_count, unit.data.monster_name])
		_refresh_unit_status(unit)
	else:
		log_event.emit("%s is already stable." % unit.data.monster_name)

func _get_persistent_meta(unit: BattleMonster) -> Dictionary:
	var meta_to_save = {}
	var all_meta = unit.get_meta_list()
	for key in all_meta:
		if key.begins_with("persist_"):
			meta_to_save[key] = unit.get_meta(key)
	return meta_to_save

func _force_bench_dead_unit(unit: BattleMonster):
	log_event.emit("%s retreats to the bench!" % unit.data.monster_name)
	
	var index = active_player_monsters.find(unit)
	if index != -1:
		active_player_monsters[index] = null
	
	benched_player_monsters.append(unit.data)
	
	# Save state
	_strip_temporary_buffs(unit)
	roster_hp_cache[unit.data] = { "hp": 0, "stats": unit.stats.duplicate(), "effects": [], "meta": _get_persistent_meta(unit) }
	
	all_monsters.erase(unit)
	unit.queue_free()
	
	# Update HUD
	if battle_hud:
		var player_data = []
		for u in active_player_monsters: 
			if u: player_data.append(u.data)
			else: player_data.append(null)
		var enemy_data = []
		for u in active_enemy_monsters: enemy_data.append(u.data)
		
		battle_hud.setup_ui(player_data, enemy_data)
		
		# Restore Bars for remaining units
		for i in range(active_player_monsters.size()):
			var u = active_player_monsters[i]
			if u:
				hud_update_hp.emit(true, i, u.current_hp, u.max_hp)
				hud_update_atb.emit(true, i, u.atb_value)
				_refresh_unit_status(u)

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
		if unit and not unit.is_dead:
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
	var has_radiation = false
	var has_stun = false
	
	if "active_effects" in unit:
		for effect in unit.active_effects:
			var s = effect.get("status")
			if s == "reactive_vapor" or s == "poison":
				has_vapor = true
			elif s == "radiation":
				has_radiation = true
			elif s == "stun":
				has_stun = true
	
	var cloud = unit.find_child("VaporCloud", false, false)
	if has_vapor and not cloud:
		_create_vapor_cloud(unit)
	elif not has_vapor and cloud:
		cloud.queue_free()
		
	var glow = unit.find_child("RadiationGlow", false, false)
	if has_radiation and not glow:
		_create_radiation_glow(unit)
	elif not has_radiation and glow:
		glow.queue_free()
		
	var stun = unit.find_child("StunVisual", false, false)
	if has_stun and not stun:
		_create_stun_visual(unit)
	elif not has_stun and stun:
		stun.queue_free()

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

func _create_radiation_glow(parent: Node):
	var particles = CPUParticles2D.new()
	particles.name = "RadiationGlow"
	particles.amount = 24
	particles.lifetime = 1.2
	particles.preprocess = 0.5
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 55.0
	particles.gravity = Vector2(0, -10)
	particles.scale_amount_min = 8.0
	particles.scale_amount_max = 16.0
	
	var gradient = Gradient.new()
	gradient.set_color(0, Color(0.4, 1.0, 0.2, 0.6)) # Radioactive Green
	gradient.set_color(1, Color(0.4, 1.0, 0.2, 0.0))
	particles.color_ramp = gradient
	
	parent.add_child(particles)

func _create_stun_visual(parent: Node):
	var particles = CPUParticles2D.new()
	particles.name = "StunVisual"
	particles.amount = 12
	particles.lifetime = 1.0
	particles.preprocess = 0.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 35.0
	particles.gravity = Vector2(0, 0)
	particles.orbit_velocity_min = 1.0
	particles.orbit_velocity_max = 1.5
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 8.0
	particles.color = Color("#ffd700") # Gold
	
	parent.add_child(particles)
	particles.position = Vector2(0, -100) # Above head

func _play_vapor_reaction(unit: BattleMonster):
	var tween = create_tween()
	tween.tween_property(unit, "modulate", Color(0.8, 0.2, 1.0), 0.1)
	tween.tween_property(unit, "modulate", Color.WHITE, 0.1)
	
	var base_pos = unit.position
	for i in range(5):
		var offset = Vector2(randf_range(-5, 5), randf_range(-5, 5))
		tween.tween_property(unit, "position", base_pos + offset, 0.05)
	tween.tween_property(unit, "position", base_pos, 0.05)

func _show_mastery_trigger(unit: Node2D, text: String):
	var label = Label.new()
	label.z_index = 25 # Above damage numbers
	label.text = text
	
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color("#ffd700")) # Gold
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	unit.add_child(label)
	label.position = Vector2(-100, -160) # Above unit, wider
	label.custom_minimum_size = Vector2(200, 60)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2(1.2, 1.2), 0.3).from(Vector2.ZERO).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(label, "modulate:a", 0.0, 0.5).set_delay(1.5)
	tween.chain().tween_callback(label.queue_free)

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
		dmg = _calculate_final_damage(unit, dmg)
		if dmg > 0:
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
		total_dmg = _calculate_final_damage(unit, total_dmg)
		if total_dmg > 0:
			unit.take_damage(total_dmg)
			_show_damage_number(unit, total_dmg, "poison")
			log_event.emit("%s takes poison damage!" % unit.data.monster_name)
			_check_shield_update(unit)

func _calculate_final_damage(target: BattleMonster, amount: int) -> int:
	if not is_tutorial_battle or not target.is_player:
		return amount
		
	if (target.current_hp - amount) <= 0:
		var final_amount = target.current_hp - 1
		if final_amount < 0: final_amount = 0
		
		# Only log if damage was actually prevented
		if final_amount < amount:
			log_event.emit("%s is protected by L.U.M.N.!" % target.data.monster_name)
		
		return final_amount
	return amount
	
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
	label.custom_minimum_size = Vector2(100, 50)
	label.position = Vector2(-50, -120) # Above unit
	label.pivot_offset = label.custom_minimum_size / 2
	label.scale = Vector2(0.1, 0.1)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 60, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	tween.tween_property(label, "scale", Vector2(scale_factor, scale_factor), 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	tween.chain().tween_callback(label.queue_free)

func _strip_temporary_buffs(unit: BattleMonster):
	if not "active_effects" in unit: return
	
	# Iterate backwards to safely remove or revert
	for i in range(unit.active_effects.size() - 1, -1, -1):
		var effect = unit.active_effects[i]
		var duration = effect.get("duration", 0)
		
		# Assume duration >= 50 is "permanent" for the run (like 99)
		if duration < 50:
			if effect.get("type") == "stat_mod":
				var stat = effect.get("stat")
				var amount = effect.get("amount", 0)
				if unit.stats.has(stat):
					unit.stats[stat] -= amount
			elif effect.get("type") == "swap_stats":
				# Revert swap
				var stats_swapped = effect.get("stats", [])
				if stats_swapped.size() == 2:
					var s1 = stats_swapped[0]
					var s2 = stats_swapped[1]
					var v1 = unit.stats.get(s1, 0)
					var v2 = unit.stats.get(s2, 0)
					unit.stats[s1] = v2
					unit.stats[s2] = v1
