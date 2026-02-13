extends Node

var owned_monsters: Array[MonsterData] = []
var pending_egg: MonsterData = null
var selected_monster: MonsterData = null

# Resources for the new Atomic System
var resources = { "neutron_dust": 0, "stability_boosters": 0 }

# Helper to check if we already own a specific monster
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

func add_resource(resource_name: String, amount: int):
	if resources.has(resource_name):
		resources[resource_name] += amount

# NOTE: You'll need to create these .tres files first!
var starter_monster_paths = [
	"res://Data/Monsters/Hydrogen.tres",
	"res://Data/Monsters/Helium.tres",
	"res://Data/Monsters/Lithium.tres",
	"res://Data/Monsters/Beryllium.tres",
	"res://Data/Monsters/Boron.tres",
	"res://Data/Monsters/Carbon.tres",
	"res://Data/Monsters/Nitrogen.tres",
	"res://Data/Monsters/Oxygen.tres",
	"res://Data/Monsters/Fluorine.tres",
	"res://Data/Monsters/Neon.tres"
]

func _ready():
	# Load only the first two elements as starters
	for path in starter_monster_paths:
		if FileAccess.file_exists(path):
			var monster_resource = load(path)
			if monster_resource:
				# Only add Hydrogen (1) and Helium (2) initially
				if monster_resource.atomic_number <= 2:
					owned_monsters.append(monster_resource)
		else:
			print("MISSING FILE: " + path)
			print("Make sure you created the folder 'Data' and 'Monsters' and saved the .tres files there!")