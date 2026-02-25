extends Node

const SAVE_PATH = "user://savegame.json"

func _ready():
	load_game()
	
	# Initialize chambers if they don't exist (fresh save or migration)
	if synthesis_chambers.is_empty():
		for i in range(4):
			synthesis_chambers.append({
				"is_unlocked": (i == 0), # First one is unlocked by default
				"capsule": null
			})
	
	# On a fresh start, if the collection is empty, give the player the starting elements.
	if owned_monsters.is_empty():
		var he = load("res://data/Monsters/Helium.tres")
		var h = load("res://data/Monsters/Hydrogen.tres")
		if h: owned_monsters.append(h.duplicate())
		if he: owned_monsters.append(he.duplicate())
		save_game()

signal resource_updated(resource_type, amount)

# Inventory
var owned_monsters: Array[MonsterData] = []
var capsules: Array = [] # Array of Dictionaries { "id": String, "z": int }
var synthesis_chambers: Array = [] # Array of { "is_unlocked": bool, "capsule": Dictionary/null }
var pending_egg: MonsterData = null
var selected_monster: MonsterData = null

# Battle Prep Data
var active_team: Array[MonsterData] = []
var pending_enemy_team: Array[MonsterData] = []
var current_campaign_level: int = 1

# Resources
var resources = {
	"neutron_dust": 0,
	"experience": 0,
	"gems": 0
}

# --- Helper Functions ---

func is_monster_owned(monster_name: String) -> bool:
	for m in owned_monsters:
		if m.monster_name == monster_name:
			return true
	return false

func get_owned_monster(monster_name: String) -> MonsterData:
	for m in owned_monsters:
		if m.monster_name == monster_name:
			return m
	return null

func add_resource(type: String, amount: int):
	if not resources.has(type):
		resources[type] = 0
	resources[type] += amount
	print("PlayerData: Emitting resource_updated for '", type, "'")
	resource_updated.emit(type, resources[type])
	print("Added %d %s. Total: %d" % [amount, type, resources[type]])

func spend_resource(type: String, amount: int) -> bool:
	if resources.get(type, 0) >= amount:
		resources[type] -= amount
		resource_updated.emit(type, resources[type])
		print("Spent %d %s. Total: %d" % [amount, type, resources[type]])
		return true
	return false

func add_essence(group: int, amount: int):
	# Simplified: All essence is now Neutron Dust
	add_resource("neutron_dust", amount)

func get_monster_path_by_z(z: int) -> String:
	var m = MonsterManifest.get_monster(z)
	if m: return m.resource_path
	return ""

func add_capsule(z: int, p1_z: int = 0, p2_z: int = 0) -> Dictionary:
	var capsule = {
		"id": str(Time.get_unix_time_from_system()) + "_" + str(randi()),
		"z": z,
		"parents": [p1_z, p2_z]
	}
	capsules.append(capsule)
	save_game()
	return capsule

func remove_capsule(capsule_id: String):
	for i in range(capsules.size()):
		if capsules[i]["id"] == capsule_id:
			capsules.remove_at(i)
			save_game()
			return

# --- Save & Load System ---

func save_game():
	var save_data = {
		"resources": resources,
		"monsters": [],
		"capsules": capsules,
		"synthesis_chambers": synthesis_chambers,
		"current_campaign_level": current_campaign_level
	}
	
	# Serialize Monsters
	for m in owned_monsters:
		var m_data = {
			"name": m.monster_name,
			"level": m.level
		}
		# Save infusion stats if they exist on the monster object
		if "infusion_hp" in m: m_data["infusion_hp"] = m.infusion_hp
		if "infusion_attack" in m: m_data["infusion_attack"] = m.infusion_attack
		if "infusion_defense" in m: m_data["infusion_defense"] = m.infusion_defense
		if "infusion_speed" in m: m_data["infusion_speed"] = m.infusion_speed
		save_data["monsters"].append(m_data)
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	var json_str = JSON.stringify(save_data)
	file.store_string(json_str)
	
	# Also save timers from TimeManager
	if TimeManager.has_method("save_timers"):
		TimeManager.save_timers()
		
	print("PlayerData: Game Saved.")

func load_game():
	# Load Timers
	if TimeManager.has_method("load_timers"):
		TimeManager.load_timers()
	
	# Ensure MonsterManifest is populated before we try to look up monsters
	if MonsterManifest.all_monsters.is_empty():
		MonsterManifest._scan_monsters()
	
	if not FileAccess.file_exists(SAVE_PATH):
		return
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json_str = file.get_as_text()
	var save_data = JSON.parse_string(json_str)
	
	if save_data:
		if "resources" in save_data:
			resources = save_data["resources"]
			
			# Notify UI of loaded values
			for key in resources:
				resource_updated.emit(key, resources[key])
				
		if "capsules" in save_data:
			capsules = save_data["capsules"]
			
		if "synthesis_chambers" in save_data:
			synthesis_chambers = save_data["synthesis_chambers"]
			
		if "current_campaign_level" in save_data:
			current_campaign_level = int(save_data["current_campaign_level"])

		if "monsters" in save_data:
			owned_monsters.clear()
			for m_data in save_data["monsters"]:
				var m_name = m_data["name"]
				# Find the original resource to duplicate
				for m in MonsterManifest.all_monsters:
					if m.monster_name == m_name:
						var new_m = m.duplicate()
						new_m.level = int(m_data["level"])
						
						# Load infusion stats
						if "infusion_hp" in m_data: new_m.infusion_hp = int(m_data["infusion_hp"])
						if "infusion_attack" in m_data: new_m.infusion_attack = int(m_data["infusion_attack"])
						if "infusion_defense" in m_data: new_m.infusion_defense = int(m_data["infusion_defense"])
						if "infusion_speed" in m_data: new_m.infusion_speed = int(m_data["infusion_speed"])
						
						owned_monsters.append(new_m)
						break

func _notification(what):
	# Auto-save on exit or pause (mobile backgrounding)
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()

func reset_save():
	print("PlayerData: Resetting save data...")
	
	# 1. Clear In-Memory Data
	owned_monsters.clear()
	capsules.clear()
	synthesis_chambers.clear()
	current_campaign_level = 1
	resources = {
		"neutron_dust": 0,
		"experience": 0,
		"gems": 0
	}
	
	# 2. Delete Save Files
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	if FileAccess.file_exists("user://timers.save"):
		DirAccess.remove_absolute("user://timers.save")
		
	# 3. Re-initialize (Starter Logic)
	for i in range(4):
		synthesis_chambers.append({
			"is_unlocked": (i == 0),
			"capsule": null
		})
		
	var he = load("res://data/Monsters/Helium.tres")
	var h = load("res://data/Monsters/Hydrogen.tres")
	if h: owned_monsters.append(h.duplicate())
	if he: owned_monsters.append(he.duplicate())
	
	# 4. Save (creates fresh file)
	save_game()
	
	print("PlayerData: Save reset. Reloading scene...")
	get_tree().reload_current_scene()