extends Node

# -- CONFIGURATION --
const LEVEL_WEIGHT = 5.0 
const MIN_CHANCE = 15.0
const MAX_CHANCE = 100.0
const MAX_Z = 118 # Oganesson Limit

# Signal to tell the UI what happened
signal fusion_completed(result_z, success, reward)
signal capsule_created(capsule_data)
signal fusion_error(message)

# This mimics the "Cheat Sheet" logic for base success rate
func get_base_success_rate(z: int) -> float:
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

func calculate_success_rate(stability_a: int, stability_b: int, target_z: int) -> float:
	var base = get_base_success_rate(target_z)
	
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

func calculate_synthesis_duration(z: int, stability: int) -> float:
	# Scale max time based on Z: 15 mins (900s) at Z=1 to 60 mins (3600s) at Z=118
	var min_max_time = 900.0
	var max_max_time = 3600.0
	
	var z_factor = clamp(float(z - 1) / float(MAX_Z - 1), 0.0, 1.0)
	var max_time_for_z = min_max_time + (max_max_time - min_max_time) * z_factor
	
	# Stability reduces time: 100% stability = 0 time, 0% stability = max_time_for_z
	var stability_factor = clamp(float(stability), 0.0, 100.0) / 100.0
	var duration = max_time_for_z * (1.0 - stability_factor)
	
	# Apply Ship Upgrade: Fusion Speed (10% reduction per level)
	if PlayerData:
		var speed_level = PlayerData.get_upgrade_level("fusion_speed")
		duration *= (1.0 - (speed_level * 0.10))
	
	return duration

func attempt_fusion(parent_a: MonsterData, parent_b: MonsterData):
	attempt_fusion_with_bonus(parent_a, parent_b, 0)

func attempt_fusion_with_bonus(parent_a: MonsterData, parent_b: MonsterData, bonus_percent: int):
	var initial_target_z = parent_a.atomic_number + parent_b.atomic_number
	
	# Check for empty chamber first
	var chamber_idx = -1
	if PlayerData:
		chamber_idx = PlayerData.get_first_empty_chamber_index()
		if chamber_idx == -1:
			fusion_error.emit("No empty Synthesis Chambers available!")
			return

	# Check Blueprint Unlock
	if PlayerData:
		if initial_target_z > PlayerData.get_max_unlocked_z():
			fusion_error.emit("Blueprint Required: Complete Discovery Run for Z-%d." % initial_target_z)
			return

	if initial_target_z > MAX_Z:
		fusion_error.emit("Ship Upgrade Required: Cannot synthesize elements beyond Oganesson (118).")
		return

	# Apply Fatigue to Parents
	# Cooldown = 1 minute * Attempted Z
	var cooldown_seconds = initial_target_z * 60
	var expiry = int(Time.get_unix_time_from_system()) + cooldown_seconds
	
	parent_a.fatigue_expiry = expiry
	parent_b.fatigue_expiry = expiry
	if PlayerData: PlayerData.save_game()

	var current_z = initial_target_z
	var final_stability = 0.0
	
	# Decay Loop: Keep rolling until we succeed or hit Hydrogen (1)
	while current_z > 1:
		var chance = calculate_success_rate(parent_a.stability, parent_b.stability, current_z)
		chance += float(bonus_percent)
		chance = clamp(chance, MIN_CHANCE, MAX_CHANCE)
		var roll = randf() * 100.0
		
		print("Rolling for Z%d (Chance: %.1f%%)... Rolled: %.1f" % [current_z, chance, roll])
		
		if roll <= chance:
			final_stability = _calculate_result_stability(current_z)
			break # Success! We stabilized at current_z
		
		# Failure: Decay and try again
		print("Fusion unstable at Z%d! Decaying..." % current_z)
		current_z -= 1
	
	# If we reach 1, it is guaranteed (Hydrogen is the baseline)
	if current_z == 1:
		print("Stabilized at Hydrogen (Z=1).")
		final_stability = _calculate_result_stability(1)
	
	var base_duration = calculate_synthesis_duration(current_z, int(final_stability))
	
	# Tutorial Override: 30 seconds for the first fusion
	if TutorialManager and PlayerData and PlayerData.tutorial_step == TutorialManager.Step.CLICK_FUSE:
		base_duration = 30.0
	
	var duration = int(max(0, base_duration))
	var finish_time = int(Time.get_unix_time_from_system()) + duration
	
	if PlayerData:
		var capsule = PlayerData.add_capsule_to_chamber(chamber_idx, current_z, parent_a.atomic_number, parent_b.atomic_number, finish_time, int(final_stability))
		capsule_created.emit(capsule)
		print("Fusion complete. Capsule placed in Chamber %d. Time: %ds" % [chamber_idx, duration])

# Renamed from _process_fusion_result to be called after the synthesis chamber step
func complete_synthesis(z_num: int, incoming_stability: int = 50):
	# Safety check for cap (handles legacy capsules > 26)
	if z_num > MAX_Z:
		print("Synthesis failed: Z%d exceeds ship capacity." % z_num)
		var dust = _calculate_dust_reward(z_num * 5)
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
		
		# Always award dust for duplicates
		var dust_amount = _calculate_dust_reward(z_num * 10)
		if PlayerData:
			PlayerData.add_resource("neutron_dust", dust_amount)
			
		var msg = "Duplicate Z-%d found!\nDissolved into %d Neutron Dust." % [z_num, dust_amount]
		
		# Check for stability upgrade
		if incoming_stability > existing.stability:
			existing.stability = incoming_stability
			PlayerData.save_game()
			msg += "\nStability increased to %d%%!" % incoming_stability
		else:
			msg += "\nCurrent Stability: %d%% (New: %d%%)" % [existing.stability, incoming_stability]
		
		fusion_completed.emit(z_num, false, msg)
		
	else:
		# NEW DISCOVERY -> ADD TO COLLECTION
		var new_monster = monster_res.duplicate()
		
		# Assign stability from the fusion result
		new_monster.stability = incoming_stability
		
		if PlayerData:
			PlayerData.owned_monsters.append(new_monster)
			PlayerData.unlock_blueprint(z_num) # Ensure resonance is updated
			PlayerData.save_game()
			
		print("New Monster Z%d added to collection! Stability: %d%%" % [z_num, new_monster.stability])
		fusion_completed.emit(z_num, true, 0)

func _calculate_dust_reward(base_amount: int) -> int:
	if not PlayerData: return base_amount
	var siphon_level = PlayerData.get_upgrade_level("dust_efficiency")
	return int(base_amount * (1.0 + (siphon_level * 0.10)))

func _calculate_result_stability(z: int) -> int:
	var current_val = 0 # Base floor (so min result is 1% for new/low elements)
	
	if PlayerData:
		var path = PlayerData.get_monster_path_by_z(z)
		if path != "":
			var res = load(path)
			if res and PlayerData.is_monster_owned(res.monster_name):
				var owned = PlayerData.get_owned_monster(res.monster_name)
				if owned.stability > current_val:
					current_val = owned.stability
	
	var min_val = clampi(current_val + 3, 1, 100)
	
	if min_val >= 100: return 100
	
	# Weighted random: Bias heavily towards min_val (current stability)
	# Power of 4 makes high rolls much less likely
	var exponent = 4.0
	
	# Apply Isotope Scanner Upgrade
	if PlayerData:
		var scanner_level = PlayerData.get_upgrade_level("scanner_range")
		exponent = max(1.0, 4.0 - (scanner_level * 0.3))
	
	var range_size = 100 - min_val
	var roll = pow(randf(), exponent)
	var added = int(roll * range_size)
	
	return min_val + added