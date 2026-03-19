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

const SPAWN_MAP = [1, 0, 2] # 0->Center, 1->Left, 2->Right

# --- State ---
enum BattleState { SETUP, COUNTING, ACTION_SELECTION, TARGET_SELECTION, EXECUTING, END }
var current_state = BattleState.SETUP

var active_player_monsters: Array = []
var active_enemy_monsters: Array = []
var all_monsters: Array = [] # Combined list for ATB processing
var benched_player_monsters: Array[MonsterData] = []
var current_player_team: Array[MonsterData] = []
var _temp_item_targets: Array[MonsterData] = []

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
		battle_hud.battle_finished.connect(_on_battle_hud_finished)
		
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
		player_roster = PlayerData.owned_monsters.duplicate()
		PlayerData.active_team = player_roster
		
	# Fallback safety net for new players
	if player_roster.is_empty() and MonsterManifest:
		push_warning("BattleManager: Player roster empty. Generating starters.")
		var h = MonsterManifest.get_monster(1)
		var he = MonsterManifest.get_monster(2)
		if h: PlayerData.owned_monsters.append(h.duplicate())
		if he: PlayerData.owned_monsters.append(he.duplicate())
		player_roster = PlayerData.owned_monsters.duplicate()
		PlayerData.active_team = player_roster
	
	benched_player_monsters.clear()
	current_player_team = player_roster.duplicate()
	
	for i in range(current_player_team.size()):
		var unit_data = current_player_team[i]
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
			if not is_dead:
				var spawn_idx = i
				if player_spawn_points.size() >= 3:
					spawn_idx = SPAWN_MAP[i]
				
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
			spawn_idx = SPAWN_MAP[i]
			
		if spawn_idx < enemy_spawn_points.size():
			spawn_unit(enemy_data_list[i], enemy_spawn_points[spawn_idx], false)
		
	var player_count = active_player_monsters.size()
	print("BattleManager: Battle started with %d vs %d units." % [player_count, enemy_count])
	_update_team_passives()
	
	# Mastery: Nonmetals (100% Stability) -> Free Turn at Start
	var all_units = active_player_monsters + active_enemy_monsters
	for unit in all_units:
		if not unit: continue
		if unit.data.group == AtomicConfig.Group.NONMETAL and unit.data.stability >= 100:
			unit.atb_value = 100.0
			_show_mastery_trigger(unit, "Mastery: Free Turn!")
		
		# Mastery: Alkaline Earths (100% Stability) -> Start with 25% Shield
		if unit.data.group == AtomicConfig.Group.ALKALINE_EARTH and unit.data.stability >= 100:
			var shield_amt = int(unit.max_hp * 0.25)
			unit.set_meta("shield", shield_amt)
			_check_shield_update(unit)
			_show_mastery_trigger(unit, "Mastery: Shielded!")
			_play_status_vfx(unit, "shield")
			
		# Mastery: Halogens (100% Stability) -> Randomly poison 1 enemy
		if unit.data.group == AtomicConfig.Group.HALOGEN and unit.data.stability >= 100:
			var targets = active_enemy_monsters if unit.is_player else active_player_monsters
			var living_targets = targets.filter(func(m): return not m.is_dead)
			
			if not living_targets.is_empty():
				var target = living_targets.pick_random()
				target.apply_effect({ "status": "poison", "duration": 3, "damage_percent": 0.1, "type": "status" })
				_refresh_unit_status(target)
				_play_status_vfx(target, "poison")
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
				_check_shield_update(unit)
				_refresh_unit_status(unit)
			
		for i in range(active_enemy_monsters.size()):
			var unit = active_enemy_monsters[i]
			hud_update_hp.emit(false, i, unit.current_hp, unit.max_hp)
			_check_shield_update(unit)
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
				battle_hud.show_swap_options(_get_swap_options(), true, current_acting_unit.data.monster_name, index)
			return
		else:
			end_turn()
			return

	current_acting_unit.on_turn_start()
	_process_status_damage(current_acting_unit)
	_process_status_heal(current_acting_unit)
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
			var index = active_player_monsters.find(current_acting_unit)
			if battle_hud:
				battle_hud.show_swap_options(_get_swap_options(), true, current_acting_unit.data.monster_name, index)
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
	
	var available_moves = []
	for m in moves:
		if not current_acting_unit.move_cooldowns.has(m.name):
			available_moves.append(m)
			
	var move = null
	if available_moves.is_empty():
		# Fallback move
		move = MoveData.new()
		move.name = "Struggle"
		move.power = 10
	else:
		# AI Logic: Categorize Moves
		var heals = []
		var buffs = []
		var attacks = []
		var debuffs = []
		
		for m in available_moves:
			if m.type == "Status_Friendly":
				var is_heal = false
				for eff in m.effects:
					if eff.get("effect") in ["heal", "team_heal", "add_shield", "add_team_shield", "heal_overflow_shield"]:
						is_heal = true
						break
				if is_heal: heals.append(m)
				else: buffs.append(m)
			elif m.type == "Status_Hostile":
				debuffs.append(m)
			else:
				attacks.append(m)
				
		# Analyze Allies
		var allies = active_enemy_monsters.filter(func(m): return not m.is_dead)
		var lowest_ally_hp_pct = 1.0
		
		for a in allies:
			var pct = float(a.current_hp) / float(a.max_hp)
			if pct < lowest_ally_hp_pct:
				lowest_ally_hp_pct = pct
				
		# AI Decision Tree
		if lowest_ally_hp_pct < 0.4 and not heals.is_empty():
			move = heals.pick_random() # 1. Critical Healing
		elif not buffs.is_empty() and randf() < 0.4:
			move = buffs.pick_random() # 2. Buffing
		elif not attacks.is_empty() and randf() < 0.8:
			move = attacks.pick_random() # 3. Attacking
		elif not debuffs.is_empty():
			move = debuffs.pick_random() # 4. Debuffing
		else:
			move = available_moves.pick_random() # Fallback
	
	# 2. Determine Valid Targets
	# Handle Self/Ally targeting for AI
	if move.target_type == MoveData.TargetType.SELF:
		perform_move(current_acting_unit, current_acting_unit, move)
		return
	elif move.target_type == MoveData.TargetType.ALLY:
		var allies = active_enemy_monsters.filter(func(m): return not m.is_dead)
		if not allies.is_empty():
			var is_heal = false
			for eff in move.effects:
				if eff.get("effect") in ["heal", "add_shield", "heal_overflow_shield"]: is_heal = true
			
			var target_ally = null
			if is_heal:
				# Find lowest HP ally for heals/shields
				allies.sort_custom(func(a, b): return (float(a.current_hp) / float(a.max_hp)) < (float(b.current_hp) / float(b.max_hp)))
				target_ally = allies[0]
			else:
				# Find strongest ally to buff
				allies.sort_custom(func(a, b): return (a.stats.get("attack", 0) + a.max_hp) > (b.stats.get("attack", 0) + b.max_hp))
				target_ally = allies[0]
				
			perform_move(current_acting_unit, target_ally, move)
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
	
	var target = null
	
	# Execution Priority (Target enemies below 25% HP)
	var execute_targets = valid_targets.filter(func(m): return float(m.current_hp) / float(m.max_hp) < 0.25)
	if not execute_targets.is_empty():
		execute_targets.sort_custom(func(a, b): return a.current_hp < b.current_hp)
		target = execute_targets[0]
	else:
		# AI Preference: Target weakest unit (Lowest HP + Def)
		if valid_targets.size() > 1:
			valid_targets.sort_custom(func(a, b):
				var score_a = a.current_hp + a.stats.get("defense", 0)
				var score_b = b.current_hp + b.stats.get("defense", 0)
				return score_a < score_b
			)
		target = valid_targets[0]
	
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
			var is_dead = false
			if roster_hp_cache.has(m):
				var state = roster_hp_cache[m]
				var hp = state if typeof(state) == TYPE_INT else state.get("hp", 0)
				if typeof(hp) != TYPE_INT and typeof(hp) != TYPE_FLOAT: hp = 0
				if hp <= 0: is_dead = true
			if not is_dead:
				can_swap = true
				break
				
		if not can_swap:
			log_event.emit("No monsters to swap with!")
			return
		if battle_hud:
			battle_hud.show_swap_options(_get_swap_options())

	elif action_type == "item":
		_show_item_menu()

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
		# Enemy Targeting logic...
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
	
	# Check for Bench Targets (Swap Moves)
	var bench_info = {}
	var can_target_bench = false
	for eff in move.effects:
		if eff.get("effect") == "swap_position":
			can_target_bench = true
			break
			
	if can_target_bench:
		var valid_bench_indices = []
		for i in range(benched_player_monsters.size()):
			var m = benched_player_monsters[i]
			var is_alive = true
			if roster_hp_cache.has(m):
				var state = roster_hp_cache[m]
				var hp = state if typeof(state) == TYPE_INT else state.get("hp", 0)
				if hp <= 0: is_alive = false
			if is_alive: valid_bench_indices.append(i)
		
		if not valid_bench_indices.is_empty():
			bench_info = { "indices": valid_bench_indices, "data": benched_player_monsters }
	
	# Show move details and enable targeting mode on the HUD
	battle_hud.show_move_details(move)
	battle_hud.set_targeting_mode(true, valid_targets, target_allies or move.target_type == MoveData.TargetType.SELF, bench_info)
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
	var is_revive = (data.get("effect") == "revive")
	var valid_targets = []
	var bench_info = {}
	
	if target_allies:
		if is_revive:
			_temp_item_targets.clear()
			for m in current_player_team:
				var is_dead = false
				if roster_hp_cache.has(m):
					var state = roster_hp_cache[m]
					var hp = state if typeof(state) == TYPE_INT else state.get("hp", 1)
					if typeof(hp) != TYPE_INT and typeof(hp) != TYPE_FLOAT: hp = 0
					if hp <= 0: is_dead = true
				if is_dead:
					_temp_item_targets.append(m)
			
			if _temp_item_targets.is_empty():
				log_event.emit("No valid targets for this item!")
				current_state = BattleState.ACTION_SELECTION
				selected_item_id = ""
				_show_item_menu()
				return
				
			battle_hud.move_container.visible = false
			battle_hud.show_revive_options(_temp_item_targets)
			log_event.emit("Select target for %s..." % data.name)
			return
		else:
			for i in range(active_player_monsters.size()):
				if active_player_monsters[i] and not active_player_monsters[i].is_dead:
					valid_targets.append(i)

	if valid_targets.is_empty() and bench_info.is_empty():
		log_event.emit("No valid targets for this item!")
		current_state = BattleState.ACTION_SELECTION
		selected_item_id = ""
		_show_item_menu()
		return
	
	battle_hud.move_container.visible = false
	battle_hud.set_targeting_mode(true, valid_targets, target_allies, bench_info)
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
		battle_hud.show_moves(moves, current_acting_unit.move_cooldowns)
	elif was_item:
		_show_item_menu()
	else:
		battle_hud.show_actions()
		
	log_event.emit("It's %s's turn!" % current_acting_unit.data.monster_name)

func _on_target_selected(index: int):
	if current_state != BattleState.TARGET_SELECTION: return
	
	# Handle Bench Target (Swap)
	if index >= 10:
		var bench_idx = index - 10
		battle_hud.set_targeting_mode(false)
		if battle_hud.move_container: battle_hud.move_container.visible = false
		
		if selected_item_id != "":
			var item_id = selected_item_id
			selected_item_id = ""
			_perform_item_on_data(current_acting_unit, _temp_item_targets[bench_idx], item_id)
			return
			
		_perform_bench_swap_move(current_acting_unit, bench_idx, selected_move)
		return
	
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

func _show_item_menu():
	var battle_items = {}
	for item_id in PlayerData.inventory:
		if CombatManager.get_item_data(item_id).has("target"):
			battle_items[item_id] = PlayerData.inventory[item_id]
			
	if battle_items.is_empty():
		log_event.emit("No battle items!")
		current_state = BattleState.ACTION_SELECTION
		if battle_hud: battle_hud.show_actions()
		return
		
	var disabled_items = []
	var has_dead_units = false
	for m in current_player_team:
		if m != null:
			var is_dead = false
			if roster_hp_cache.has(m):
				var state = roster_hp_cache[m]
				var hp = state if typeof(state) == TYPE_INT else state.get("hp", 1)
				if typeof(hp) != TYPE_INT and typeof(hp) != TYPE_FLOAT: hp = 0
				if hp <= 0: is_dead = true
			if is_dead:
				has_dead_units = true
				break
				
	if not has_dead_units: disabled_items.append("defibrillator")
	if battle_hud: battle_hud.call_deferred("show_items", battle_items, disabled_items)

func perform_swap(active_unit: BattleMonster, new_data: MonsterData, bench_index: int):
	current_state = BattleState.EXECUTING
	
	log_event.emit("%s retreats!" % active_unit.data.monster_name)
	await active_unit.play_move()
		
	await get_tree().create_timer(2.0).timeout
	
	# Swap data: Active goes to bench, Bench goes to active
	var active_idx = active_player_monsters.find(active_unit)
	benched_player_monsters[bench_index] = active_unit.data
	current_player_team[active_idx] = new_data
	current_player_team[bench_index + 3] = active_unit.data
	
	# Swap physical unit
	var marker = active_unit.get_parent()
	
	if active_idx == -1:
		push_error("BattleManager: Active unit not found in roster during swap!")
		return
	
	# Save state of retreating unit
	_strip_temporary_buffs(active_unit)
	roster_hp_cache[active_unit.data] = { "hp": active_unit.current_hp, "stats": active_unit.stats.duplicate(), "effects": active_unit.active_effects.duplicate(true), "meta": _get_persistent_meta(active_unit) }
	
	all_monsters.erase(active_unit)
	active_unit.queue_free()
	
	log_event.emit("Go! %s!" % new_data.monster_name)
		
	spawn_unit(new_data, marker, true, active_idx)
	
	# The new unit is the last added to active_player_monsters by spawn_unit
	var new_unit = active_player_monsters[active_idx]
	
	new_unit.atb_value = 0 # Start fresh
	new_unit.play_move() # Play enter animation
	
	_update_team_passives()
	_sync_roster_order()
	
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
				_check_shield_update(u)
				battle_hud.update_speed_bar(true, i, u.atb_value)
			
		for i in range(active_enemy_monsters.size()):
			var u = active_enemy_monsters[i]
			battle_hud.update_hp(false, i, u.current_hp, u.max_hp)
			_refresh_unit_status(u)
			_check_shield_update(u)
			battle_hud.update_speed_bar(false, i, u.atb_value)
	
	await get_tree().create_timer(1.5).timeout
	end_turn()

func perform_move(attacker: BattleMonster, defender: BattleMonster, move: MoveData):
	current_state = BattleState.EXECUTING
	var attacker_is_player = attacker.is_player
	
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
			
	# Singularity Hazard Check
	if attacker.has_status("singularity_hazard") and move.target_type == MoveData.TargetType.ENEMY:
		attacker.apply_effect({ "status": "poison", "duration": 3, "damage_percent": 0.1, "type": "status" })
		var spd_drop = int(attacker.stats.speed * 0.2)
		attacker.apply_effect({ "stat": "speed", "amount": -spd_drop, "duration": 1, "type": "stat_mod" })
		_refresh_unit_status(attacker)
		log_event.emit("%s is caught in the singularity!" % attacker.data.monster_name)
	
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
				
				var is_guarded = false
				if defender.has_status("guarded"):
					damage = 0
					is_guarded = true
					log_event.emit("Blocked by Octet!")
					result.effects.append({ "target": defender, "effect": "remove_status", "status": "guarded" })
				
				# Mirror Coat (Reflect 1 Hit)
				if not is_guarded and defender.has_status("mirror_coat") and damage > 0:
					var reflected = damage
					attacker.take_damage(reflected)
					_show_damage_number(attacker, reflected, "damage")
					log_event.emit("Reflected!")
					damage = 0
					result.effects.append({ "target": defender, "effect": "remove_status", "status": "mirror_coat" })
				
				# Reflective Shell (Reflect 30% of damage, Negate Hit)
				if not is_guarded and defender.has_status("reflective_shell") and damage > 0:
					var reflected = int(damage * 0.3)
					if reflected > 0:
						attacker.take_damage(reflected)
						_show_damage_number(attacker, reflected, "damage")
					log_event.emit("Shell Reflected!")
					damage = 0
					result.effects.append({ "target": defender, "effect": "remove_status", "status": "reflective_shell" })

				# Absorb Shield (Heal 30% of damage, Negate Hit)
				if not is_guarded and defender.has_status("absorb_shield") and damage > 0:
					var absorb_pct = 0.3
					for eff in defender.active_effects:
						if eff.get("status") == "absorb_shield":
							absorb_pct = eff.get("absorb_percent", 0.3)
							break
							
					var heal_amt = int(damage * absorb_pct)
					if heal_amt > 0:
						defender.heal(heal_amt)
						_show_damage_number(defender, heal_amt, "heal")
					log_event.emit("Absorbed!")
					damage = 0
					result.effects.append({ "target": defender, "effect": "remove_status", "status": "absorb_shield" })
				
				# Toxic Feedback Check
				if not is_guarded and defender.has_status("toxic_feedback") and damage > 0:
					var feedback_effect = null
					for eff in defender.active_effects:
						if eff.get("status") == "toxic_feedback":
							feedback_effect = eff
							break
					
					if feedback_effect:
						var debuff_stat = feedback_effect.get("debuff_stat", "attack")
						var debuff_amount = feedback_effect.get("debuff_amount", -40)
						var debuff_percent = feedback_effect.get("debuff_percent", true)
						var debuff_duration = feedback_effect.get("debuff_duration", 2)
						var effect_to_apply = { "type": "stat_mod", "stat": debuff_stat, "amount": debuff_amount, "percent": debuff_percent, "duration": debuff_duration }
						if effect_to_apply.get("percent", false):
							effect_to_apply["amount"] = int(attacker.stats.get(debuff_stat, 10) * (effect_to_apply.get("amount") / 100.0))
						attacker.apply_effect(effect_to_apply)
						_play_status_vfx(attacker, "toxic_feedback")
						_refresh_unit_status(attacker)
						log_event.emit("%s's %s was lowered by Toxic Feedback!" % [attacker.data.monster_name, debuff_stat.capitalize()])
						
				# Radiation Feedback Check
				if not is_guarded and defender.has_status("radiation_feedback") and damage > 0:
					attacker.apply_effect({ "status": "radiation", "duration": 3, "damage_percent": 0.05, "type": "status" })
					_play_status_vfx(attacker, "radiation")
					_refresh_unit_status(attacker)
					log_event.emit("%s is irradiated by the shell!" % attacker.data.monster_name)
				
				# Inertia Feedback Check
				if not is_guarded and defender.has_status("inertia_feedback") and damage > 0:
					var spd_drop = max(1, int(attacker.stats.get("speed", 10) * 0.2))
					attacker.apply_effect({ "stat": "speed", "amount": -spd_drop, "duration": 2, "type": "stat_mod" })
					_play_status_vfx(attacker, "inertia_feedback")
					_refresh_unit_status(attacker)
					log_event.emit("%s is slowed by Dense Inertia!" % attacker.data.monster_name)

				# Reflection Check
				if not is_guarded and defender.has_status("static_reflection") and move.target_type == MoveData.TargetType.ENEMY:
					var reflect_pct = 0.3
					# Check for custom reflection percent
					for eff in defender.active_effects:
						if eff.get("status") == "static_reflection":
							reflect_pct = eff.get("damage_percent", 0.3)
							break
					var reflect_dmg = int(damage * reflect_pct)
					reflect_dmg = _calculate_final_damage(attacker, reflect_dmg)
					if reflect_dmg > 0:
						attacker.take_damage(reflect_dmg)
						_show_damage_number(attacker, reflect_dmg, "damage")
						log_event.emit("Static discharge hits %s!" % attacker.data.monster_name)
						_check_shield_update(attacker)
				
				# Handle Multi-Hit
				var hits = move.hit_count
				var base_damage = damage
				var total_damage_dealt = 0
				
				for i in range(hits):
					if not is_instance_valid(defender) or defender.is_dead: break
					
					var current_hit_damage = base_damage
					var shield = defender.get_meta("shield", 0)
					
					if shield > 0:
						var absorbed = min(current_hit_damage, shield)
						shield -= absorbed
						current_hit_damage -= absorbed
						defender.set_meta("shield", shield)
						_check_shield_update(defender)
						
						if shield <= 0:
							var explosion = defender.get_meta("shield_explosion_dmg", 0)
							if explosion > 0 and is_instance_valid(attacker):
								attacker.take_damage(explosion)
								if is_instance_valid(attacker):
									_show_damage_number(attacker, explosion, "damage")
								log_event.emit("Shield shatters explosively!")
							if is_instance_valid(defender):
								defender.set_meta("shield_explosion_dmg", 0)
					
					if not is_instance_valid(defender): break
					current_hit_damage = _calculate_final_damage(defender, current_hit_damage)
					
					if current_hit_damage > 0:
						defender.take_damage(current_hit_damage)
						if is_instance_valid(defender):
							var dmg_type = "damage"
							if result.get("is_crit", false): dmg_type = "crit"
							if result.get("is_reaction", false): dmg_type = "reaction"
							_show_damage_number(defender, current_hit_damage, dmg_type)
						total_damage_dealt += current_hit_damage
						
					if i < hits - 1:
						await get_tree().create_timer(0.3).timeout
				
				if hits > 1:
					log_event.emit("Hit %d times! (%d total)" % [hits, total_damage_dealt])
				else:
					log_event.emit("Dealt %d damage!" % total_damage_dealt)
					
				await get_tree().create_timer(1.0).timeout
			
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
				if is_instance_valid(target):
					var amount = effect.get("amount", 0)
					if effect.get("is_crit"): _show_damage_number(target, 0, "crit") # Visual cue for crit
					var current = target.get_meta("shield", 0)
					target.set_meta("shield", current + amount)
					
					if effect.get("explode_on_break", false):
						target.set_meta("shield_explosion_dmg", amount)
						
					_check_shield_update(target)
					_play_status_vfx(target, "shield")
				continue
			
			if effect.get("effect") == "add_team_shield":
				var amount = effect.get("amount", 0)
				if effect.get("is_crit"): log_event.emit("Critical Shield!")
				var team = active_player_monsters if attacker.is_player else active_enemy_monsters
				for unit in team:
					if is_instance_valid(unit) and not unit.is_dead:
						var current = unit.get_meta("shield", 0)
						unit.set_meta("shield", current + amount)
						_check_shield_update(unit)
						_play_status_vfx(unit, "shield")
				log_event.emit("Team shielded!")
				continue
			
			if effect.get("effect") == "heal_overflow_shield":
				var target = effect.get("target")
				var amount = effect.get("amount", 0)
				if target and is_instance_valid(target):
					var missing = target.max_hp - target.current_hp
					var heal_val = min(amount, missing)
					var shield_val = max(0, amount - missing)
					var is_crit = effect.get("is_crit", false)
					
					if heal_val > 0:
						if target.has_status("heal_block"):
							log_event.emit("%s is blocked from healing!" % target.data.monster_name)
							shield_val += heal_val # Convert blocked heal entirely into shield
							heal_val = 0
						else:
							target.heal(heal_val)
							_show_damage_number(target, heal_val, "crit" if is_crit else "heal")
							
							# Mastery: Post-Transition (100% Stability) -> Heal deals damage
							if attacker.data.group == AtomicConfig.Group.POST_TRANSITION and attacker.data.stability >= 100:
								_apply_post_transition_mastery_damage(attacker, heal_val)
						
					if shield_val > 0:
						var current = target.get_meta("shield", 0)
						target.set_meta("shield", current + shield_val)
						_check_shield_update(target)
						_play_status_vfx(target, "shield")
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
							_play_status_vfx(unit, choice)
							log_event.emit("%s is affected by %s!" % [unit.data.monster_name, choice.capitalize()])
						
						_refresh_unit_status(unit)
				continue
			
			if effect.get("effect") == "cleanse":
				_handle_cleanse(effect)
				continue
			
			if effect.get("effect") == "swap_position":
				var target = effect.get("target")
				if is_instance_valid(target) and target != attacker:
					_swap_active_positions(attacker, target)
				continue
			
			if effect.get("effect") == "aoe_stat_mod":
				var targets = []
				if effect.get("target_team") == "ally":
					targets = active_player_monsters if attacker.is_player else active_enemy_monsters
				else:
					targets = active_enemy_monsters if attacker.is_player else active_player_monsters
				
				for unit in targets:
					if is_instance_valid(unit) and not unit.is_dead:
						var stat = effect.get("stat")
						var amount = effect.get("amount", 0)
						var duration = effect.get("duration", 2)
						var percent = effect.get("percent", false)
						var new_effect = { "target": unit, "stat": stat, "amount": amount, "duration": duration, "percent": percent, "type": "stat_mod" }
						
						# Resolve percent for each target
						if percent:
							new_effect["amount"] = int(unit.stats.get(stat, 10) * (amount / 100.0))
							
						unit.apply_effect(new_effect)
						_refresh_unit_status(unit)
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
			
			if effect.get("effect") == "percent_damage":
				var target = effect.get("target")
				var pct = effect.get("percent", 0.2)
				if is_instance_valid(target) and not target.is_dead:
					var dmg = int(target.max_hp * pct)
					dmg = _calculate_final_damage(target, dmg)
					if dmg > 0:
						target.take_damage(dmg)
						var is_crit = effect.get("is_crit", false)
						_show_damage_number(target, dmg, "crit" if is_crit else "damage")
						_check_shield_update(target)
				continue

			if effect.get("effect") == "steal_hp_team":
				var target = effect.get("target")
				var pct = effect.get("percent", 0.1)
				if is_instance_valid(target) and not target.is_dead:
					var dmg = int(target.max_hp * pct)
					dmg = _calculate_final_damage(target, dmg)
					if dmg > 0:
						target.take_damage(dmg)
						var is_crit = effect.get("is_crit", false)
						_show_damage_number(target, dmg, "crit" if is_crit else "damage")
						_check_shield_update(target)
						
						var team = active_player_monsters if attacker.is_player else active_enemy_monsters
						for unit in team:
							if is_instance_valid(unit) and not unit.is_dead:
								var actual_heal = min(dmg, unit.max_hp - unit.current_hp)
								if actual_heal > 0:
									if unit.has_status("heal_block"):
										pass # Cannot be healed
									else:
										unit.heal(actual_heal)
										_show_damage_number(unit, actual_heal, "heal")
										
										# Mastery: Post-Transition (100% Stability) -> Heal deals damage
										if attacker.data.group == AtomicConfig.Group.POST_TRANSITION and attacker.data.stability >= 100:
											_apply_post_transition_mastery_damage(attacker, actual_heal)
										_refresh_unit_status(unit)
						log_event.emit("HP stolen and shared with the team!")
				continue

			if effect.get("effect") == "team_heal":
				var amount = effect.get("amount", 0)
				if amount > 0:
					var team = active_player_monsters if attacker.is_player else active_enemy_monsters
					for unit in team:
						if is_instance_valid(unit) and not unit.is_dead:
							var actual_heal = min(amount, unit.max_hp - unit.current_hp)
							if actual_heal > 0:
								if unit.has_status("heal_block"):
									pass # Heal blocked
								else:
									unit.heal(actual_heal)
									_show_damage_number(unit, actual_heal, "heal")
									
									# Mastery: Post-Transition (100% Stability) -> Heal deals damage
									if attacker.data.group == AtomicConfig.Group.POST_TRANSITION and attacker.data.stability >= 100:
										_apply_post_transition_mastery_damage(attacker, actual_heal)
									_refresh_unit_status(unit)
									
					if effect.get("include_bench", false) and attacker.is_player:
						for m_data in benched_player_monsters:
							var max_hp = m_data.get_current_stats().max_hp
							var hp = max_hp
							if roster_hp_cache.has(m_data):
								var state = roster_hp_cache[m_data]
								if typeof(state) == TYPE_INT: hp = state
								elif typeof(state) == TYPE_DICTIONARY: hp = state.get("hp", max_hp)
								
							if hp > 0 and hp < max_hp:
								var actual_heal = min(amount, max_hp - hp)
								if actual_heal > 0:
									var new_hp = hp + actual_heal
									if typeof(roster_hp_cache.get(m_data)) == TYPE_INT:
										roster_hp_cache[m_data] = new_hp
									elif typeof(roster_hp_cache.get(m_data)) == TYPE_DICTIONARY:
										roster_hp_cache[m_data]["hp"] = new_hp
									else:
										roster_hp_cache[m_data] = {"hp": new_hp, "stats": {}}
									log_event.emit("%s (Benched) was healed!" % m_data.monster_name)
									if attacker.data.group == AtomicConfig.Group.POST_TRANSITION and attacker.data.stability >= 100:
										_apply_post_transition_mastery_damage(attacker, actual_heal)
										
					log_event.emit("Team healed!")
				continue
			
			if effect.get("effect") == "aoe_power_attack":
				var power = effect.get("power", 40)
				var targets = active_enemy_monsters if attacker.is_player else active_player_monsters
				for unit in targets:
					if is_instance_valid(unit) and not unit.is_dead:
						# Create a temporary move to reuse damage calc logic
						var temp_move = MoveData.new()
						temp_move.name = "AoE Burst"
						temp_move.power = power
						temp_move.type = move.type # Physical/Special
						
						var sub_result = CombatManager.execute_move(attacker, unit, temp_move)
						if sub_result.success:
							if sub_result.damage > 0:
								unit.take_damage(sub_result.damage)
								if is_instance_valid(unit):
									_show_damage_number(unit, sub_result.damage, "damage")
							
							for sub_effect in sub_result.effects:
								var sub_target = sub_effect.get("target")
								if is_instance_valid(sub_target) and not sub_target.is_dead:
									if sub_target.has_status("invulnerable") and sub_effect.get("type") in ["status", "stat_mod"]:
										continue
									sub_target.apply_effect(sub_effect)
									_refresh_unit_status(sub_target)
				log_event.emit("AoE Damage!")
				continue
				
			if effect.get("effect") == "splash_damage":
				var pct = effect.get("percent", 0.5)
				var splash_dmg = int(result.damage * pct)
				if splash_dmg > 0:
					var targets = active_enemy_monsters if attacker.is_player else active_player_monsters
					for unit in targets:
						if is_instance_valid(unit) and not unit.is_dead and (not is_instance_valid(defender) or unit != defender):
							unit.take_damage(splash_dmg)
							if is_instance_valid(unit):
								_show_damage_number(unit, splash_dmg, "damage")
					log_event.emit("Splash Damage!")
				continue
				
			if effect.get("effect") == "extend_debuffs":
				var amount = effect.get("amount", 1)
				var target = effect.get("target")
				if is_instance_valid(target) and "active_effects" in target:
					var count = 0
					for eff in target.active_effects:
						var is_debuff = false
						if eff.get("type") == "stat_mod" and eff.get("amount", 0) < 0:
							is_debuff = true
						elif eff.get("type") == "status":
							var s = str(eff.get("status", "")).to_lower()
							if eff.has("damage_multiplier") or s in ["poison", "stun", "silence_special", "marked_covalent", "vulnerable", "corrosion", "reactive_vapor", "radiation", "refracted", "insanity", "illuminated", "singularity_hazard"]:
								is_debuff = true
						
						if is_debuff and eff.has("duration"):
							eff["duration"] += amount
							count += 1
					if count > 0:
						log_event.emit("Debuffs extended!")
						_refresh_unit_status(target)
				continue
			
			if effect.get("effect") == "recoil":
				var target = effect.get("target")
				var amount = effect.get("amount", 0)
				if is_instance_valid(target):
					var final_amount = _calculate_final_damage(target, amount)
					if final_amount > 0:
						target.take_damage(final_amount)
						_show_damage_number(target, final_amount, "damage")
						log_event.emit("%s takes %d recoil damage!" % [target.data.monster_name, final_amount])
						_check_shield_update(target)
				continue
				
			if effect.get("effect") == "reset_cooldowns":
				var target = effect.get("target")
				if is_instance_valid(target) and "move_cooldowns" in target:
					target.move_cooldowns.clear()
					log_event.emit("%s's cooldowns were reset!" % target.data.monster_name)
				continue
				
			if effect.get("effect") == "swap_and_heal_lowest_ally":
				var amount = effect.get("amount", 0)
				var lowest_pct = 2.0 # Changed to 2.0 to catch 100% HP targets
				var lowest_unit = null
				var lowest_benched_idx = -1
				var lowest_benched_data = null
				
				var team = active_player_monsters if attacker_is_player else active_enemy_monsters
				for m in team:
					if is_instance_valid(m) and not m.is_dead and m != attacker:
						var pct = float(m.current_hp) / float(m.max_hp)
						if pct < lowest_pct:
							lowest_pct = pct
							lowest_unit = m
							lowest_benched_data = null # Clear if active is lower
				
				if attacker_is_player:
					for i in range(benched_player_monsters.size()):
						var m_data = benched_player_monsters[i]
						var max_hp = m_data.get_current_stats().max_hp
						var hp = max_hp
						if roster_hp_cache.has(m_data):
							var state = roster_hp_cache[m_data]
							if typeof(state) == TYPE_INT: hp = state
							elif typeof(state) == TYPE_DICTIONARY: hp = state.get("hp", max_hp)
						
						if hp > 0: # Ensures swap still occurs even if at 100% HP
							var pct = float(hp) / float(max_hp)
							if pct < lowest_pct:
								lowest_pct = pct
								lowest_unit = null
								lowest_benched_data = m_data
								lowest_benched_idx = i
								
				if lowest_unit:
					if amount > 0 and not lowest_unit.has_status("heal_block"):
						var actual_heal = min(amount, lowest_unit.max_hp - lowest_unit.current_hp)
						if actual_heal > 0:
							lowest_unit.heal(actual_heal)
							_show_damage_number(lowest_unit, actual_heal, "heal")
							log_event.emit("%s was healed!" % lowest_unit.data.monster_name)
							if attacker.data.group == AtomicConfig.Group.POST_TRANSITION and attacker.data.stability >= 100:
								_apply_post_transition_mastery_damage(attacker, actual_heal)
					_swap_active_positions(attacker, lowest_unit)
				elif lowest_benched_data:
					if amount > 0:
						var max_hp_val = lowest_benched_data.get_current_stats().max_hp
						var hp_val = max_hp_val
						if roster_hp_cache.has(lowest_benched_data):
							var state = roster_hp_cache[lowest_benched_data]
							if typeof(state) == TYPE_INT: hp_val = state
							elif typeof(state) == TYPE_DICTIONARY: hp_val = state.get("hp", max_hp_val)
							
						var actual_heal_val = min(amount, max_hp_val - hp_val)
						if actual_heal_val > 0:
							var new_hp_val = hp_val + actual_heal_val
							if typeof(roster_hp_cache.get(lowest_benched_data)) == TYPE_INT:
								roster_hp_cache[lowest_benched_data] = new_hp_val
							elif typeof(roster_hp_cache.get(lowest_benched_data)) == TYPE_DICTIONARY:
								roster_hp_cache[lowest_benched_data]["hp"] = new_hp_val
							else:
								roster_hp_cache[lowest_benched_data] = {"hp": new_hp_val, "stats": {}}
							log_event.emit("%s (Benched) was healed!" % lowest_benched_data.monster_name)
							
					var active_idx = active_player_monsters.find(attacker)
					benched_player_monsters[lowest_benched_idx] = attacker.data
					current_player_team[active_idx] = lowest_benched_data
					current_player_team[lowest_benched_idx + 3] = attacker.data
					
					_strip_temporary_buffs(attacker)
					roster_hp_cache[attacker.data] = { "hp": attacker.current_hp, "stats": attacker.stats.duplicate(), "effects": attacker.active_effects.duplicate(true), "meta": _get_persistent_meta(attacker) }
					
					var marker = attacker.get_parent()
					all_monsters.erase(attacker)
					attacker.queue_free()
					
					spawn_unit(lowest_benched_data, marker, true, active_idx)
					var new_unit = active_player_monsters[active_idx]
					new_unit.atb_value = 0
					new_unit.play_move()
					
					_update_team_passives()
					_refresh_team_ui(true)
					log_event.emit("%s swaps in!" % lowest_benched_data.monster_name)
				continue
				
			if effect.get("effect") == "heal_lowest_ally":
				var amount = effect.get("amount", 0)
				if amount > 0:
					var lowest_pct = 2.0 # Changed to 2.0 to catch 100% HP targets
					var lowest_unit = null
					var lowest_benched_data = null
					
					var team = active_player_monsters if attacker.is_player else active_enemy_monsters
					for m in team:
						if is_instance_valid(m) and not m.is_dead:
							var pct = float(m.current_hp) / float(m.max_hp)
							if pct < lowest_pct:
								lowest_pct = pct
								lowest_unit = m
								lowest_benched_data = null # Clear if active is lower
					
					if attacker.is_player:
						for m_data in benched_player_monsters:
							var max_hp = m_data.get_current_stats().max_hp
							var hp = max_hp
							if roster_hp_cache.has(m_data):
								var state = roster_hp_cache[m_data]
								if typeof(state) == TYPE_INT: hp = state
								elif typeof(state) == TYPE_DICTIONARY: hp = state.get("hp", max_hp)
							
							if hp > 0:
								var pct = float(hp) / float(max_hp)
								if pct < lowest_pct:
									lowest_pct = pct
									lowest_unit = null
									lowest_benched_data = m_data
									
					if lowest_unit:
						if not lowest_unit.has_status("heal_block"):
							var actual_heal = min(amount, lowest_unit.max_hp - lowest_unit.current_hp)
							if actual_heal > 0:
								lowest_unit.heal(actual_heal)
								_show_damage_number(lowest_unit, actual_heal, "heal")
								log_event.emit("%s was healed!" % lowest_unit.data.monster_name)
								if attacker.data.group == AtomicConfig.Group.POST_TRANSITION and attacker.data.stability >= 100:
									_apply_post_transition_mastery_damage(attacker, actual_heal)
								_refresh_unit_status(lowest_unit)
					elif lowest_benched_data:
						var max_hp = lowest_benched_data.get_current_stats().max_hp
						var hp = max_hp
						if roster_hp_cache.has(lowest_benched_data):
							var state = roster_hp_cache[lowest_benched_data]
							if typeof(state) == TYPE_INT: hp = state
							elif typeof(state) == TYPE_DICTIONARY: hp = state.get("hp", max_hp)
							
						var actual_heal = min(amount, max_hp - hp)
						if actual_heal > 0:
							var new_hp = hp + actual_heal
							if typeof(roster_hp_cache.get(lowest_benched_data)) == TYPE_INT:
								roster_hp_cache[lowest_benched_data] = new_hp
							elif typeof(roster_hp_cache.get(lowest_benched_data)) == TYPE_DICTIONARY:
								roster_hp_cache[lowest_benched_data]["hp"] = new_hp
							else:
								roster_hp_cache[lowest_benched_data] = {"hp": new_hp, "stats": {}}
							log_event.emit("%s (Benched) was healed!" % lowest_benched_data.monster_name)
							if attacker.data.group == AtomicConfig.Group.POST_TRANSITION and attacker.data.stability >= 100:
								_apply_post_transition_mastery_damage(attacker, actual_heal)
				continue
				
			var target_unit = effect.get("target")

			if effect.get("effect") == "cleanse_buffs":
				var target = effect.get("target")
				if is_instance_valid(target) and "active_effects" in target:
					var cleaned_count = 0
					for i in range(target.active_effects.size() - 1, -1, -1):
						var eff = target.active_effects[i]
						var is_buff = false
						if eff.get("type") == "stat_mod" and eff.get("amount", 0) > 0:
							is_buff = true
						elif eff.get("type") == "status":
							var s = str(eff.get("status", "")).to_lower()
							if s in ["invulnerable", "taunt", "static_reflection", "physical_resist", "mirror_coat", "toxic_feedback", "radiation_feedback", "reflective_shell", "absorb_shield", "special_resist", "regeneration"]:
								is_buff = true
						if is_buff:
							if eff.get("type") == "stat_mod":
								var stat = eff.get("stat")
								var amount = eff.get("amount", 0)
								if target.stats.has(stat): target.stats[stat] -= amount
							target.active_effects.remove_at(i)
							cleaned_count += 1
					if cleaned_count > 0:
						log_event.emit("Removed %d buff(s) from %s!" % [cleaned_count, target.data.monster_name])
						_refresh_unit_status(target)
				continue

			if effect.get("effect") == "execute":
				var target = effect.get("target")
				var threshold = effect.get("threshold", 0.15)
				if is_instance_valid(target) and not target.is_dead:
					var threshold_hp = int(target.max_hp * threshold)
					if target.current_hp <= threshold_hp:
						target.take_damage(target.current_hp)
						_show_damage_number(target, target.current_hp, "crit")
						log_event.emit("%s was executed!" % target.data.monster_name)
						_check_shield_update(target)
				continue

			if effect.get("effect") == "random_multi_hit":
				var hits = effect.get("hits", 2)
				var power = effect.get("power", 20)
				var enemies = active_enemy_monsters if attacker.is_player else active_player_monsters
				for i in range(hits):
					var living = enemies.filter(func(m): return is_instance_valid(m) and not m.is_dead)
					if not living.is_empty():
						var target = living.pick_random()
						var temp_move = MoveData.new()
						temp_move.name = "Random Hit"
						temp_move.power = power
						temp_move.type = move.type
						
						var sub_result = CombatManager.execute_move(attacker, target, temp_move)
						if sub_result.success and sub_result.damage > 0:
							target.take_damage(sub_result.damage)
							if is_instance_valid(target):
								_show_damage_number(target, sub_result.damage, "damage")
							
							for sub_effect in sub_result.effects:
								var sub_target = sub_effect.get("target")
								if is_instance_valid(sub_target) and not sub_target.is_dead:
									if sub_target.has_status("invulnerable") and sub_effect.get("type") in ["status", "stat_mod"]:
										continue
									sub_target.apply_effect(sub_effect)
									_refresh_unit_status(sub_target)
						await get_tree().create_timer(0.3).timeout
				continue
			
			# Check Invulnerability for negative effects
			if is_instance_valid(target_unit) and target_unit.has_status("invulnerable"):
				var is_harmful = false
				if effect.get("type") == "status":
					var s = effect.get("status")
					if s in ["poison", "stun", "silence_special", "marked_covalent", "vulnerable", "corrosion", "reactive_vapor", "insanity", "singularity_hazard", "chain_reaction_mark"]:
						is_harmful = true
				elif effect.get("type") == "stat_mod" and effect.get("amount", 0) < 0:
					is_harmful = true
				elif effect.get("effect") == "swap_stats":
					is_harmful = true
				
				if is_harmful:
					log_event.emit("%s blocked the effect!" % target_unit.data.monster_name)
					continue
			
			if is_instance_valid(target_unit):
				# Check heal block for basic heal
				if effect.get("effect") == "heal":
					var amount = effect.get("amount", 0)
					if amount > 0 and target_unit.has_status("heal_block"):
						log_event.emit("%s is blocked from healing!" % target_unit.data.monster_name)
						effect["amount"] = 0 # Nullify heal
						
					var actual_heal = min(effect.get("amount", 0), target_unit.max_hp - target_unit.current_hp)
					if actual_heal > 0 and attacker.data.group == AtomicConfig.Group.POST_TRANSITION and attacker.data.stability >= 100:
						_apply_post_transition_mastery_damage(attacker, actual_heal)

				target_unit.apply_effect(effect)
				_refresh_unit_status(target_unit)
				
				# Play visual effects for statuses applied successfully
				if effect.get("type") == "status":
					_play_status_vfx(target_unit, effect.get("status"))
				
				if effect.get("effect") == "heal" and effect.get("amount", 0) > 0:
					var is_crit = effect.get("is_crit", false)
					_show_damage_number(target_unit, effect.get("amount"), "crit" if is_crit else "heal")
				
		# Handle Chain Reaction (Nonmetal Passive)
		for effect in result.effects:
			if effect.get("effect") == "chain_reaction":
				var enemies = active_enemy_monsters if attacker_is_player else active_player_monsters
				var living = []
				for m in enemies:
					if is_instance_valid(m) and not m.is_dead and (not is_instance_valid(defender) or m != defender):
						living.append(m)
				
				if not living.is_empty():
					var secondary = living.pick_random()
					var start_pos = defender.global_position if is_instance_valid(defender) else (attacker.global_position if is_instance_valid(attacker) else Vector2.ZERO)
					_play_chain_reaction_effect(start_pos, secondary.global_position)
					secondary.take_damage(int(effect.amount * 0.5)) # 50% damage to secondary
					if is_instance_valid(secondary):
						_show_damage_number(secondary, int(effect.amount * 0.5), "damage")
					log_event.emit("Chain Reaction hits %s!" % secondary.data.monster_name)
					
					# Mastery: Copy Status Effects
					if effect.get("copy_status", false):
						for other_effect in result.effects:
							var eff_target = other_effect.get("target")
							var is_primary_target = false
							if is_instance_valid(defender):
								is_primary_target = (eff_target == defender)
							else:
								is_primary_target = (not is_instance_valid(eff_target))
							
							if other_effect.get("type") == "status" and is_primary_target:
								var new_status = other_effect.duplicate()
								new_status["target"] = secondary
								if is_instance_valid(secondary):
									secondary.apply_effect(new_status)
									_refresh_unit_status(secondary)
									_play_status_vfx(secondary, new_status.get("status", ""))
								log_event.emit("Status spreads to %s!" % secondary.data.monster_name)
	
	# Wait for animation/text
	if move.cooldown > 1 and is_instance_valid(attacker):
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
	elif data.get("effect") == "cleanse_debuffs":
		log_event.emit("%s's debuffs were cleansed!" % target.data.monster_name)
		_play_status_vfx(target, "shield")
	
	CombatManager.apply_item_effect(target, item_id)
	PlayerData.consume_item(item_id, 1)
	_check_shield_update(target)
	
	if data.get("effect") == "add_shield":
		_play_status_vfx(target, "shield")
	
	if TutorialManager and PlayerData.tutorial_step == TutorialManager.Step.EXPLAIN_TARGETING:
		TutorialManager.advance_step() # To INSPECT_ENEMY
		
	await get_tree().create_timer(2.0).timeout
	end_turn()

func _perform_item_on_data(user: BattleMonster, m_data: MonsterData, item_id: String):
	current_state = BattleState.EXECUTING
	var data = CombatManager.get_item_data(item_id)
	var item_name = data.get("name", "Item")
	
	log_event.emit("%s used %s on %s!" % [user.data.monster_name, item_name, m_data.monster_name])
	await user.play_move()
	
	if data.get("effect") == "revive":
		var max_hp = m_data.get_current_stats().max_hp
		var heal_amt = int(max_hp * data.get("amount", 0.5))
		
		if roster_hp_cache.has(m_data):
			var state = roster_hp_cache[m_data]
			if typeof(state) == TYPE_INT:
				roster_hp_cache[m_data] = heal_amt
			elif typeof(state) == TYPE_DICTIONARY:
				roster_hp_cache[m_data]["hp"] = heal_amt
		else:
			roster_hp_cache[m_data] = { "hp": heal_amt, "stats": {} }
			
		log_event.emit("%s was revived!" % m_data.monster_name)
		
		var empty_active_idx = -1
		for i in range(3):
			if i < active_player_monsters.size() and active_player_monsters[i] == null:
				empty_active_idx = i
				break
				
		var team_idx = current_player_team.find(m_data)
		
		# If unit is in the bench but there's an open active slot, swap it in
		if team_idx >= 3 and empty_active_idx != -1:
			var old_active_data = current_player_team[empty_active_idx]
			current_player_team[empty_active_idx] = m_data
			current_player_team[team_idx] = old_active_data
			
			var bench_idx = benched_player_monsters.find(m_data)
			if bench_idx != -1:
				if old_active_data != null:
					benched_player_monsters[bench_idx] = old_active_data
				else:
					benched_player_monsters.remove_at(bench_idx)
					
			team_idx = empty_active_idx
			_sync_roster_order()
			log_event.emit("%s steps up to the front!" % m_data.monster_name)
			
		if team_idx != -1 and team_idx < 3:
			if active_player_monsters[team_idx] == null:
				var s_idx = SPAWN_MAP[team_idx] if SPAWN_MAP.size() > team_idx else team_idx
				if s_idx < player_spawn_points.size():
					var marker = player_spawn_points[s_idx]
					spawn_unit(m_data, marker, true, team_idx)
					var revived_unit = active_player_monsters[team_idx]
					if revived_unit:
						revived_unit.atb_value = 0
						revived_unit.play_move()
					_update_team_passives()
					_refresh_team_ui(true)
		
	PlayerData.consume_item(item_id, 1)
	
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

func _on_battle_hud_finished():
	var next_scene = "main_menu"
	if CampaignManager and CampaignManager.is_rogue_run:
		# Check if we should go to rest site
		if CampaignManager.current_run_energy > 0 and CampaignManager.current_run_wave <= CampaignManager.max_run_waves:
			next_scene = "rest_site"
			
	GlobalManager.switch_scene(next_scene)

func _on_monster_death(dead_unit: BattleMonster):
	# Death animation is handled in BattleMonster.die(), so we just check win condition
	
	var death_bomb_effect = null
	if "active_effects" in dead_unit:
		for eff in dead_unit.active_effects:
			if eff.get("status") == "death_bomb":
				death_bomb_effect = eff
				break
	
	if death_bomb_effect:
		var pct = death_bomb_effect.get("damage_percent", 0.2)
		var dmg = int(dead_unit.max_hp * pct)
		log_event.emit("%s explodes violently!" % dead_unit.data.monster_name)
		
		var explosion = CPUParticles2D.new()
		explosion.emitting = false
		explosion.one_shot = true
		explosion.amount = 60
		explosion.lifetime = 0.8
		explosion.explosiveness = 1.0
		explosion.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		explosion.emission_sphere_radius = 20.0
		explosion.spread = 180.0
		explosion.initial_velocity_min = 200.0
		explosion.initial_velocity_max = 400.0
		explosion.scale_amount_min = 10.0
		explosion.scale_amount_max = 20.0
		explosion.color = Color("#ff4500")
		
		var parent = dead_unit.get_parent()
		if parent:
			parent.add_child(explosion)
			explosion.global_position = dead_unit.global_position + Vector2(0, -50)
			explosion.restart()
			get_tree().create_timer(1.0).timeout.connect(explosion.queue_free)
			
		_shake_screen(0.5, 20.0)
			
		var targets = active_player_monsters if dead_unit.is_player else active_enemy_monsters # Damage its own team
		for unit in targets:
			if unit and not unit.is_dead and unit != dead_unit:
				unit.take_damage(dmg)
				_show_damage_number(unit, dmg, "damage")
				_check_shield_update(unit)
	
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
		# Emphasize the loss with a screen shake and red flash
		_shake_screen(0.5, 25.0)
		
		var flash = ColorRect.new()
		flash.color = Color(1.0, 0.0, 0.0, 0.5)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash.z_index = 400 # High enough to cover UI
		
		if battle_hud:
			battle_hud.add_child(flash)
		else:
			add_child(flash)
			
		var tween = create_tween()
		tween.tween_property(flash, "color:a", 0.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_callback(flash.queue_free)

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
	var shield = unit.get_meta("shield", 0)
	
	# Sync shield to status effect so it shows in UI
	if "active_effects" in unit:
		var found = false
		for i in range(unit.active_effects.size() - 1, -1, -1):
			var eff = unit.active_effects[i]
			if eff.get("status") == "shield":
				if shield <= 0:
					unit.active_effects.remove_at(i)
				else:
					eff["amount"] = shield
				found = true
				break
		
		if not found and shield > 0:
			unit.active_effects.append({ "status": "shield", "amount": shield, "type": "status", "duration": 99 })
			
	var index = active_player_monsters.find(unit) if unit.is_player else active_enemy_monsters.find(unit)
	if index != -1:
		# We pass max_hp so the bar can scale correctly relative to health
		hud_update_shield.emit(unit.is_player, index, shield, unit.max_hp)
		hud_update_status.emit(unit.is_player, index, unit.active_effects)

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
	# Clean up legacy nonmetal passives from old saves to prevent bugs
	var all_units = active_player_monsters + active_enemy_monsters
	for u in all_units:
		if u and "active_effects" in u:
			for i in range(u.active_effects.size() - 1, -1, -1):
				var effect = u.active_effects[i]
				if effect.get("source") == "nonmetal_passive":
					if u.stats.has(effect.get("stat")):
						u.stats[effect.get("stat")] -= effect.get("amount", 0)
					u.active_effects.remove_at(i)

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
			if unit.has_status("heal_block"):
				log_event.emit("%s's passive healing is blocked!" % unit.data.monster_name)
			else:
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
						_play_status_vfx(target, "radiation")
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
	var spawn_points = player_spawn_points if is_player else enemy_spawn_points
	
	if is_player:
		var front_count = min(3, current_player_team.size())
		var front_data = current_player_team.slice(0, front_count)
		front_data.shuffle()
		
		var new_active = [null, null, null]
		for i in range(front_count):
			current_player_team[i] = front_data[i]
			for u in active_player_monsters:
				if u and u.data == front_data[i]:
					new_active[i] = u
					break
		active_player_monsters = new_active
		_sync_roster_order()
	else:
		active_enemy_monsters.shuffle()
	
	var team = active_player_monsters if is_player else active_enemy_monsters
	
	for i in range(team.size()):
		var unit = team[i]
		if unit == null: continue
		var spawn_idx = i
		if i < 3 and spawn_points.size() >= 3:
			spawn_idx = SPAWN_MAP[i]
			
		if spawn_idx < spawn_points.size():
			var marker = spawn_points[spawn_idx]
			# Reparent to the new marker
			if unit.get_parent() != marker:
				unit.get_parent().remove_child(unit)
				marker.add_child(unit)
				unit.position = Vector2.ZERO
				
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

func _perform_bench_swap_move(attacker: BattleMonster, bench_index: int, move: MoveData):
	current_state = BattleState.EXECUTING
	var new_monster_data = benched_player_monsters[bench_index]
	
	log_event.emit("%s uses %s to switch with %s!" % [attacker.data.monster_name, move.name, new_monster_data.monster_name])
	await attacker.play_move()
	
	# Swap Data
	var active_idx = active_player_monsters.find(attacker)
	benched_player_monsters[bench_index] = attacker.data
	current_player_team[active_idx] = new_monster_data
	current_player_team[bench_index + 3] = attacker.data
	
	# Save Attacker State
	_strip_temporary_buffs(attacker)
	roster_hp_cache[attacker.data] = { "hp": attacker.current_hp, "stats": attacker.stats.duplicate(), "effects": attacker.active_effects.duplicate(true), "meta": _get_persistent_meta(attacker) }
	
	# Swap Visuals
	var marker = attacker.get_parent()
	all_monsters.erase(attacker)
	attacker.queue_free()
	
	spawn_unit(new_monster_data, marker, true, active_idx)
	var new_unit = active_player_monsters[active_idx]
	new_unit.atb_value = 0
	new_unit.play_move()
	
	_update_team_passives()
	_sync_roster_order()
	
	# Apply Move Effects to Incoming Unit
	for effect_def in move.effects:
		if effect_def.get("effect") == "swap_position": continue
		
		var effect = effect_def.duplicate()
		effect["target"] = new_unit
		
		# Resolve relative values
		if effect.get("type") == "stat_mod" and effect.get("percent", false):
			var stat_name = effect.get("stat")
			var base_val = new_unit.stats.get(stat_name, 10)
			effect["amount"] = int(base_val * (effect.get("amount") / 100.0))
			
		new_unit.apply_effect(effect)
		
		if effect.get("type") == "stat_mod":
			var v = "rose" if effect.get("amount") > 0 else "fell"
			log_event.emit("%s's %s %s!" % [new_unit.data.monster_name, effect.get("stat").capitalize(), v])

	# Refresh HUD
	if battle_hud:
		var player_data_list = []
		for u in active_player_monsters: 
			if u: player_data_list.append(u.data)
			else: player_data_list.append(null)
		var enemy_data_list = []
		for u in active_enemy_monsters: enemy_data_list.append(u.data)
		battle_hud.setup_ui(player_data_list, enemy_data_list)
		
		for i in range(active_player_monsters.size()):
			var u = active_player_monsters[i]
			if u:
				hud_update_hp.emit(true, i, u.current_hp, u.max_hp)
				hud_update_atb.emit(true, i, u.atb_value)
				_refresh_unit_status(u)
				_check_shield_update(u)
		for i in range(active_enemy_monsters.size()):
			var u = active_enemy_monsters[i]
			hud_update_hp.emit(false, i, u.current_hp, u.max_hp)
			_refresh_unit_status(u)
			_check_shield_update(u)
	
	await get_tree().create_timer(1.5).timeout
	end_turn()

func _swap_active_positions(unit1: BattleMonster, unit2: BattleMonster):
	var is_player = unit1.is_player
	if unit1.is_player != unit2.is_player: return
	
	var team = active_player_monsters if is_player else active_enemy_monsters
	var spawn_points = player_spawn_points if is_player else enemy_spawn_points
	
	var idx1 = team.find(unit1)
	var idx2 = team.find(unit2)
	
	if idx1 == -1 or idx2 == -1: return
	
	# Swap in array
	team[idx1] = unit2
	team[idx2] = unit1
	
	if is_player:
		var temp = current_player_team[idx1]
		current_player_team[idx1] = current_player_team[idx2]
		current_player_team[idx2] = temp
		_sync_roster_order()
	
	for i in [idx1, idx2]:
		var unit = team[i]
		if unit == null: continue
		var spawn_idx = i
		if i < 3 and spawn_points.size() >= 3:
			spawn_idx = SPAWN_MAP[i]
			
		if spawn_idx < spawn_points.size():
			var marker = spawn_points[spawn_idx]
			if unit.get_parent() != marker:
				unit.get_parent().remove_child(unit)
				marker.add_child(unit)
				unit.position = Vector2.ZERO
	
	log_event.emit("Positions swapped!")
	
	_refresh_team_ui(is_player)

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

func _refresh_team_ui(is_player: bool):
	if not battle_hud: return
	
	var player_data = []
	for u in active_player_monsters: 
		if u: player_data.append(u.data)
		else: player_data.append(null)
	var enemy_data = []
	for u in active_enemy_monsters: enemy_data.append(u.data)
	
	battle_hud.setup_ui(player_data, enemy_data)
	
	var team = active_player_monsters if is_player else active_enemy_monsters
	for i in range(team.size()):
		var u = team[i]
		if u:
			hud_update_hp.emit(is_player, i, u.current_hp, u.max_hp)
			hud_update_atb.emit(is_player, i, u.atb_value)
			_refresh_unit_status(u)
			_check_shield_update(u)

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

func _handle_cleanse(effect_data: Dictionary):
	var unit = effect_data.get("target")
	if not is_instance_valid(unit) or not "active_effects" in unit: return
	
	var cleanse_amount = effect_data.get("amount", 99) # Default to a high number to cleanse all
	var effects = unit.active_effects
	var cleaned_count = 0
	
	# Iterate backwards to safely remove
	for i in range(effects.size() - 1, -1, -1):
		if cleaned_count >= cleanse_amount: break
		
		var effect = effects[i]
		var is_debuff = false
		
		if effect.get("type") == "stat_mod":
			if effect.get("amount", 0) < 0:
				is_debuff = true
		elif effect.has("status"):
			var s = effect.get("status")
			# Check for known debuff names or if it's a damage multiplier debuff
			if effect.has("damage_multiplier") or s in ["poison", "stun", "silence_special", "vulnerable", "corrosion", "radiation", "refracted", "insanity", "singularity_hazard", "reactive_vapor", "chain_reaction_mark"]:
				is_debuff = true
		elif effect.get("type") == "swap_stats":
			is_debuff = true
		
		if is_debuff:
			cleaned_count += 1
			
			# Revert Stat Mods immediately
			if effect.get("type") == "stat_mod":
				var stat = effect.get("stat")
				var amount = effect.get("amount", 0)
				if unit.stats.has(stat): unit.stats[stat] -= amount
			
			# Revert Swap Stats immediately
			if effect.get("type") == "swap_stats":
				var stats_swapped = effect.get("stats", [])
				if stats_swapped.size() == 2:
					var s1 = stats_swapped[0]; var s2 = stats_swapped[1]
					var v1 = unit.stats.get(s1, 0); var v2 = unit.stats.get(s2, 0)
					unit.stats[s1] = v2; unit.stats[s2] = v1
			
			unit.active_effects.remove_at(i)
	
	if cleaned_count > 0:
		log_event.emit("Cleansed %d debuff(s) from %s!" % [cleaned_count, unit.data.monster_name])
		_refresh_unit_status(unit)
	else:
		log_event.emit("%s is already stable." % unit.data.monster_name)

func _get_persistent_meta(unit: BattleMonster) -> Dictionary:
	var meta_to_save = {}
	var all_meta = unit.get_meta_list()
	for key in all_meta:
		if key.begins_with("persist_") or key in ["shield", "shield_explosion_dmg", "full_set_crit_used", "full_set_immune_used", "consecutive_attacks"]:
			meta_to_save[key] = unit.get_meta(key)
	return meta_to_save

func _force_bench_dead_unit(unit: BattleMonster):
	log_event.emit("%s retreats to the bench!" % unit.data.monster_name)
	
	var index = active_player_monsters.find(unit)
	if index != -1:
		active_player_monsters[index] = null
	
	# Save state
	_strip_temporary_buffs(unit)
	roster_hp_cache[unit.data] = { "hp": 0, "stats": unit.stats.duplicate(), "effects": [], "meta": _get_persistent_meta(unit) }
	
	all_monsters.erase(unit)
	unit.queue_free()
	
	_sync_roster_order()
	
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
				_check_shield_update(u)

func _handle_swap_stats(effect: Dictionary):
	var target = effect.get("target")
	if not is_instance_valid(target): return
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
	if not is_instance_valid(unit) or not status_name: return
	
	if "active_effects" in unit:
		var effects = unit.active_effects
		for i in range(effects.size() - 1, -1, -1):
			if effects[i].get("status") == status_name:
				effects.remove_at(i)
		_refresh_unit_status(unit)

func _handle_team_status(attacker: BattleMonster, effect: Dictionary):
	var targets = []
	var target_team = effect.get("target_team", "enemy")
	
	if target_team == "ally":
		targets = active_player_monsters if attacker.is_player else active_enemy_monsters
	else:
		targets = active_enemy_monsters if attacker.is_player else active_player_monsters
	
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
			if effect.has("reduction_amount"): new_effect["reduction_amount"] = effect.get("reduction_amount")
			
			unit.apply_effect(new_effect)
			_refresh_unit_status(unit)
			_play_status_vfx(unit, status_name)
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
			if s == "reactive_vapor" or s == "poison" or s == "singularity_hazard":
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

func _process_status_heal(unit: BattleMonster):
	if unit.is_dead: return
	
	var total_heal = 0
	if "active_effects" in unit:
		for effect in unit.active_effects:
			if str(effect.get("status", "")).to_lower() == "regeneration":
				var amount = 0
				var pct = float(effect.get("heal_percent", 0.0))
				if pct > 0:
					amount = int(unit.max_hp * pct)
				else:
					amount = int(effect.get("amount", 0))
				
				if amount > 0:
					total_heal += amount
	
	if total_heal > 0:
		if unit.has_status("heal_block"):
			log_event.emit("%s's regeneration is blocked!" % unit.data.monster_name)
		else:
			unit.heal(total_heal)
			_show_damage_number(unit, total_heal, "heal")
			log_event.emit("%s regenerates health!" % unit.data.monster_name)

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
		"reaction":
			color = Color("#60fafc") # Cyan
			scale_factor = 1.4
			
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

func _shake_screen(duration: float, intensity: float):
	var target = null
	var camera = get_viewport().get_camera_2d()
	if camera:
		target = camera
	elif player_spawn_points.size() > 0:
		target = player_spawn_points[0].get_parent()
		
	if target and "position" in target:
		var original_pos = target.position
		var tween = create_tween()
		var steps = int(duration / 0.05)
		for i in range(steps):
			var offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
			tween.tween_property(target, "position", original_pos + offset, 0.05)
		tween.tween_property(target, "position", original_pos, 0.05)

func _play_status_vfx(unit: Node2D, status: String):
	if not is_instance_valid(unit): return
	var s = status.to_lower()
	
	# 1. Bubbles / Acid (Poison, Corrosion, Singularity)
	if s in ["poison", "corrosion", "toxic_feedback", "singularity_hazard"]:
		var particles = CPUParticles2D.new()
		particles.amount = 15
		particles.lifetime = 1.0
		particles.one_shot = true
		particles.explosiveness = 0.8
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		particles.emission_sphere_radius = 40.0
		particles.gravity = Vector2(0, -100) # Float up rapidly
		particles.scale_amount_min = 4.0
		particles.scale_amount_max = 12.0
		particles.color = Color("#802680") if s == "poison" else Color("#6dc000")
		if s == "singularity_hazard": particles.color = Color("#4b0082")
		
		unit.add_child(particles)
		get_tree().create_timer(1.5).timeout.connect(particles.queue_free)
		
		if s == "corrosion":
			var tween = create_tween()
			var base_mod = unit.modulate
			for i in range(5):
				tween.tween_property(unit, "modulate", Color(0.6, 1.0, 0.4), 0.05)
				tween.tween_property(unit, "modulate", base_mod, 0.05)
			tween.tween_property(unit, "modulate", Color.WHITE, 0.05)
		
	# 2. Glowing Shields (Invulnerable, Reflect, Guards)
	elif s in ["shield", "invulnerable", "guarded", "static_reflection", "mirror_coat", "reflective_shell", "absorb_shield", "physical_resist", "special_resist", "inertia_feedback"]:
		var ring = Line2D.new()
		var points = []
		var segments = 32
		var radius = 90.0
		for i in range(segments + 1):
			var angle = (float(i) / segments) * TAU
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		ring.points = points
		ring.width = 8.0
		ring.default_color = Color("#ffd700") # Default Gold
		if s in ["mirror_coat", "reflective_shell", "inertia_feedback"]: ring.default_color = Color("#e0e0e0")
		elif s in ["shield", "static_reflection", "guarded"]: ring.default_color = Color("#60fafc")
		elif s in ["absorb_shield", "physical_resist"]: ring.default_color = Color("#2ecc71")
		
		unit.add_child(ring)
		ring.position = Vector2(0, -40)
		ring.scale = Vector2(0.1, 0.1)
		
		var tween = create_tween()
		tween.tween_property(ring, "scale", Vector2(1.2, 1.2), 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(ring, "width", 2.0, 0.8)
		tween.tween_property(ring, "modulate:a", 0.0, 0.9)
		tween.tween_callback(ring.queue_free)
		
	# 3. Erratic Sparks (Radiation, Unstable, Overload, Explosive)
	elif s in ["radiation", "radiation_feedback", "unstable", "volatile", "overload", "explosive", "death_bomb"]:
		var particles = CPUParticles2D.new()
		particles.amount = 30
		particles.lifetime = 0.6
		particles.one_shot = true
		particles.explosiveness = 1.0
		particles.spread = 180.0
		particles.initial_velocity_min = 100.0
		particles.initial_velocity_max = 200.0
		particles.gravity = Vector2(0, 0)
		particles.scale_amount_min = 3.0
		particles.scale_amount_max = 6.0
		
		if s in ["radiation", "radiation_feedback"]: particles.color = Color("#adff2f")
		elif s in ["explosive", "death_bomb"]: particles.color = Color("#ff4500")
		else: particles.color = Color("#ffeb3b")
		
		unit.add_child(particles)
		particles.position = Vector2(0, -40)
		get_tree().create_timer(1.0).timeout.connect(particles.queue_free)
		
		if s == "unstable" or s == "volatile":
			var tween = create_tween()
			var base_pos = unit.position
			for i in range(5):
				tween.tween_property(unit, "position", base_pos + Vector2(randf_range(-12, 12), randf_range(-6, 6)), 0.05)
			tween.tween_property(unit, "position", base_pos, 0.05)
		elif s == "overload":
			var tween = create_tween()
			var base_mod = unit.modulate
			for i in range(5):
				tween.tween_property(unit, "modulate", Color(2.0, 2.0, 0.5), 0.05)
				tween.tween_property(unit, "modulate", base_mod, 0.05)
			tween.tween_property(unit, "modulate", Color.WHITE, 0.05)
		elif s in ["explosive", "death_bomb"]:
			var tween = create_tween()
			var base_mod = unit.modulate
			var base_scale = unit.scale
			for i in range(4):
				tween.tween_property(unit, "modulate", Color(3.0, 0.5, 0.2), 0.1)
				tween.parallel().tween_property(unit, "scale", base_scale * 1.05, 0.1)
				tween.tween_property(unit, "modulate", base_mod, 0.1)
				tween.parallel().tween_property(unit, "scale", base_scale, 0.1)
			tween.tween_property(unit, "modulate", Color.WHITE, 0.05)
			tween.parallel().tween_property(unit, "scale", base_scale, 0.05)

	# 4. Mind/Senses (Stun, Insanity, Refracted, Taunt)
	elif s in ["stun", "insanity", "refracted", "taunt", "marked_covalent", "chain_reaction_mark"]:
		var particles = CPUParticles2D.new()
		particles.amount = 8
		particles.lifetime = 0.8
		particles.one_shot = true
		particles.explosiveness = 0.9
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		particles.emission_sphere_radius = 20.0
		particles.direction = Vector2(0, -1)
		particles.initial_velocity_min = 50.0
		particles.initial_velocity_max = 80.0
		particles.gravity = Vector2(0, 50)
		particles.scale_amount_min = 8.0
		particles.scale_amount_max = 16.0
		
		if s == "stun": particles.color = Color("#ffd700")
		elif s == "insanity": particles.color = Color("#1a0033")
		elif s == "refracted": particles.color = Color("#ffffff")
		elif s in ["taunt", "marked_covalent", "chain_reaction_mark"]: particles.color = Color("#ff4d4d")
		
		unit.add_child(particles)
		particles.position = Vector2(0, -80) # Head level
		get_tree().create_timer(1.2).timeout.connect(particles.queue_free)
		
		# Add a subtle shake to the unit itself
		var tween = create_tween()
		var base_pos = unit.position
		for i in range(4):
			tween.tween_property(unit, "position", base_pos + Vector2(randf_range(-10, 10), 0), 0.05)
		tween.tween_property(unit, "position", base_pos, 0.05)
		
		if s == "insanity":
			var color_tween = create_tween()
			for i in range(6):
				var glitch_color = [Color(1, 0, 1), Color(0, 1, 1), Color(0.2, 0.2, 0.2), Color(1, 1, 0)].pick_random() # Magenta, Cyan, Dark Grey, Yellow
				color_tween.tween_property(unit, "modulate", glitch_color, 0.04)
			color_tween.tween_property(unit, "modulate", Color.WHITE, 0.05)

	# 5. Soot/Dust (Carbonized, Oxidized)
	elif s in ["carbonized", "oxidized"]:
		var particles = CPUParticles2D.new()
		particles.amount = 40
		particles.lifetime = 1.2
		particles.one_shot = true
		particles.explosiveness = 0.8
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		particles.emission_rect_extents = Vector2(30, 40)
		particles.gravity = Vector2(0, 40) # Float down like heavy dust
		particles.scale_amount_min = 2.0
		particles.scale_amount_max = 6.0
		
		var grad = Gradient.new()
		var base_c = Color(0.1, 0.1, 0.1, 0.8) if s == "carbonized" else Color(0.6, 0.3, 0.1, 0.8)
		grad.set_color(0, base_c)
		grad.set_color(1, Color(base_c.r, base_c.g, base_c.b, 0.0))
		particles.color_ramp = grad
		
		unit.add_child(particles)
		particles.position = Vector2(0, -40)
		get_tree().create_timer(1.5).timeout.connect(particles.queue_free)

func _strip_temporary_buffs(unit: BattleMonster):
	if not "active_effects" in unit: return
	
	# Only remove statuses when the unit is actually dead
	if not unit.is_dead: return
	
	# Iterate backwards to safely remove or revert
	for i in range(unit.active_effects.size() - 1, -1, -1):
		var effect = unit.active_effects[i]
		
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
				
		unit.active_effects.remove_at(i)

func _sync_roster_order():
	if not PlayerData: return
	
	PlayerData.active_team = current_player_team.duplicate()
	if PlayerData.has_method("save_game"):
		PlayerData.save_game()
