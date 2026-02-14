extends Node

# Inventory
var owned_monsters: Array[MonsterData] = []
var pending_egg: MonsterData = null
var selected_monster: MonsterData = null

# Resources
var resources = {
	"neutron_dust": 0
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
	"res://data/Monsters/Neon.tres"
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
	print("Added %d %s. Total: %d" % [amount, type, resources[type]])