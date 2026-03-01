extends Node

# Autoload: CampaignManager

const ENEMY_PATHS = {
    "grunt": "res://data/Enemies/NullGrunt.tres",
    "tank": "res://data/Enemies/NullTank.tres",
    "commander": "res://data/Enemies/NullCommander.tres"
}

# The "Cost" of each enemy type in slots
const WEIGHTS = {
    "grunt": 1,
    "tank": 2,
    "commander": 3
}

const MAX_ENEMY_SLOTS = 6
const MAX_CAMPAIGN_LEVEL = 50

# Rogue-lite State
var is_active_campaign_battle: bool = false
var is_rogue_run: bool = false
var current_run_target_z: int = 0
var current_run_energy: int = 0
var current_run_wave: int = 0
var max_run_waves: int = 3 # Standard run length
var run_team_state: Dictionary = {} # MonsterData -> int (HP)
var run_buffs: Dictionary = {} # Stat (String) -> Amount (int)

# Starts a "Discovery Run" for a specific element node
func start_node_run(target_z: int):
    is_rogue_run = true
    current_run_target_z = target_z
    current_run_energy = 0
    current_run_wave = 1
    run_team_state.clear()
    run_buffs.clear()
    
    # Difficulty scales with Atomic Number
    # Z=3 (Lithium) stays easy (Level 1).
    # Z=4+ ramps up immediately (Level = Z).
    var difficulty_level = 1
    if target_z > 3: difficulty_level = target_z
    
    var enemies = generate_level_encounter(difficulty_level)
    
    PlayerData.pending_enemy_team = enemies
    GlobalManager.switch_scene("battle_prepare")

func on_battle_ended(player_won: bool, rewards: Dictionary = {}, final_team_state: Dictionary = {}):
    if is_rogue_run:
        if player_won:
            # Stash the energy
            if rewards.has("binding_energy"):
                current_run_energy += rewards["binding_energy"]
            
            # Update HP state for next wave
            for monster in final_team_state:
                run_team_state[monster] = final_team_state[monster]
            
            if current_run_wave < max_run_waves:
                # Continue Run
                current_run_wave += 1
                print("Wave Complete. Proceeding to Rest Site...")
                GlobalManager.switch_scene("rest_site")
            else:
                # Run Complete!
                print("Run Complete! Blueprint Unlocked: ", current_run_target_z)
                PlayerData.add_resource("binding_energy", current_run_energy)
                PlayerData.unlock_blueprint(current_run_target_z)
                is_rogue_run = false
        else:
            # Run Failed - Lose Energy
            print("Run Failed. Binding Energy Lost: ", current_run_energy)
            current_run_energy = 0
            is_rogue_run = false
    
    is_active_campaign_battle = false

func start_next_wave():
    var base_level = 1
    if current_run_target_z > 3: base_level = current_run_target_z
    
    var difficulty_level = base_level + (current_run_wave - 1)
    var enemies = generate_level_encounter(difficulty_level)
    PlayerData.pending_enemy_team = enemies
    GlobalManager.switch_scene("battle")

func generate_level_encounter(level: int) -> Array[MonsterData]:
    var enemies: Array[MonsterData] = []
    
    # 1. Calculate Chaos Budget (Slot Weight)
    # Ramped up progression: Level 4+ gets harder fast
    var budget = 3
    if level >= 4: budget = 4
    if level >= 8: budget = 5
    if level >= 12: budget = 6
    
    # Boss Levels (Every 10th) get max budget immediately
    var is_boss = (level % 10 == 0)
    if is_boss: budget = 6
    
    # 2. Determine Available Enemy Types based on progression
    var pool = ["grunt"]
    if level >= 4: pool.append("tank")
    if level >= 10: pool.append("commander")
    
    # 3. Fill the Budget
    var current_weight = 0
    
    # For Bosses, force a Commander first
    if is_boss:
        var boss = _create_enemy("commander", level + 2) # Boss is stronger
        boss.monster_name = "Void Lord"
        enemies.append(boss)
        current_weight += WEIGHTS["commander"]
    
    # Fill remaining slots until budget is met or slots are full
    while current_weight < budget and enemies.size() < MAX_ENEMY_SLOTS:
        # Filter pool for affordable units
        var affordable = []
        for type in pool:
            if WEIGHTS[type] <= (budget - current_weight):
                affordable.append(type)
        
        if affordable.is_empty():
            break
            
        # Pick a random affordable enemy
        var type = affordable.pick_random()
        
        var enemy = _create_enemy(type, level)
        enemies.append(enemy)
        current_weight += WEIGHTS[type]
        
    return enemies

func _create_enemy(type: String, level: int) -> MonsterData:
    var path = ENEMY_PATHS.get(type)
    if ResourceLoader.exists(path):
        var base = load(path)
        var enemy = base.duplicate()
        
        # Scale stability with difficulty level (Base 50 + Level)
        # Level 1 -> 51%, Level 50 -> 100%
        enemy.stability = clampi(50 + level, 50, 100)
        return enemy
    return null
