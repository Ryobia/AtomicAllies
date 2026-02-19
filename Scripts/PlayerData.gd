extends Node

const SAVE_PATH = "user://savegame.json"

func _ready():
	load_game()
	
	# On a fresh start, if the collection is empty, give the player the starting elements.
	if owned_monsters.is_empty():
		var h = load("res://data/Monsters/Hydrogen.tres")
		var he = load("res://data/Monsters/Helium.tres")
		if h: owned_monsters.append(h.duplicate())
		if he: owned_monsters.append(he.duplicate())
		save_game()

signal resource_updated(resource_type, amount)

# Inventory
var owned_monsters: Array[MonsterData] = []
var pending_egg: MonsterData = null
var selected_monster: MonsterData = null

# Resources
var resources = {
	"neutron_dust": 0,
	"experience": 0,
	"gems": 0
}

# List of all discoverable monsters (for the Collection Grid)
var starter_monster_paths = [
	"res://data/Monsters/Hydrogen.tres",
	"res://data/Monsters/Helium.tres",
	"res://data/Monsters/Lithium.tres",
	"res://data/Monsters/Beryllium.tres",
	"res://data/Monsters/Boron.tres",
	"res://data/Monsters/Carbon.tres",
	"res://data/Monsters/Nitrogen.tres",
	"res://data/Monsters/Oxygen.tres",
	"res://data/Monsters/Fluorine.tres",
	"res://data/Monsters/Neon.tres",
	"res://data/Monsters/Sodium.tres",
	"res://data/Monsters/Magnesium.tres",
	"res://data/Monsters/Aluminium.tres",
	"res://data/Monsters/Silicon.tres",
	"res://data/Monsters/Phosphorus.tres",
	"res://data/Monsters/Sulfur.tres",
	"res://data/Monsters/Chlorine.tres",
	"res://data/Monsters/Argon.tres",
	"res://data/Monsters/Potassium.tres",
	"res://data/Monsters/Calcium.tres",
	"res://data/Monsters/Scandium.tres",
	"res://data/Monsters/Titanium.tres",
	"res://data/Monsters/Vanadium.tres",
	"res://data/Monsters/Chromium.tres",
	"res://data/Monsters/Manganese.tres",
	"res://data/Monsters/Iron.tres"
]

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

# --- Save & Load System ---

func save_game():
	var save_data = {
		"resources": resources,
		"monsters": []
	}
	
	# Serialize Monsters
	for m in owned_monsters:
		save_data["monsters"].append({
			"name": m.monster_name,
			"level": m.level
		})
		
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
				
		if "monsters" in save_data:
			owned_monsters.clear()
			for m_data in save_data["monsters"]:
				var m_name = m_data["name"]
				# Find the original resource to duplicate
				for path in starter_monster_paths:
					var res = load(path)
					if res and res.monster_name == m_name:
						var new_m = res.duplicate()
						new_m.level = int(m_data["level"])
						owned_monsters.append(new_m)
						break

func _notification(what):
	# Auto-save on exit or pause (mobile backgrounding)
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()