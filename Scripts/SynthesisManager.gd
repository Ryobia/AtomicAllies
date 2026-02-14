extends Node

# -- CONFIGURATION --
const LEVEL_WEIGHT = 5.0 
const MIN_CHANCE = 15.0
const MAX_CHANCE = 100.0

# Signal to tell the UI what happened
signal fusion_completed(result_z, success, reward)

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
	var target_z = parent_a.atomic_number + parent_b.atomic_number
	
	# 1. Calculate Odds
	var chance = calculate_stability(parent_a.level, parent_b.level, target_z)
	var roll = randf() * 100.0
	
	print("Attempting Fusion: Z%d + Z%d -> Z%d (Chance: %.1f%%)" % [parent_a.atomic_number, parent_b.atomic_number, target_z, chance])
	
	if roll <= chance:
		# SUCCESS
		_handle_success(target_z)
	else:
		# FAILURE
		_handle_failure(target_z, chance)

func _handle_success(target_z: int):
	# In a real scenario, we would look up the MonsterData resource for this Z
	# For now, we just signal that it worked
	print("Fusion Successful! Element #%d created." % target_z)
	fusion_completed.emit(target_z, true, 0)

func _handle_failure(target_z: int, chance: float):
	# Calculate Neutron Dust reward based on difficulty
	var dust_amount = int((target_z * 10) * (1.0 - (chance / 100.0)))
	
	if PlayerData:
		PlayerData.add_resource("neutron_dust", dust_amount)
	
	print("Fusion Failed. Recovered %d Neutron Dust." % dust_amount)
	fusion_completed.emit(target_z, false, dust_amount)