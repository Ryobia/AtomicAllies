extends Node

# -- CONFIGURATION --
const LEVEL_WEIGHT = 5.0 
const MIN_CHANCE = 15.0
const MAX_CHANCE = 100.0
const MAX_Z = 26 # Iron Limit

# Signal to tell the UI what happened
signal fusion_completed(result_z, success, reward)
signal capsule_created(capsule_data)
signal fusion_error(message)

# This mimics the "Cheat Sheet" logic for base stability
func get_base_stability(z: int) -> float:
	match z:
		2: return 90.0 # Helium (Easy)
		3: return 80.0 # Lithium
		4: return 75.0 # Beryllium
		5: return 65.0 # Boron
		6: return 60.0 # Carbon
		7: return 50.0 # Nitrogen
		8: return 45.0 # Oxygen
		9: return 35.0 # Fluorine
		10: return 30.0 # Neon (Hard)
		_: return 20.0 # Default for heavier elements

func calculate_stability(level_a: int, level_b: int, target_z: int) -> float:
	var base = get_base_stability(target_z)
	
	# The Formula: Heavier elements require higher level parents to stabilize
	var bonus = (float(level_a + level_b) * LEVEL_WEIGHT) / float(target_z)
	
	return clamp(base + bonus, MIN_CHANCE, MAX_CHANCE)

func attempt_fusion(parent_a: MonsterData, parent_b: MonsterData):
	var initial_target_z = parent_a.atomic_number + parent_b.atomic_number
	
	if initial_target_z > MAX_Z:
		fusion_error.emit("Ship Upgrade Required: Cannot synthesize elements beyond Iron (26).")
		return

	var current_z = initial_target_z
	
	# Decay Loop: Keep rolling until we succeed or hit Hydrogen (1)
	while current_z > 1:
		var chance = calculate_stability(parent_a.level, parent_b.level, current_z)
		var roll = randf() * 100.0
		
		print("Rolling for Z%d (Chance: %.1f%%)... Rolled: %.1f" % [current_z, chance, roll])
		
		if roll <= chance:
			break # Success! We stabilized at current_z
		
		# Failure: Decay and try again
		print("Fusion unstable at Z%d! Decaying..." % current_z)
		current_z -= 1
	
	# If we reach 1, it is guaranteed (Hydrogen is the baseline)
	if current_z == 1:
		print("Stabilized at Hydrogen (Z=1).")
	
	if PlayerData:
		var capsule = PlayerData.add_capsule(current_z, parent_a.atomic_number, parent_b.atomic_number)
		capsule_created.emit(capsule)
		print("Fusion complete. Capsule created: ", capsule)

# Renamed from _process_fusion_result to be called after the synthesis chamber step
func complete_synthesis(z_num: int):
	# Safety check for cap (handles legacy capsules > 26)
	if z_num > MAX_Z:
		print("Synthesis failed: Z%d exceeds ship capacity." % z_num)
		var dust = z_num * 5
		if PlayerData:
			PlayerData.add_resource("neutron_dust", dust)
		fusion_completed.emit(z_num, false, dust)
		return

	# 1. Find the monster data for this Atomic Number
	var path = PlayerData.get_monster_path_by_z(z_num)
	if path == "":
		print("Error: No monster path found for Z%d" % z_num)
		fusion_completed.emit(z_num, false, 0) # Ensure UI resets
		return

	var monster_res = load(path)
	if not monster_res:
		print("Error: Could not load monster resource at %s" % path)
		fusion_completed.emit(z_num, false, 0) # Ensure UI resets
		return
	
	# 2. Check if the player already owns this monster
	if PlayerData.is_monster_owned(monster_res.monster_name):
		# DUPLICATE -> DISSOLVE INTO DUST
		# Higher Z gives more dust
		var dust_amount = z_num * 10 
		
		if PlayerData:
			PlayerData.add_resource("neutron_dust", dust_amount)
			
		print("Duplicate Z%d found. Dissolved into %d Neutron Dust." % [z_num, dust_amount])
		fusion_completed.emit(z_num, false, dust_amount)
		
	else:
		# NEW DISCOVERY -> ADD TO COLLECTION
		var new_monster = monster_res.duplicate()
		new_monster.level = 1 # New fusions start at Level 1
		
		if PlayerData:
			PlayerData.owned_monsters.append(new_monster)
			PlayerData.save_game()
			
		print("New Monster Z%d added to collection!" % z_num)
		fusion_completed.emit(z_num, true, 0)