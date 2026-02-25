extends Node

# This script automatically scans the data/Monsters folder on startup
# and populates a global list.
# IMPORTANT: Add this to Project Settings -> Globals (Autoload) as "MonsterManifest"

var all_monsters: Array[MonsterData] = []
var monsters_by_z: Dictionary = {} # Key: Atomic Number (int), Value: MonsterData

func _ready():
	_scan_monsters()

func _scan_monsters():
	all_monsters.clear()
	monsters_by_z.clear()
	
	var folder_path = "res://data/Monsters/"
	var dir = DirAccess.open(folder_path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if not dir.current_is_dir():
				# Handle exported .remap files (Godot creates these on export)
				var clean_name = file_name.replace(".remap", "")
				
				if clean_name.ends_with(".tres"):
					var full_path = folder_path + clean_name
					var resource = load(full_path)
					
					if resource is MonsterData:
						all_monsters.append(resource)
						monsters_by_z[resource.atomic_number] = resource
			
			file_name = dir.get_next()
		
		dir.list_dir_end()
	else:
		push_error("MonsterManifest: Could not open directory " + folder_path)
	
	# Sort by Atomic Number so the list is always 1, 2, 3...
	all_monsters.sort_custom(func(a, b): return a.atomic_number < b.atomic_number)
	
	print("MonsterManifest: Loaded %d monsters." % all_monsters.size())

func get_monster(atomic_number: int) -> MonsterData:
	return monsters_by_z.get(atomic_number)