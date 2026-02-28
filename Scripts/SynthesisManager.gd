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

func calculate_stability(stability_a: int, stability_b: int, target_z: int) -> float:
	var base = get_base_stability(target_z)
	
	# Bonus: Each parent contributes up to 25% flat bonus at 100% stability
	var bonus = (float(stability_a) / 100.0 * 25.0) + (float(stability_b) / 100.0 * 25.0)
	
	return clamp(base + bonus, MIN_CHANCE, MAX_CHANCE)

func calculate_stability_gain(current: int) -> int:
	var remaining = 100 - current
	if remaining <= 0: return 0
	
	# Weighted random: x^3 bias towards 0 (smaller gains)
	var roll = pow(randf(), 3.0)
	# Ensure at least 1 gain if remaining > 0
	var gain = 1 + int(roll * (remaining - 1))
	return gain

func attempt_fusion(parent_a: MonsterData, parent_b: MonsterData):
	var initial_target_z = parent_a.atomic_number + parent_b.atomic_number
	
	if initial_target_z > MAX_Z:
		fusion_error.emit("Ship Upgrade Required: Cannot synthesize elements beyond Iron (26).")
		return

	var current_z = initial_target_z
	
	# Decay Loop: Keep rolling until we succeed or hit Hydrogen (1)
	while current_z > 1:
		var chance = calculate_stability(parent_a.stability, parent_b.stability, current_z)
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
		var existing = PlayerData.get_owned_monster(monster_res.monster_name)
		
		if existing.stability < 100:
			# UPGRADE STABILITY
			var gain = calculate_stability_gain(existing.stability)
			existing.stability += gain
			if existing.stability > 100: existing.stability = 100
			PlayerData.save_game()
			
			print("Stability Improved for Z%d! New Stability: %d%%" % [z_num, existing.stability])
			fusion_completed.emit(z_num, false, 0) # Success but no new monster/dust
		else:
			# MAXED OUT -> DISSOLVE INTO DUST
			var dust_amount = z_num * 10 
			if PlayerData:
				PlayerData.add_resource("neutron_dust", dust_amount)
			print("Duplicate Z%d (Max Stability) found. Dissolved into %d Neutron Dust." % [z_num, dust_amount])
			fusion_completed.emit(z_num, false, dust_amount)
		
	else:
		# NEW DISCOVERY -> ADD TO COLLECTION
		var new_monster = monster_res.duplicate()
		
		# Assign initial stability (Base 50 + weighted gain)
		new_monster.stability = 50 + calculate_stability_gain(50)
		if new_monster.stability > 100: new_monster.stability = 100
		
		if PlayerData:
			PlayerData.owned_monsters.append(new_monster)
			PlayerData.unlock_blueprint(z_num) # Ensure resonance is updated
			PlayerData.save_game()
			
		print("New Monster Z%d added to collection! Stability: %d%%" % [z_num, new_monster.stability])
		fusion_completed.emit(z_num, true, 0)