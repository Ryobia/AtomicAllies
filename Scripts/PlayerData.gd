extends Node

const SAVE_PATH = "user://savegame.json"
const REVIVE_COST = 1

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
		var li = load("res://data/Monsters/Lithium.tres")
		var be = load("res://data/Monsters/Beryllium.tres")
		var b = load("res://data/Monsters/Boron.tres")
		var f = load("res://data/Monsters/Fluorine.tres")
		var sc = load("res://data/Monsters/Scandium.tres")
		var la = load("res://data/Monsters/Lanthanum.tres")
		var ac = load("res://data/Monsters/Actinium.tres")
		var al = load("res://data/Monsters/Aluminium.tres")
		
		if al: owned_monsters.append(al.duplicate())
		if ac: owned_monsters.append(ac.duplicate())
		if la: owned_monsters.append(la.duplicate())
		if sc: owned_monsters.append(sc.duplicate())
		if be: owned_monsters.append(be.duplicate())
		if li: owned_monsters.append(li.duplicate())
		if h: owned_monsters.append(h.duplicate())
		if he: owned_monsters.append(he.duplicate())
		if b: owned_monsters.append(b.duplicate())
		if f: owned_monsters.append(f.duplicate())
		save_game()
	
	recalculate_class_resonance()

signal resource_updated(resource_type, amount)

# Inventory
var owned_monsters: Array[MonsterData] = []
var synthesis_chambers: Array = [] # Array of { "is_unlocked": bool, "capsule": Dictionary/null }
var pending_egg: MonsterData = null
var selected_monster: MonsterData = null

# Battle Prep Data
var active_team: Array[MonsterData] = []
var pending_enemy_team: Array[MonsterData] = []
var current_campaign_level: int = 1
var unlocked_blueprints: Array = [] # Array of Atomic Numbers (int)
var class_resonance: Dictionary = {} # Group (int) -> Resonance Level (int)
var inventory: Dictionary = {} # Item ID (String) -> Count (int)

# Resources
var resources = {
	"neutron_dust": 0,
	"gems": 0,
	"binding_energy": 0
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
	save_game()

func spend_resource(type: String, amount: int) -> bool:
	if resources.get(type, 0) >= amount:
		resources[type] -= amount
		resource_updated.emit(type, resources[type])
		print("Spent %d %s. Total: %d" % [amount, type, resources[type]])
		save_game()
		return true
	return false

func add_essence(group: int, amount: int):
	# Simplified: All essence is now Neutron Dust
	add_resource("neutron_dust", amount)

func add_item(item_id: String, amount: int = 1):
	if not inventory.has(item_id):
		inventory[item_id] = 0
	inventory[item_id] += amount
	save_game()
	print("Added %d %s. Total: %d" % [amount, item_id, inventory[item_id]])

func get_item_count(item_id: String) -> int:
	return inventory.get(item_id, 0)

func consume_item(item_id: String, amount: int = 1) -> bool:
	if get_item_count(item_id) >= amount:
		inventory[item_id] -= amount
		if inventory[item_id] <= 0:
			inventory.erase(item_id)
		save_game()
		return true
	return false

func get_monster_path_by_z(z: int) -> String:
	var m = MonsterManifest.get_monster(z)
	if m: return m.resource_path
	return ""

func get_first_empty_chamber_index() -> int:
	for i in range(synthesis_chambers.size()):
		var chamber = synthesis_chambers[i]
		if chamber["is_unlocked"] and chamber["capsule"] == null:
			return i
	return -1

func add_capsule_to_chamber(chamber_index: int, z: int, p1_z: int, p2_z: int, finish_time: int = 0, stability: int = 50) -> Dictionary:
	if chamber_index < 0 or chamber_index >= synthesis_chambers.size():
		return {}
		
	var capsule = {
		"id": str(Time.get_unix_time_from_system()) + "_" + str(randi()),
		"z": z,
		"parents": [p1_z, p2_z],
		"finish_time": finish_time,
		"stability": stability
	}
	synthesis_chambers[chamber_index]["capsule"] = capsule
	save_game()
	return capsule

func has_ready_chamber() -> bool:
	var current_time = int(Time.get_unix_time_from_system())
	for chamber in synthesis_chambers:
		if chamber.get("capsule"):
			var finish_time = chamber.capsule.get("finish_time", 0)
			if current_time >= finish_time:
				return true
	return false

func unlock_blueprint(z: int):
	if z not in unlocked_blueprints:
		unlocked_blueprints.append(z)
		save_game()
		recalculate_class_resonance()

func get_max_unlocked_z() -> int:
	var max_z = 0
	for m in owned_monsters:
		if m.atomic_number > max_z:
			max_z = m.atomic_number
	for z in unlocked_blueprints:
		if z > max_z:
			max_z = z
	return max_z

func recalculate_class_resonance():
	class_resonance.clear()
	
	# Count from owned monsters
	for m in owned_monsters:
		if not m: continue
		
		if not class_resonance.has(m.group):
			class_resonance[m.group] = 0
		class_resonance[m.group] += 1

# --- Save & Load System ---

func save_game():
	var save_data = {
		"resources": resources,
		"monsters": [],
		"synthesis_chambers": synthesis_chambers,
		"current_campaign_level": current_campaign_level,
		"unlocked_blueprints": unlocked_blueprints,
		"class_resonance": class_resonance,
		"inventory": inventory
	}
	
	# Serialize Monsters
	for m in owned_monsters:
		var m_data = {
			"name": m.monster_name,
			"stability": m.stability,
			"fatigue_expiry": m.fatigue_expiry
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
			var loaded_res = save_data["resources"]
			for key in loaded_res:
				resources[key] = loaded_res[key]
			
			# Notify UI of loaded values
			for key in resources:
				resource_updated.emit(key, resources[key])
				
		if "synthesis_chambers" in save_data:
			synthesis_chambers = save_data["synthesis_chambers"]
			
		if "current_campaign_level" in save_data:
			current_campaign_level = int(save_data["current_campaign_level"])

		if "unlocked_blueprints" in save_data:
			unlocked_blueprints = save_data["unlocked_blueprints"]
			# Ensure ints
			for i in range(unlocked_blueprints.size()):
				unlocked_blueprints[i] = int(unlocked_blueprints[i])
				
		if "class_resonance" in save_data:
			var raw_res = save_data["class_resonance"]
			class_resonance.clear()
			for k in raw_res:
				class_resonance[int(k)] = int(raw_res[k])

		if "inventory" in save_data:
			inventory = save_data["inventory"]

		if "monsters" in save_data:
			owned_monsters.clear()
			for m_data in save_data["monsters"]:
				var m_name = m_data["name"]
				# Find the original resource to duplicate
				for m in MonsterManifest.all_monsters:
					if m.monster_name == m_name:
						var new_m = m.duplicate()
						
						if "stability" in m_data:
							new_m.stability = int(m_data["stability"])
						else:
							new_m.stability = 50 # Default for legacy saves
						
						if "fatigue_expiry" in m_data:
							new_m.fatigue_expiry = int(m_data["fatigue_expiry"])
						
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
	synthesis_chambers.clear()
	current_campaign_level = 1
	unlocked_blueprints.clear()
	class_resonance.clear()
	inventory.clear()
	resources = {
		"neutron_dust": 999999,
		"gems": 99999,
		"binding_energy": 999999
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
	var li = load("res://data/Monsters/Lithium.tres")
	var be = load("res://data/Monsters/Beryllium.tres")
	var b = load("res://data/Monsters/Boron.tres")
	var f = load("res://data/Monsters/Fluorine.tres")
	var sc = load("res://data/Monsters/Scandium.tres")
	var la = load("res://data/Monsters/Lanthanum.tres")
	var ac = load("res://data/Monsters/Actinium.tres")
	var al = load("res://data/Monsters/Aluminium.tres")
		
	if al: owned_monsters.append(al.duplicate())
	if ac: owned_monsters.append(ac.duplicate())
	if la: owned_monsters.append(la.duplicate())
	if sc: owned_monsters.append(sc.duplicate())
	if be: owned_monsters.append(be.duplicate())
	if li: owned_monsters.append(li.duplicate())
	if h: owned_monsters.append(h.duplicate())
	if he: owned_monsters.append(he.duplicate())
	if b: owned_monsters.append(b.duplicate())
	if f: owned_monsters.append(f.duplicate())
	
	# 4. Save (creates fresh file)
	save_game()
	recalculate_class_resonance()
	
	print("PlayerData: Save reset. Reloading scene...")
	get_tree().reload_current_scene()