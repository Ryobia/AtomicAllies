extends Node

# Autoload: CampaignManager

# Current active race for encounters (Change this to "brood", "eldritch", etc. to test)
var current_enemy_race: String = "brood"

const RACE_CONFIG = {
    "void": {
        "grunt": "res://data/Enemies/NullGrunt.tres",
        "brute": "res://data/Enemies/NullTank.tres",
        "assassin": "res://data/Enemies/NullAssassin.tres",
        "commander": "res://data/Enemies/NullCommander.tres",
        "king": "res://data/Enemies/NullKing.tres"
    },
    "brood": {
        "grunt": "res://data/Enemies/BroodGrunt.tres",
        "assassin": "res://data/Enemies/BroodAssassin.tres",
        "brute": "res://data/Enemies/BroodBrute.tres",
        "commander": "res://data/Enemies/BroodCommander.tres",
        "king": "res://data/Enemies/BroodKing.tres"
    },
    "chaos": {
        "grunt": "res://data/Enemies/ChaosGrunt.tres",
        "assassin": "res://data/Enemies/ChaosAssassin.tres",
        "brute": "res://data/Enemies/ChaosBrute.tres",
        "commander": "res://data/Enemies/ChaosCommander.tres",
        "king": "res://data/Enemies/ChaosKing.tres"
    },
    "fission": {
        "grunt": "res://data/Enemies/FissionGrunt.tres",
        "assassin": "res://data/Enemies/FissionAssassin.tres",
        "brute": "res://data/Enemies/FissionBrute.tres",
        "commander": "res://data/Enemies/FissionCommander.tres",
        "king": "res://data/Enemies/FissionKing.tres"
    },
    "eldritch": {
        "grunt": "res://data/Enemies/EldritchGrunt.tres",
        "assassin": "res://data/Enemies/EldritchAssassin.tres",
        "brute": "res://data/Enemies/EldritchBrute.tres",
        "commander": "res://data/Enemies/EldritchCommander.tres",
        "king": "res://data/Enemies/EldritchKing.tres"
    }
}

# Map Player Element Groups to Enemy Races for thematic Discovery Runs
const GROUP_TO_RACE_MAP = {
    AtomicConfig.Group.ALKALI_METAL: "fission",
    AtomicConfig.Group.ALKALINE_EARTH: "void",
    AtomicConfig.Group.TRANSITION_METAL: "chaos",
    AtomicConfig.Group.POST_TRANSITION: "void",
    AtomicConfig.Group.METALLOID: "chaos",
    AtomicConfig.Group.NONMETAL: "brood",
    AtomicConfig.Group.HALOGEN: "brood",
    AtomicConfig.Group.NOBLE_GAS: "eldritch",
    AtomicConfig.Group.ACTINIDE: "fission",
    AtomicConfig.Group.LANTHANIDE: "eldritch",
    AtomicConfig.Group.UNKNOWN: "void"
}

# The "Cost" of each enemy type in slots
const WEIGHTS = {
    "grunt": 1,
    "assassin": 2,
    "brute": 2,
    "commander": 3,
    "king": 5
}

const MAX_ENEMY_SLOTS = 3
const MAX_CAMPAIGN_LEVEL = 50

# Rogue-lite State
var is_active_campaign_battle: bool = false
var is_rogue_run: bool = false
var current_run_target_z: int = 0
var current_run_energy: int = 0
var current_run_dust: int = 0
var current_run_gems: int = 0
var current_run_wave: int = 0
var max_run_waves: int = 3 # Standard run length
var run_team_state: Dictionary = {} # MonsterData -> int (HP)
var run_buffs: Dictionary = {} # Stat (String) -> Amount (int)

# Starts a "Discovery Run" for a specific element node
func start_node_run(target_z: int):
    is_rogue_run = true
    current_run_target_z = target_z
    current_run_energy = 0
    current_run_dust = 0
    current_run_gems = 0
    current_run_wave = 1
    run_team_state.clear()
    run_buffs.clear()
    
    # Determine Enemy Race based on Target Element's Group
    var target_monster = MonsterManifest.get_monster(target_z)
    if target_monster:
        current_enemy_race = GROUP_TO_RACE_MAP.get(target_monster.group, "void")
    else:
        current_enemy_race = "void"
        
    print("Starting run for Z%d. Enemy Race: %s" % [target_z, current_enemy_race])
    
    # Adjust run structure based on race
    # Scale waves based on Atomic Number (Z). Z=1 -> 3 waves, Z=118 -> ~10 waves.
    var base_waves = 3 + int(target_z / 16.0)
    
    if current_enemy_race == "brood":
        max_run_waves = base_waves + 2 # Swarm: More waves
    else:
        max_run_waves = base_waves
    
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
            if rewards.has("neutron_dust"):
                current_run_dust += rewards["neutron_dust"]
            if rewards.has("gems"):
                current_run_gems += rewards["gems"]
            
            # Update HP state for next wave
            for monster in final_team_state:
                run_team_state[monster] = final_team_state[monster]
            
            if current_run_wave < max_run_waves:
                # Continue Run
                current_run_wave += 1
                
                var skip_rest = false
                if current_enemy_race == "brood":
                    # Swarm behavior: Fight 2 waves back-to-back before resting
                    # Wave 1 -> 2 (Skip Rest)
                    # Wave 2 -> 3 (Rest)
                    # Wave 3 -> 4 (Skip Rest)
                    # Wave 4 -> 5 (Rest)
                    if current_run_wave % 2 == 0:
                        skip_rest = true
                
                if skip_rest:
                    print("Swarm continues! Immediate next wave...")
                    start_next_wave()
                else:
                    print("Wave Complete. Proceeding to Rest Site...")
                    GlobalManager.switch_scene("rest_site")
            else:
                # Run Complete!
                print("Run Complete! Blueprint Unlocked: ", current_run_target_z)
                PlayerData.add_resource("binding_energy", current_run_energy)
                if current_run_dust > 0: PlayerData.add_resource("neutron_dust", current_run_dust)
                if current_run_gems > 0: PlayerData.add_resource("gems", current_run_gems)
                PlayerData.unlock_blueprint(current_run_target_z)
                is_rogue_run = false
        else:
            # Run Failed - Lose Energy
            print("Run Failed. Binding Energy Lost: ", current_run_energy)
            current_run_energy = 0
            current_run_dust = 0
            current_run_gems = 0
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
    if level >= 2: pool.append("assassin")
    if level >= 4: pool.append("brute")
    if level >= 8: pool.append("commander")
    if level >= 15: pool.append("king")
    
    # 3. Fill the Budget
    var current_weight = 0
    
    # For Bosses, force a Commander or King
    if is_boss:
        var boss_type = "commander"
        if level >= 10: boss_type = "king"
        
        var boss = _create_enemy(boss_type, level + 2) # Boss is stronger
        # Removed name override to ensure animations load correctly
        enemies.append(boss)
        current_weight += WEIGHTS[boss_type]
    
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
    var race_paths = RACE_CONFIG.get(current_enemy_race, RACE_CONFIG["void"])
    var path = race_paths.get(type)
    if ResourceLoader.exists(path):
        var base = load(path)
        var enemy = base.duplicate()
        
        # Scale stability with difficulty level (Base 50 + Level)
        # Level 1 -> 51%, Level 50 -> 100%
        enemy.stability = clampi(50 + level, 50, 100)
        return enemy
    return null
