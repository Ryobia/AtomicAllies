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

var is_active_campaign_battle: bool = false

func start_next_level():
    var level = PlayerData.current_campaign_level
    
    # Cap at 50 for now (or loop into endless later)
    if level > MAX_CAMPAIGN_LEVEL:
        print("Campaign Completed! You have conquered the Void.")
        return
    
    is_active_campaign_battle = true
    var enemies = generate_level_encounter(level)
    
    PlayerData.pending_enemy_team = enemies
    GlobalManager.switch_scene("battle")

func on_battle_ended(player_won: bool):
    if is_active_campaign_battle and player_won:
        if PlayerData.current_campaign_level <= MAX_CAMPAIGN_LEVEL:
            PlayerData.current_campaign_level += 1
            PlayerData.save_game()
            print("Campaign Progress: Level ", PlayerData.current_campaign_level)
    
    is_active_campaign_battle = false

func generate_level_encounter(level: int) -> Array[MonsterData]:
    var enemies: Array[MonsterData] = []
    
    # 1. Calculate Chaos Budget (Slot Weight)
    # Scales from 3 (Level 1) to 6 (Level 50)
    var budget = 3
    if level > 10: budget = 4
    if level > 25: budget = 5
    if level > 40: budget = 6
    
    # Boss Levels (Every 10th) get max budget immediately
    var is_boss = (level % 10 == 0)
    if is_boss: budget = 6
    
    # 2. Determine Available Enemy Types based on progression
    var pool = ["grunt"]
    if level >= 5: pool.append("tank")
    if level >= 15: pool.append("commander")
    
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
        # Scale level with some variance
        enemy.level = max(1, level + randi_range(-1, 1))
        return enemy
    return null
