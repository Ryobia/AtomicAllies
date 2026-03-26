extends Node

# NOTE: For this to work globally, add this script to your Project Settings -> Autoload tab.

# PvE Combat Logic (No Type Chart, No Surge)

var current_global_entropy: int = 0

# --- Battle Items ---
const ITEM_DATA = {
	"repair_nanites": { "name": "Repair Nanites", "target": "Ally", "effect": "heal_percent", "amount": 0.5, "desc": "Restores 50% Max HP." },
	"adrenaline_shot": { "name": "Adrenaline Shot", "target": "Ally", "effect": "buff_stat", "stat": "attack", "amount": 20, "duration": 3, "desc": "Raises Attack by 20% for 3 turns." },
	"emergency_shield": { "name": "Emergency Shield", "target": "Ally", "effect": "add_shield", "amount": 0.3, "desc": "Grants a 30% Max HP Shield." },
	"power_cell": { "name": "Power Cell", "target": "Ally", "effect": "heal_percent", "amount": 1.0, "desc": "Restores 100% Max HP." },
	"ion_battery": { "name": "Ion Battery", "target": "Ally", "effect": "buff_stat", "stat": "defense", "amount": 20, "duration": 3, "desc": "Raises Defense by 20% for 3 turns." },
	"plasma_injector": { "name": "Plasma Injector", "target": "Ally", "effect": "buff_stat", "stat": "speed", "amount": 20, "duration": 3, "desc": "Raises Speed by 20% for 3 turns." },
	"purifying_salt": { "name": "Purifying Salt", "target": "Ally", "effect": "cleanse_debuffs", "desc": "Removes all negative status effects and stat drops." },
	"defibrillator": { "name": "Defibrillator", "target": "Ally", "effect": "revive", "amount": 0.5, "desc": "Revives a fallen unit with 50% HP." }
}

func get_item_data(item_id: String) -> Dictionary:
	return ITEM_DATA.get(item_id, {})

func apply_item_effect(target: BattleMonster, item_id: String):
	var data = get_item_data(item_id)
	if data.is_empty(): return
	
	match data.effect:
		"heal_percent":
			var amount = int(target.max_hp * data.amount)
			target.heal(amount)
		"buff_stat":
			var effect = { "target": target, "stat": data.stat, "amount": int(target.stats.get(data.stat, 10) * (data.amount / 100.0)), "duration": data.duration, "type": "stat_mod" }
			target.apply_effect(effect)
		"add_shield":
			var amount = int(target.max_hp * data.amount)
			var current = target.get_meta("shield", 0)
			target.set_meta("shield", current + amount)
		"cleanse_debuffs":
			if "active_effects" in target:
				var cleaned = false
				var effects = target.active_effects
				for i in range(effects.size() - 1, -1, -1):
					var eff = effects[i]
					var is_debuff = false
					if eff.get("type") == "stat_mod" and eff.get("amount", 0) < 0:
						is_debuff = true
					elif eff.has("status"):
						var s = str(eff.get("status", "")).to_lower()
						if eff.has("damage_multiplier") or s in ["poison", "stun", "silence_special", "vulnerable", "corrosion", "radiation", "refracted", "insanity", "singularity_hazard", "reactive_vapor", "chain_reaction_mark", "processing_loop", "luminescent", "burn", "proton_charge", "spontaneous_fumes", "incendiary_flash", "contrast_shadow", "bio_poison", "decay_catalyst", "irradiated_lock", "smoke_detector", "law_of_octets", "mri_trace", "buff_lock", "suppressed", "inhibited"]:
							is_debuff = true
					elif eff.get("type") == "swap_stats":
						is_debuff = true
						
					if is_debuff:
						if eff.has("status") and eff.get("status") == "reduced" and (target.has_status("illuminated") or target.has_status("irradiated_lock")):
							continue
							
						cleaned = true
						if eff.get("type") == "stat_mod":
							var stat = eff.get("stat")
							var amt = eff.get("amount", 0)
							if target.stats.has(stat): target.stats[stat] -= amt
						elif eff.get("type") == "swap_stats":
							var stats = eff.get("stats", [])
							if stats.size() == 2:
								var v1 = target.stats.get(stats[0], 0)
								var v2 = target.stats.get(stats[1], 0)
								target.stats[stats[0]] = v2
								target.stats[stats[1]] = v1
						effects.remove_at(i)
				if cleaned and target.has_signal("effects_changed"):
					target.effects_changed.emit(target.active_effects)

# Retrieves moves for a monster, falling back to Group Defaults if necessary
func get_active_moves(monster: MonsterData) -> Array:
	var moves: Array = []
	
	# 1. Unique Signature Move (Based on Atomic Number)
	if AtomicConfig.UNIQUE_MOVES.has(monster.atomic_number):
		var def = AtomicConfig.UNIQUE_MOVES[monster.atomic_number]
		var m = _create_move_from_dict(def)
		# Mastery: Dual Logic (Metalloids)
		if monster.group == AtomicConfig.Group.METALLOID and monster.stability >= 100:
			m.cooldown = max(0, m.cooldown - 1)
		moves.append(m)
	
	# 2. Add Custom/Group Moves
	if not monster.moves.is_empty():
		# If specific moves are assigned in Inspector, use those
		moves.append_array(monster.moves)
	elif "group" in monster:
		# Fallback to Group defaults
		var defaults = AtomicConfig.GROUP_MOVES.get(monster.group, [])
		for def in defaults:
			moves.append(_create_move_from_dict(def))
	
	return moves

func _create_move_from_dict(def: Dictionary) -> MoveData:
	var m = MoveData.new()
	m.name = def.name
	m.power = def.get("power", 0)
	m.accuracy = def.get("accuracy", 100)
	m.type = def.get("type", "Physical")
	m.description = def.get("description", "")
	m.is_snipe = def.get("is_snipe", false)
	m.effects = def.get("effects", []) # Load generic effects
	m.cooldown = def.get("cooldown", 1)
	
	# FIX: Correct bad JSON data for Chain Reaction move
	if m.name == "Chain Reaction":
		var cleaned = []
		var has_mark = false
		for eff in m.effects:
			if eff.get("effect") == "chain_reaction" or (eff.get("type") == "status" and str(eff.get("status")).to_lower() == "chain_reaction"):
				continue
			if eff.get("type") == "status" and str(eff.get("status")).to_lower() == "chain_reaction_mark":
				has_mark = true
			cleaned.append(eff)
		if not has_mark:
			cleaned.append({ "type": "status", "status": "chain_reaction_mark", "duration": 3, "target": "Defender", "message": "%s is marked for a chain reaction!" })
		m.effects = cleaned
	m.hit_count = def.get("hit_count", 1)
	m.damage_scale = def.get("damage_scale", 1.0)
	if def.has("ignore_def_percent"):
		m.set_meta("ignore_def_percent", float(def["ignore_def_percent"]))
	if def.has("crit_bonus"):
		m.set_meta("crit_bonus", float(def["crit_bonus"]))
	if def.has("speed_scaling"):
		m.set_meta("speed_scaling", def["speed_scaling"])
	if def.has("bonus_damage_condition"):
		m.set_meta("bonus_damage_condition", def["bonus_damage_condition"])
	if def.has("damage_multiplier"):
		m.set_meta("damage_multiplier", float(def["damage_multiplier"]))
	
	var t_str = def.get("target_type", "Enemy")
	match t_str:
		"Self": m.target_type = MoveData.TargetType.SELF
		"Ally": m.target_type = MoveData.TargetType.ALLY
		_: m.target_type = MoveData.TargetType.ENEMY
	return m

# Executes a move and returns a result Dictionary describing what happened
func execute_move(attacker: BattleMonster, defender: BattleMonster, move: MoveData) -> Dictionary:
	var result = {
		"success": true,
		"damage": 0,
		"is_crit": false,
		"is_reaction": false,
		"hit": false,
		"messages": [],
		"effects": [] # List of effects applied
	}

	# 1. Accuracy Check
	var hit_chance = float(move.accuracy)
	
	if attacker.has_status("refracted") or attacker.has_status("insanity"):
		hit_chance -= 20.0
		
	# Illuminated status negates misses
	if defender.has_status("illuminated"):
		hit_chance = 1000.0
		
	if attacker.has_status("focused"):
		hit_chance += 20.0
	
	if hit_chance < 100 and randf() * 100 > hit_chance:
		result.success = false
		result.messages.append("Missed!")
		return result
	
	result.hit = true

	# 2. Handle Damage
	if move.power > 0:
		_calculate_damage(attacker, defender, move, result)

	# 3. Apply Data-Driven Effects (New System)
	_apply_data_driven_effects(attacker, defender, move, result)

	# 4. Apply Unique Effects defined by name (Legacy/Complex Logic)
	_apply_unique_effects(attacker, defender, move, result)

	# Creeping Entropy (Enemy Timer)
	if not attacker.is_player and result.hit and move.power > 0 and not attacker.has_status("suppressed"):
		var entropy_gain = 2
		var msg = ""
		if is_void(attacker.data.group):
			entropy_gain = 8 # Void generates more
			msg = "%s's void energy accelerates Entropy!" % attacker.data.monster_name
		
		result.effects.append({
			"effect": "add_global_entropy",
			"amount": entropy_gain
		})
		if msg != "":
			result.messages.append(msg)

	if result.is_reaction:
		result.effects.insert(0, { "effect": "critical_mass_boost" })
		var ng_count = 0
		if attacker.is_player and PlayerData:
			ng_count = PlayerData.get_combat_resonance(attacker.is_player, AtomicConfig.Group.NOBLE_GAS)
			
		var final_entropy = int(5.0 * (1.0 - (ng_count * 0.15)))
		if final_entropy > 0:
			result.effects.append({ "effect": "add_global_entropy", "amount": final_entropy })
			
	if attacker.has_status("suppressed"):
		for eff in result.effects:
			if eff.get("effect") == "add_global_entropy" and eff.get("amount", 0) > 0:
				eff["amount"] = 0

	return result

func _calculate_damage(attacker: BattleMonster, defender: BattleMonster, move: MoveData, result: Dictionary):
	# Use current battle stats from BattleMonster nodes
	var effective_attack = attacker.stats.attack
	var effective_defense = defender.stats.defense

	# Move-specific defense ignore

	var ignore_def = move.get_meta("ignore_def_percent", 0.0)
	
	if move.name == "X-Ray Impact":
		var tm_has_dots = false
		for eff in defender.active_effects:
			if eff.get("type") == "status" and eff.get("status") in ["poison", "radiation", "corrosion", "bio_poison"]:
				tm_has_dots = true
				break
		if tm_has_dots:
			ignore_def = 100.0
			result["bypasses_defenses"] = true
			result.messages.append("Catalyzed X-Ray bypasses all defenses!")
			
	if attacker.has_status("excited"):
		ignore_def = 100.0
		
	if move.name == "Sublimation Burst":
		var r_stacks = 0
		for eff in defender.active_effects:
			if eff.get("type") == "status" and eff.get("status") == "reduced":
				r_stacks = eff.get("stacks", 1)
				break
		ignore_def += r_stacks * 10.0
		
	if ignore_def > 100.0: ignore_def = 100.0
		
	if ignore_def > 0.0:
		effective_defense = int(effective_defense * (1.0 - (ignore_def / 100.0)))

	# Toxic Lattice
	if defender.has_status("toxic_lattice"):
		result.messages.append("Toxic Lattice reduced damage!")
		result.effects.append({
			"target": attacker,
			"effect": "add_status_stacks",
			"status": "reduced",
			"amount": 2,
			"duration": 3
		})

	# Formula: ((Base Attack * Scale) + Move Power) * Mitigation
	# Mitigation: 100 / (100 + Defense) -> Standard diminishing returns
	var raw_power = (effective_attack * move.damage_scale) + move.power
	
	if move.name == "Resonance Strike":
		var hp_bonus = attacker.current_hp * 0.2
		raw_power += hp_bonus
		result.messages.append("Resonance HP Bonus! (+%d)" % int(hp_bonus))
		
	var mitigation = (100.0 / (100.0 + effective_defense))
	var final_damage = raw_power * mitigation

	if defender.has_status("toxic_lattice"):
		final_damage *= 0.70
	
	# Conditional Bonus Damage
	var bonus_condition = move.get_meta("bonus_damage_condition", "")
	if bonus_condition == "debuffed":
		var has_debuff = false
		for effect in defender.active_effects:
			var is_debuff = false
			if effect.get("type") == "stat_mod" and effect.get("amount", 0) < 0:
				is_debuff = true
			elif effect.get("type") == "status":
				var s = str(effect.get("status", "")).to_lower()
				if effect.has("damage_multiplier") or s in ["poison", "stun", "silence_special", "vulnerable", "corrosion", "reactive_vapor", "radiation", "refracted", "insanity", "oxidized", "carbonized", "overload", "illuminated", "singularity_hazard", "chain_reaction_mark", "luminescent", "burn", "proton_charge", "spontaneous_fumes", "incendiary_flash", "contrast_shadow", "bio_poison", "decay_catalyst", "irradiated_lock", "smoke_detector", "law_of_octets", "mri_trace", "buff_lock", "suppressed", "inhibited"]:
					is_debuff = true
			if is_debuff:
				has_debuff = true
				break
		if has_debuff:
			var mult = move.get_meta("damage_multiplier", 1.0)
			var bonus = (final_damage * mult) - final_damage
			final_damage *= mult
			result.messages.append("Debuff Bonus! (+%d)" % int(bonus))
			result.is_reaction = true
			
	if move.name == "Unstable Mass":
		var multiplier = 1.0 + (current_global_entropy * 0.05)
		var bonus = (final_damage * multiplier) - final_damage
		final_damage *= multiplier
		result.messages.append("Unstable Mass Bonus! (+%d)" % int(bonus))
		
	if move.name == "Hyper-Mag Crush":
		var r_stacks = 0
		for eff in defender.active_effects:
			if eff.get("type") == "status" and eff.get("status") == "reduced":
				r_stacks = eff.get("stacks", 1)
				break
		if r_stacks > 0:
			var multiplier = 1.0 + (r_stacks * 0.25)
			var bonus = (final_damage * multiplier) - final_damage
			final_damage *= multiplier
			result.messages.append("Magnet Bonus! (+%d)" % int(bonus))

	if move.name == "Relativistic Impact":
		var multiplier = 1.0 + (current_global_entropy * 0.01)
		var bonus = (final_damage * multiplier) - final_damage
		final_damage *= multiplier
		result.messages.append("E=mc2 Bonus! (+%d)" % int(bonus))

	if move.name == "Final Chain":
		var multiplier = 1.0 + (current_global_entropy * 0.02)
		var bonus = (final_damage * multiplier) - final_damage
		final_damage *= multiplier
		
	if move.name == "Crystalline Cry":
		if defender.has_status("reduced"):
			var bonus = final_damage * 0.2
			final_damage *= 1.2
			result.messages.append("Resonated! (+%d)" % int(bonus))
			result.is_reaction = true
	
	# Speed Scaling (Einsteinium)
	if move.get_meta("speed_scaling", false):
		var spd_diff = max(0, attacker.stats.speed - defender.stats.speed)
		if spd_diff > 0:
			var multiplier = 1.0 + (spd_diff * 0.05) # 5% per point of speed difference
			var bonus = (final_damage * multiplier) - final_damage
			final_damage *= multiplier
			result.messages.append("Speed Bonus! (%.1fx)" % multiplier)
			

	# Critical Hit Calculation
	var crit_chance = attacker.stats.get("crit_chance", 5) + move.get_meta("crit_bonus", 0.0)
	var crit_mult = 1.5
	
	if move.name == "Alpha Strike":
		var tm_has_dots = false
		for eff in defender.active_effects:
			if eff.get("type") == "status" and eff.get("status") in ["poison", "radiation", "corrosion", "bio_poison"]:
				tm_has_dots = true
				break
		if tm_has_dots:
			crit_chance = 1000.0
			crit_mult += 0.5
			result.messages.append("Catalyzed Alpha Strike guarantees enhanced critical!")
			
	if randf() * 100.0 < crit_chance:
		# Mastery: Reactive Burst (Nonmetals)
		if attacker.data.group == AtomicConfig.Group.NONMETAL and attacker.data.stability >= 100:
			var will_burst = false
			for eff in defender.active_effects:
				if eff.get("type") == "status" and eff.get("status") == "reduced":
					will_burst = true
					break
			if will_burst:
				crit_mult += 0.25
				
		final_damage *= crit_mult
		result.is_crit = true
	
	# Check for physical resistance
	if move.type == "Physical" and not attacker.has_status("excited"):
		for effect in defender.active_effects:
			if effect.get("status") == "physical_resist":
				var reduction = effect.get("reduction_amount", 0.2)
				final_damage *= (1.0 - reduction)
				result.messages.append("Resisted Physical!")
				break # Apply only once
	
	# Check for special resistance
	if move.type == "Special" and not attacker.has_status("excited"):
		for effect in defender.active_effects:
			if effect.get("status") == "special_resist":
				var reduction = effect.get("reduction_amount", 0.2)
				final_damage *= (1.0 - reduction)
				result.messages.append("Resisted Special!")
				break # Apply only once
	
	# Check for damage-multiplying status effects on the defender
	if not defender.active_effects.is_empty():
		# Iterate backwards to safely queue removals
		for i in range(defender.active_effects.size() - 1, -1, -1):
			var effect = defender.active_effects[i]
			if effect.has("damage_multiplier"):
				var condition_met = true
				var condition = effect.get("condition")
				
				if condition == "cross_element":
					if attacker.data.group == defender.data.group:
						condition_met = false
				
				if condition_met:
					var multiplier = effect.get("damage_multiplier", 1.0)
					var bonus_dmg = (final_damage * multiplier) - final_damage
					final_damage *= multiplier
					
					var default_name = str(effect.get("status", "Reaction")).replace("_", " ").capitalize()
					var reaction_name = effect.get("reaction_name", default_name)
					result.messages.append("%s Bonus! (+%d Dmg)" % [reaction_name, int(bonus_dmg)])
					result.effects.append({ "target": defender, "effect": "remove_status", "status": effect.get("status") })
					result.is_reaction = true
					
	# Proton Charge Bonus
	var p_charge = 0
	for eff in defender.active_effects:
		if eff.get("type") == "status" and eff.get("status") == "proton_charge":
			p_charge = eff.get("stacks", 1)
			break
	if p_charge > 0:
		var mult = 1.0 + (p_charge * 0.10)
		var bonus_dmg = (final_damage * mult) - final_damage
		final_damage *= mult
		result.messages.append("Proton Charge Released! (+%d Dmg)" % int(bonus_dmg))
		result.effects.append({ "target": defender, "effect": "remove_status", "status": "proton_charge" })
		result.is_reaction = true

	# Tier 1 V.I.E. Passive: Oxidation Burst (Nonmetals)
	if (is_nonmetal(attacker.data.group) or move.name == "Fission Burst" or move.name == "Critical Detonation" or move.name == "Peacekeeper Burst") and move.power > 0 and move.name != "Logic Gate":
		var reduced_stacks = 0
		for eff in defender.active_effects:
			if eff.get("type") == "status" and eff.get("status") == "reduced":
				reduced_stacks = eff.get("stacks", 1)
				break
				
		if defender.has_status("mri_trace"):
			reduced_stacks = int(float(reduced_stacks) * 1.5)
			result.messages.append("MRI Trace amplifies [R] stacks!")
		
		if move.name == "Valence Flip":
			reduced_stacks += 1
			
		var processing_loops = 0
		for eff in defender.active_effects:
			if eff.get("type") == "status" and eff.get("status") == "processing_loop":
				processing_loops = eff.get("stacks", 1)
				break
				
		var has_luminescent = false
		for eff in defender.active_effects:
			if eff.get("type") == "status" and eff.get("status") == "luminescent":
				has_luminescent = true
				break
		
		if reduced_stacks > 0 or processing_loops > 0:
			var nonmetal_count = 0
			if PlayerData:
				for group in [AtomicConfig.Group.NONMETAL, AtomicConfig.Group.HALOGEN, AtomicConfig.Group.NOBLE_GAS, AtomicConfig.Group.METALLOID]:
					nonmetal_count += PlayerData.class_resonance.get(group, 0)
					
			var delta_x = 0.2 + (nonmetal_count * 0.05)
			
			if defender.has_status("smoke_detector"):
				delta_x += 0.50
				result.effects.append({"target": defender, "effect": "remove_status", "status": "smoke_detector"})
				
			if attacker.has_status("hidden_potential"):
				delta_x += 0.30
				result.effects.append({"target": attacker, "effect": "remove_status", "status": "hidden_potential"})
				result.messages.append("Hidden Potential amplifies the burst!")
			
			# Tier 2 V.I.E. Passive: Reactive Hunger (Halogens)
			if attacker.data.group == AtomicConfig.Group.HALOGEN:
				var halogen_count = 0
				if PlayerData:
					halogen_count = PlayerData.get_combat_resonance(attacker.is_player, AtomicConfig.Group.HALOGEN)
				delta_x += (0.1 * halogen_count)
				
			var burst_multiplier = 1.0 + (delta_x * reduced_stacks) + (0.1 * processing_loops)
			
			if move.name == "Valence Flip":
				burst_multiplier += 0.20
				
			if move.name == "Fission Burst":
				burst_multiplier += (0.20 * reduced_stacks)
				if current_global_entropy >= 50:
					burst_multiplier *= 2.0
				
				if reduced_stacks > 0:
					var base_ent = 10 * reduced_stacks
					var ng_count = 0
					if attacker.is_player and PlayerData:
						ng_count = PlayerData.get_combat_resonance(attacker.is_player, AtomicConfig.Group.NOBLE_GAS)
					var final_ent = int(base_ent * max(0.10, 1.0 - (ng_count * 0.15)))
					if final_ent > 0:
						result.effects.append({ "effect": "add_global_entropy", "amount": final_ent })
				
			if move.name == "Catenation Chain" and reduced_stacks >= 3:
				burst_multiplier *= 2.0
				result.messages.append("Catenation Chain Doubled!")
				
			if has_luminescent:
				burst_multiplier += 0.50
			
			if defender.has_status("law_of_octets"):
				burst_multiplier *= 2.0
				result.effects.append({"target": defender, "effect": "remove_status", "status": "law_of_octets"})
				result.messages.append("Law of Octets Doubled Burst!")
			
			if move.name == "Cryogenic Lock":
				var stun_chance = 0.20 + (0.10 * reduced_stacks)
				if randf() < stun_chance:
					result.effects.append({ "target": defender, "status": "stun", "duration": 1, "type": "status" })
					result.messages.append("Cryogenic Freeze!")
					
			if move.name == "Rapid Combustion" and reduced_stacks > 0:
				var burn_dmg = delta_x * 0.10 # Burn scales off 10% delta_x
				result.effects.append({ "target": defender, "status": "burn", "duration": reduced_stacks, "damage_percent": burn_dmg, "type": "status" })
				result.messages.append("Target ignited!")
				
			if move.name == "Vulcanization" and reduced_stacks > 0:
				var def_drop = min(50, 5 * reduced_stacks)
				result.effects.append({ "target": defender, "stat": "defense", "amount": -def_drop, "percent": true, "duration": 99, "type": "stat_mod" })
				result.messages.append("Defense shredded by %d%%!" % def_drop)
				
			if move.name == "Hydrofluoric Etch" and reduced_stacks > 0:
				var def_drop = min(100, 10 * reduced_stacks)
				result.effects.append({ "target": defender, "stat": "defense", "amount": -def_drop, "percent": true, "duration": 99, "type": "stat_mod" })
				result.messages.append("Defense etched away by %d%%!" % def_drop)
				
			if move.name == "Oxidizing Bleach" and reduced_stacks > 0:
				var is_poisoned = defender.has_status("poison")
				var poison_dmg = 0.05 * reduced_stacks
				if is_poisoned:
					poison_dmg *= 2.0
					result.messages.append("Bleach reacts with Poison! (Double Damage)")
				result.effects.append({ "target": defender, "status": "poison", "duration": 3, "damage_percent": poison_dmg, "type": "status" })
				
			if move.name == "Halon Extinguisher" and reduced_stacks > 0:
				result.effects.append({ "target": defender, "effect": "reset_atb" })
				result.messages.append("Action Gauge extinguished!")
				
			if move.name == "Sublimation Burst" and reduced_stacks > 0:
				result.messages.append("Sublimation bypassed %d%% Defense!" % (reduced_stacks * 10))
				
			if move.name == "Short-Lived Decay" and reduced_stacks > 0:
				result.effects.append({ "target": defender, "status": "radiation", "damage_percent": 0.05, "duration": 3, "type": "status" })
				result.effects.append({ "target": defender, "status": "poison", "damage_percent": 0.1, "duration": 3, "type": "status" })
				result.messages.append("Toxic decay applied!")
				
			if move.name == "Relativistic Siphon" and reduced_stacks > 0:
				result.effects.append({ "target": attacker, "effect": "add_atb", "amount": 10.0 * reduced_stacks })
				result.messages.append("Siphoned %d%% Action Gauge!" % (10 * reduced_stacks))
				
			if move.name == "Protanation Drive" and reduced_stacks > 0:
				result.effects.append({ "target": defender, "effect": "add_status_stacks", "status": "proton_charge", "amount": reduced_stacks, "duration": 3 })
				result.messages.append("Converted to %d Proton Charges!" % reduced_stacks)
			
			if move.name == "Valence Siphon" and reduced_stacks > 0:
				var spd_drop = 10 * reduced_stacks
				result.effects.append({ "target": defender, "stat": "speed", "amount": -spd_drop, "percent": true, "duration": 2, "type": "stat_mod" })
				result.messages.append("Valence Siphoned! Speed -%d%%!" % spd_drop)
				
			if move.name == "Oxidation Chain" and reduced_stacks > 0:
				result.effects.append({ "effect": "oxidation_chain", "target": defender })
			
			var bonus_dmg = (final_damage * burst_multiplier) - final_damage
			
			result["r_stacks_consumed"] = reduced_stacks
			result["base_damage"] = int(final_damage)
			result["burst_multiplier"] = burst_multiplier
			final_damage *= burst_multiplier
			
			if move.name == "Critical Detonation":
				var rad_pct = (final_damage * 0.5) / max(defender.max_hp, 1)
				result.effects.append({ "target": defender, "status": "radiation", "duration": 3, "damage_percent": rad_pct, "type": "status" })
				result.messages.append("Radiation released!")
				
			if move.name == "Transuranic Decay":
				result.effects.append({ "effect": "transuranic_decay" })
			
			result.messages.append("BURST! %.1fx Dmg!" % burst_multiplier)
			if move.name != "Peacekeeper Burst" and not defender.has_status("irradiated_lock"):
				result.effects.append({ "target": defender, "effect": "remove_status", "status": "reduced" })
			if processing_loops > 0:
				result.effects.append({ "target": defender, "effect": "remove_status", "status": "processing_loop" })
			if has_luminescent:
				result.effects.append({ "target": defender, "effect": "remove_status", "status": "luminescent" })
				
			if attacker.has_status("halogen_hunger"):
				result.effects.append({ "target": attacker, "effect": "add_atb", "amount": 20.0 })
				result.messages.append("%s reacts to the burst! (+20%% ATB)" % attacker.data.monster_name)
				
			if move.name == "Selenium Semiconductor":
				result.effects.append({ "effect": "excited_on_kill", "target": attacker, "damage_dealt": final_damage })
				
			if attacker.data.group == AtomicConfig.Group.ACTINIDE and reduced_stacks > 1:
				result.effects.append({ "effect": "chain_decay_jump", "target": defender, "amount": int(reduced_stacks / 2) })
				
			result.is_reaction = true
			
	if move.name == "Ion Battery" and attacker.data.stability >= 100:
		result.effects.append({"effect": "team_add_atb", "amount": 15.0})
		
	if move.name == "Solvation Burst":
		var has_vapor = false
		for eff in defender.active_effects:
			if eff.get("status") == "reactive_vapor":
				has_vapor = true
				break
		if has_vapor:
			var bonus = final_damage
			final_damage *= 2.0
			result.messages.append("Solvation Burst Doubled! (+%d Dmg)" % int(bonus))
			result.effects.append({"effect": "add_status_stacks", "status": "reduced", "amount": 2, "duration": 3, "target": "Defender"})
			
	# Alkaline Earth Synergy: Crystalline Lattice
	if defender.data.group == AtomicConfig.Group.ALKALINE_EARTH:
		var ae_count = 0
		if PlayerData:
			ae_count = PlayerData.get_combat_resonance(defender.is_player, AtomicConfig.Group.ALKALINE_EARTH)
		
		if ae_count > 0:
			var reduced_stacks = 0
			for eff in attacker.active_effects:
				if eff.get("type") == "status" and eff.get("status") == "reduced":
					reduced_stacks = eff.get("stacks", 1)
					break
			
			if reduced_stacks > 0:
				var reduction_pct = min(0.9, (ae_count * 0.01) * reduced_stacks) # Cap at 90% reduction
				var reduced_amt = final_damage * reduction_pct
				final_damage -= reduced_amt
				if reduced_amt > 0:
					result.messages.append("Crystalline Lattice! (-%d Dmg)" % int(reduced_amt))
	
	# Message for generic crits (if not handled by Full Set message)
	if result.is_crit and not "Full Set Critical!" in result.messages:
		result.messages.append("Critical Hit!")
	
	# Variance +/- 10%
	final_damage *= randf_range(0.9, 1.1)
	
	result.damage = int(final_damage)

func _apply_data_driven_effects(attacker: BattleMonster, defender: BattleMonster, move: MoveData, result: Dictionary):
	for effect_def in move.effects:
		# Determine Target
		var target_scope = effect_def.get("target", "Defender") # "Defender", "Attacker"
		var target = defender if target_scope == "Defender" else attacker
		
		# Check Condition
		if effect_def.has("condition_status"):
			if not target.has_status(effect_def.get("condition_status")):
				continue

		# Check chance
		var chance = effect_def.get("chance", 1.0)
		if randf() > chance: continue
		
		# Build effect dictionary for BattleManager
		var effect = effect_def.duplicate()
		
		# Critical Hit Check for Heals and Shields
		if effect.get("effect") in ["heal", "heal_overflow_shield", "add_shield", "add_team_shield", "team_heal"]:
			var crit_chance = attacker.stats.get("crit_chance", 5)
			if randf() * 100.0 < crit_chance:
				effect["is_crit"] = true
				# We apply the multiplier later when amount is resolved or modify it here if possible.
				# Since 'amount' might be percentage or scaled, we can tag it and handle multiplication here if it's flat, or flag it.
				
		# Resolve relative values (e.g. "amount": 20 with "percent": true)
		if effect.get("type") == "stat_mod":
			if effect.get("percent", false):
				var stat_name = effect.get("stat")
				var base_val = target.stats.get(stat_name, 10)
				effect["amount"] = int(base_val * (effect.get("amount") / 100.0))
				
		# Resolve scaling based on attacker stats (e.g. Shield scaling with Defense)
		if effect.has("scale_stat"):
			var stat_name = effect.get("scale_stat")
			var stat_val = 0
			if stat_name == "missing_hp":
				stat_val = max(0, attacker.max_hp - attacker.current_hp)
			elif stat_name == "damage_dealt":
				stat_val = result.damage
			else:
				stat_val = attacker.stats.get(stat_name, 0)
				
			var factor = float(effect.get("scale_factor", 1.0))
			effect["amount"] = int(stat_val * factor)

		# Apply Crit Multiplier to resolved amount if applicable
		if effect.get("is_crit", false):
			effect["amount"] = int(effect.get("amount", 0) * 1.5)

		# Add specific target reference for BattleManager
		effect["target"] = target
		
		# Add to result
		result.effects.append(effect)
		
		# Add generic message if provided
		if effect.has("message"):
			var msg = effect.message
			if "%s" in msg:
				result.messages.append(msg % target.data.monster_name)
			else:
				result.messages.append(msg)
		else:
			# Generate generic message based on type
			_generate_effect_message(target, effect, result)

func _generate_effect_message(target: BattleMonster, effect: Dictionary, result: Dictionary):
	var type = effect.get("type")
	if type == "status":
		var status = effect.get("status")
		if status:
			result.messages.append("%s applied!" % status.capitalize().replace("_", " "))
	elif type == "stat_mod":
		var stat = effect.get("stat")
		var amt = effect.get("amount")
		var verb = "Rose" if amt > 0 else "Fell"
		result.messages.append("%s %s!" % [stat.capitalize(), verb])

func _apply_unique_effects(attacker: BattleMonster, defender: BattleMonster, move: MoveData, result: Dictionary):
	
	# --- Class On-Hit Effects ---
	
	# Metalloid: Stun
	if attacker.data.group == AtomicConfig.Group.METALLOID:
		var chance = 0.10
			
		if randf() < chance:
			result.effects.append({ "target": defender, "status": "stun", "duration": 1, "type": "status" })
			
	# Tier 1 V.I.E. Passive: Enthalpy Burst (Alkali Metals)
	if attacker.data.group == AtomicConfig.Group.ALKALI_METAL and result.hit and move.power > 0:
		var has_vapor = false
		for eff in defender.active_effects:
			if eff.get("type") == "status" and eff.get("status") in ["reactive_vapor", "corrosion", "poison"]:
				has_vapor = true
				break
				
		if has_vapor:
			var alkali_count = 0
			if PlayerData:
				alkali_count = PlayerData.get_combat_resonance(attacker.is_player, AtomicConfig.Group.ALKALI_METAL)
			
			var burst_mult = 1.0 + (alkali_count * 0.20)
			var burst_dmg = int(result.damage * burst_mult)
			
			result.effects.append({
				"effect": "enthalpy_burst",
				"target": defender,
				"amount": burst_dmg
			})
			result.is_reaction = true
			
	# Tier 1 V.I.E. Passive: Catalysis (Transition Metals)
	if attacker.data.group == AtomicConfig.Group.TRANSITION_METAL and result.hit and move.power > 0:
		var has_dots = false
		for eff in defender.active_effects:
			if eff.get("type") == "status":
				var s = eff.get("status", "")
				if s in ["poison", "radiation", "corrosion", "bio_poison"]:
					has_dots = true
					break
		
		if has_dots:
			var tm_count = 0
			if PlayerData:
				tm_count = PlayerData.get_combat_resonance(attacker.is_player, AtomicConfig.Group.TRANSITION_METAL)
			
			var ticks = 1
				
			var dmg_mult = 1.0 + (tm_count * 0.02)
				
			result.effects.append({
				"effect": "catalyst_tick",
				"target": defender,
				"ticks": ticks,
				"multiplier": dmg_mult
			})
			result.messages.append("%s catalyzed the reactions!" % attacker.data.monster_name)
			result.is_reaction = true
			
			# --- Transition Metal DoT Consumption Bonuses ---
			match move.name:
				"Light-Alloy Strike":
					result.effects.append({"target": attacker, "stat": "defense", "amount": 15, "percent": true, "duration": 2, "type": "stat_mod"})
					result.messages.append("Catalyzed defense boost!")
				"Hardened Bash":
					result.effects.append({"target": attacker, "stat": "defense", "amount": 15, "percent": true, "duration": 2, "type": "stat_mod"})
					result.messages.append("Catalyzed defense boost!")
				"Refined Edge":
					result.effects.append({"target": attacker, "status": "focused", "duration": 2, "type": "status"})
					result.messages.append("Catalyzed accuracy boost!")
				"Mirror Luster":
					result.effects.append({"effect": "add_shield_vanguard", "amount": 0.1})
					result.messages.append("Catalyzed Vanguard Shield!")
				"Magnetic Slam":
					result.effects.append({"target": defender, "effect": "add_status_stacks", "status": "reduced", "amount": 1, "duration": 3})
					result.messages.append("Catalyzed extra [R] stack!")
				"Blue-Steel Guard":
					var shield_amt = int(result.damage * 0.25)
					result.effects.append({"effect": "add_shield", "amount": shield_amt, "target": attacker})
					result.messages.append("Catalyzed shield generation!")
				"Plated Impact":
					result.effects.append({"target": defender, "stat": "speed", "amount": -10, "percent": true, "duration": 2, "type": "stat_mod"})
					result.messages.append("Catalyzed speed reduction!")
				"Conductive Whip":
					result.effects.append({"target": attacker, "effect": "add_atb", "amount": 15.0})
					result.messages.append("Catalyzed action gauge boost!")
				"Galvanized Bash":
					result.effects.append({"effect": "team_add_atb", "amount": 10.0})
					result.messages.append("Catalyzed team action gauge boost!")
				"Luminescent Arc":
					result.effects.append({"effect": "spread_r_to_neighbors", "target": defender})
					result.messages.append("Catalyzed [R] stack spread!")
				"Gemstone Guard":
					result.effects.append({"effect": "add_global_entropy", "amount": -10})
					result.messages.append("Catalyzed stability restoration!")
				"Super-Conduct":
					result.effects.append({"effect": "reduce_cooldowns", "amount": 1, "target": attacker})
					result.messages.append("Catalyzed cooldown reduction!")
				"Heat-Sink Bash":
					result.effects.append({"effect": "add_global_entropy", "amount": -5})
					result.messages.append("Catalyzed entropy reduction!")
				"Isotope Pulse":
					for eff in result.effects:
						if eff.get("effect") == "catalyst_tick":
							eff["multiplier"] *= 2.0
					result.messages.append("Catalyzed DoT damage doubled!")
				"Catalytic Blast":
					result.effects.append({"target": defender, "effect": "add_status_stacks", "status": "reduced", "amount": 1, "duration": 3})
					result.messages.append("Catalyzed extra [R] stack!")
				"Reflective Shell":
					for eff in result.effects:
						if eff.get("status") == "reflective_shell" and eff.get("target") == attacker:
							eff["damage_percent"] = 0.6
					result.messages.append("Catalyzed double reflection!")
				"H-Absorb Shield":
					for eff in result.effects:
						if eff.get("status") == "absorb_shield" and eff.get("target") == attacker:
							eff["effect"] = "team_status"
							eff["target_team"] = "ally"
					result.messages.append("Catalyzed team absorb shield!")
				"Sterling Flash":
					result.effects.append({"target": attacker, "effect": "add_atb", "amount": 20.0})
					result.messages.append("Catalyzed action gauge boost!")
				"Neutron Dampener":
					result.effects.append({"target": defender, "status": "suppressed", "duration": 2, "type": "status"})
					result.messages.append("Catalyzed suppression!")
				"Control-Rod Bash":
					result.effects.append({"target": defender, "status": "inhibited", "duration": 2, "type": "status"})
					result.messages.append("Catalyzed inhibition!")
				"Capacitor Discharge":
					result.effects.append({"target": attacker, "effect": "add_atb", "amount": 15.0})
					result.messages.append("Catalyzed action gauge boost!")
				"Heavy-Density Slam":
					result.effects.append({"target": defender, "effect": "true_damage_percent", "percent": 0.1})
					result.messages.append("Catalyzed heavy density true damage!")
				"Super-Alloy Reinforce":
					result.effects.append({"effect": "buff_vanguard_stat", "stat": "defense", "amount": 20, "duration": 2, "percent": true})
					result.messages.append("Catalyzed Vanguard defense boost!")
				"Osmium Pressure":
					result.effects.append({"target": defender, "effect": "add_status_stacks", "status": "reduced", "amount": 2, "duration": 3})
					result.messages.append("Catalyzed extra [R] stacks!")
				"Iridescent Guard":
					for eff in result.effects:
						if eff.get("status") == "static_reflection" and eff.get("target") == attacker:
							eff["damage_percent"] = 1.0
					result.messages.append("Catalyzed full reflection!")
				"Noble Catalyst":
					result.effects.append({"effect": "team_reduce_cooldowns", "amount": 1})
					result.messages.append("Catalyzed team cooldown reduction!")
				"Aurum Radiance":
					for eff in result.effects:
						if eff.get("effect") == "team_heal":
							eff["amount"] *= 2
					result.effects.append({"effect": "add_global_entropy", "amount": -5})
					result.messages.append("Catalyzed golden radiance!")
				"Liquid Metal Coil":
					# Insert at index 0 so it pulls the DoT data BEFORE catalyst_tick burns them out
					result.effects.insert(0, {"effect": "spread_random_dot_from_target", "target": defender})
					result.messages.append("Catalyzed toxic spread!")
				"Alpha Strike":
					pass # Handled during damage calc
				"Nucleus Hammer":
					result.effects.append({"effect": "set_global_entropy", "amount": 0})
					result.messages.append("Catalyzed entropy reset!")
				"Seaborg Shell":
					result.effects.append({"effect": "team_status", "status": "dot_block", "duration": 99, "target_team": "ally"})
					result.messages.append("Catalyzed Team Radiation Shield!")
				"Resonance Blade":
					result.effects.append({"effect": "team_add_atb", "amount": 15.0})
					result.messages.append("Catalyzed team action gauge boost!")
				"High-Density Pulse":
					result.effects.append({"target": defender, "status": "inhibited", "duration": 2, "type": "status"})
					result.messages.append("Catalyzed inhibition!")
				"Fission Strike":
					for eff in result.effects:
						if eff.get("effect") == "splash_damage":
							eff["percent"] = 1.0
					result.effects.append({"effect": "aoe_status", "status": "reduced", "amount": 1, "duration": 3, "target_team": "enemy"})
					result.messages.append("Catalyzed full splash and [R] spread!")
				"Synthetic Overdrive":
					result.effects.append({"effect": "heal_percent", "target": attacker, "amount": 0.15})
					result.messages.append("Catalyzed self heal!")
				"X-Ray Impact":
					pass # Handled during damage calc
				"Orbital Smash":
					for eff in result.effects:
						if eff.get("effect") == "reset_cooldowns":
							eff["chance"] = 1.0
					result.messages.append("Catalyzed full cooldown reset!")
			
	# Trigger chain reaction mark
	if result.hit and move.power > 0:
		for effect in defender.active_effects:
			if effect.get("status") == "chain_reaction_mark":
				result.effects.append({ "effect": "chain_reaction", "amount": result.damage })
				result.effects.append({ "target": defender, "effect": "remove_status", "status": "chain_reaction_mark" })
				result.is_reaction = true
				break # Only trigger once per hit
				
	# Tier 1 V.I.E. Passive: Electron Donor (Metals)
	if is_metal(attacker.data.group) and result.hit and move.power > 0:
		result.effects.append({
			"target": defender,
			"effect": "add_status_stacks",
			"status": "reduced",
			"amount": 1,
			"duration": 3
		})
		result.messages.append("Primed! (+1 [R])")

	# Tier 2 V.I.E. Passive: Reaction Buffer (Alkaline Earth)
	if defender.data.group == AtomicConfig.Group.ALKALINE_EARTH and result.hit and move.power > 0:
		var chance = 0.25
		if randf() < chance:
			result.effects.append({
				"target": attacker,
				"effect": "add_status_stacks",
				"status": "reduced",
				"amount": 1,
				"duration": 3
			})
			result.messages.append("%s's buffer primed the attacker! (+1 [R])" % defender.data.monster_name)

	# Tier 2 V.I.E. Passive: Magnetic Pull (Lanthanides)
	if attacker.data.group == AtomicConfig.Group.LANTHANIDE and result.hit and move.power > 0:
		var lanth_count = 0
		if PlayerData:
			lanth_count = PlayerData.get_combat_resonance(attacker.is_player, AtomicConfig.Group.LANTHANIDE)
			
		result.effects.append({
			"effect": "magnetic_pull",
			"target": defender,
			"lanth_count": lanth_count,
			"catalytic_purge": move.name == "Self-Clean Bash"
		})

	# Mastery Effects (100% Stability)
	if attacker.data.stability >= 100:
		_apply_mastery_on_hit(attacker, defender, move, result)

	match move.name:
		"Logic Gate":
			var r_stacks = 0
			for eff in defender.active_effects:
				if eff.get("type") == "status" and eff.get("status") == "reduced":
					r_stacks = eff.get("stacks", 1)
					break
					
			if r_stacks > 0:
				result.effects.append({ "target": defender, "effect": "remove_status", "status": "reduced" })
				result.effects.append({ "target": defender, "effect": "add_status_stacks", "status": "processing_loop", "amount": r_stacks, "duration": 3 })
				result.messages.append("%d [R] stack(s) converted to Processing Loops!" % r_stacks)
				
		"Alloy Reinforce":
			# Heals the target
			var heal_amount = int(attacker.stats.attack * 1.5)
			result.effects.append({ "target": defender, "effect": "heal_overflow_shield", "amount": heal_amount })
			result.messages.append("%s repairs the structure!" % attacker.data.monster_name)
			
		"Liquid Melting":
			if current_global_entropy >= 30:
				var heal_amt = int(attacker.max_hp * 0.1)
				result.effects.append({ "target": attacker, "effect": "heal", "amount": heal_amt })
				result.messages.append("%s absorbs the chaotic energy!" % attacker.data.monster_name)
				
		"Stabilizing Pulse":
			result.effects.append({ "effect": "stabilize_entropy", "target": attacker })
		"Perfect Configuration":
			result.effects.append({ "effect": "add_global_entropy", "amount": -20 })
			
		"Paramagnetic Pull":
			result.effects.append({ "target": defender, "status": "vulnerable", "duration": 2, "type": "status" })
			result.messages.append("%s is magnetized!" % defender.data.monster_name)
			
		"Photonic Bash":
			if attacker.has_status("anodic_barrier"):
				result.effects.append({ "target": defender, "status": "stun", "duration": 1, "type": "status" })
				result.messages.append("%s was blinded!" % defender.data.monster_name)
			
		"Reactive Vapor":
			result.effects.append({ "effect": "team_status", "status": "reactive_vapor", "duration": 3, "type": "status" })
			result.messages.append("%s fills the area with reactive vapor!" % attacker.data.monster_name)

		"Obliterate":
			result.messages.append("%s unleashes void energy!" % attacker.data.monster_name)
			
		"Void Scratch":
			result.messages.append("%s claws with void energy!" % attacker.data.monster_name)
			
		"Heavy Slam":
			result.messages.append("%s slams with heavy force!" % attacker.data.monster_name)
			
		"Meltdown":
			var aoe_dmg = int(attacker.stats.attack * 1.5)
			result.effects.append({ "effect": "meltdown", "amount": aoe_dmg })
			result.messages.append("%s goes critical!" % attacker.data.monster_name)
			
		"Entropy":
			result.effects.append({ "effect": "add_global_entropy", "amount": 15 })
			result.messages.append("%s unleashes pure chaos!" % attacker.data.monster_name)
			
		"Cosmic Horror":
			var spd_loss = int(defender.stats.speed * 0.3)
			result.effects.append({ "target": defender, "stat": "speed", "amount": -spd_loss, "duration": 3, "type": "stat_mod" })
			result.effects.append({ "target": defender, "status": "insanity", "duration": 3, "type": "status" })
			result.messages.append("%s's mind fractures!" % defender.data.monster_name)
			
		"Madness Aura":
			result.effects.append({ "effect": "madness_aura" })
			result.messages.append("%s emits a wave of madness!" % attacker.data.monster_name)
			
		"Reality Break":
			result.messages.append("Reality shatters around %s!" % defender.data.monster_name)
			
		"Scramble":
			result.effects.append({ "effect": "scramble_team", "target": defender })
			result.messages.append("%s scrambles the formation!" % attacker.data.monster_name)
			
		"Hive Mind":
			result.effects.append({ "effect": "call_reinforcements", "target": attacker })
			result.messages.append("%s calls the swarm!" % attacker.data.monster_name)
			
		"Pheromones":
			result.effects.append({ "effect": "pheromones" })
			result.messages.append("%s releases pheromones!" % attacker.data.monster_name)
			
		"Lead Wall":
			var shield_amount = int(attacker.max_hp * 0.5)
			result.effects.append({ "target": attacker, "effect": "add_shield", "amount": shield_amount })
			result.messages.append("%s erects a lead barrier!" % attacker.data.monster_name)
			
		"Gamma Ray":
			result.messages.append("%s fires a precise gamma burst!" % attacker.data.monster_name)
			
		"Neurotoxin":
			result.effects.append({ "target": defender, "status": "poison", "damage_percent": 0.1, "duration": 3, "type": "status" })
			result.messages.append("%s injects a deadly toxin!" % attacker.data.monster_name)
			
		"Tentacle Crush":
			result.messages.append("%s crushes with a tentacle!" % attacker.data.monster_name)
			
		"Chitin Shell":
			var shield_amount = int(attacker.max_hp * 0.3)
			result.effects.append({ "target": attacker, "effect": "add_shield", "amount": shield_amount })
			var def_amount = int(attacker.stats.defense * 0.3)
			result.effects.append({ "target": attacker, "stat": "defense", "amount": def_amount, "duration": 3, "type": "stat_mod" })
			result.messages.append("%s hardens its carapace!" % attacker.data.monster_name)
			
		"Psychic Knife":
			result.messages.append("%s projects a mental blade!" % attacker.data.monster_name)
			
		"Mind Poke":
			result.messages.append("%s pokes the mind!" % attacker.data.monster_name)
			
		"Glitch Hit":
			result.messages.append("%s glitches out!" % attacker.data.monster_name)
			
		"Rad Bite":
			result.messages.append("%s bites with radiation!" % attacker.data.monster_name)
			
		"Mandible Bite":
			result.messages.append("%s snaps its mandibles!" % attacker.data.monster_name)
			
		"Pixel Stab":
			result.messages.append("%s stabs with a pixelated blade!" % attacker.data.monster_name)
			
		"Shadow Strike":
			result.messages.append("%s strikes from the shadows!" % attacker.data.monster_name)
			
		"Incendiary Flash":
			var is_vanguard = false
			if attacker.get_parent() and ("Center" in attacker.get_parent().name or "Slot2" in attacker.get_parent().name):
				is_vanguard = true
			if is_vanguard:
				result.effects.append({ "target": defender, "status": "incendiary_flash", "duration": 3, "type": "status" })
				result.messages.append("Target marked by Incendiary Flash!")
				
		"Toxic Lattice":
			result.messages.append("%s formed a Toxic Lattice!" % attacker.data.monster_name)
		"Bone Structure":
			result.messages.append("%s reinforced the team's Bone Structure!" % attacker.data.monster_name)
		"Crimson Resonance":
			result.messages.append("%s hums with Crimson Resonance!" % attacker.data.monster_name)
		"Contrast Shadow":
			result.messages.append("%s paints a Contrast Shadow on the target!" % attacker.data.monster_name)
		"Radiant Nucleus":
			result.messages.append("%s initiates a heavy radioactive cycle!" % attacker.data.monster_name)
			
		"Light-Alloy Strike":
			result.messages.append("%s strikes with a light alloy!" % attacker.data.monster_name)
		"Hardened Bash":
			result.messages.append("%s bashes with hardened metal!" % attacker.data.monster_name)
		"Refined Edge":
			result.messages.append("%s slices with a refined edge!" % attacker.data.monster_name)
		"Mirror Luster":
			result.messages.append("%s attacks with a blinding luster!" % attacker.data.monster_name)
		"Magnetic Slam":
			result.messages.append("%s slams with magnetic force!" % attacker.data.monster_name)
		"Blue-Steel Guard":
			result.messages.append("%s strikes with a Blue-Steel Guard!" % attacker.data.monster_name)
		"Plated Impact":
			result.messages.append("%s strikes with a Plated Impact!" % attacker.data.monster_name)
		"Conductive Whip":
			result.messages.append("%s lashes with a Conductive Whip!" % attacker.data.monster_name)
		"Galvanized Bash":
			result.messages.append("%s strikes with a Galvanized Bash!" % attacker.data.monster_name)
			
		"Luminescent Arc":
			result.messages.append("%s arcs with luminescence!" % attacker.data.monster_name)
		"Gemstone Guard":
			result.messages.append("%s strikes from behind a Gemstone Guard!" % attacker.data.monster_name)
		"Super-Conduct":
			result.messages.append("%s attacks with super-conductive speed!" % attacker.data.monster_name)
		"Heat-Sink Bash":
			result.messages.append("%s bashes with a Heat-Sink!" % attacker.data.monster_name)
		"Isotope Pulse":
			result.messages.append("%s releases an Isotope Pulse!" % attacker.data.monster_name)
			
		"Catalytic Blast":
			result.messages.append("%s triggers a Catalytic Blast!" % attacker.data.monster_name)
		"Reflective Shell":
			result.messages.append("%s creates a Reflective Shell!" % attacker.data.monster_name)
		"H-Absorb Shield":
			result.messages.append("%s generates an H-Absorb Shield!" % attacker.data.monster_name)
		"Sterling Flash":
			result.messages.append("%s strikes with a Sterling Flash!" % attacker.data.monster_name)
		"Neutron Dampener":
			result.messages.append("%s engages the Neutron Dampener!" % attacker.data.monster_name)
			
		"Control-Rod Bash":
			result.messages.append("%s bashes with a control rod!" % attacker.data.monster_name)
		"Capacitor Discharge":
			result.messages.append("%s discharges stored energy!" % attacker.data.monster_name)
		"Heavy-Density Slam":
			result.messages.append("%s slams with extreme density!" % attacker.data.monster_name)
		"Super-Alloy Reinforce":
			result.messages.append("%s attacks while reinforcing alloy plating!" % attacker.data.monster_name)
		"Osmium Pressure":
			result.messages.append("%s applies crushing pressure!" % attacker.data.monster_name)
			
		"Iridescent Guard":
			result.messages.append("%s raises an Iridescent Guard!" % attacker.data.monster_name)
		"Noble Catalyst":
			result.messages.append("%s strikes as a Noble Catalyst!" % attacker.data.monster_name)
		"Aurum Radiance":
			result.messages.append("%s shines with Aurum Radiance!" % attacker.data.monster_name)
		"Liquid Metal Coil":
			result.messages.append("%s strikes with a Liquid Metal Coil!" % attacker.data.monster_name)
			
		"Alpha Strike":
			result.messages.append("%s strikes with alpha particles!" % attacker.data.monster_name)
		"Nucleus Hammer":
			result.messages.append("%s brings down the Nucleus Hammer!" % attacker.data.monster_name)
		"Seaborg Shell":
			result.messages.append("%s reinforces with a Seaborg Shell!" % attacker.data.monster_name)
		"Resonance Blade":
			result.messages.append("%s slashes with a Resonance Blade!" % attacker.data.monster_name)
		"High-Density Pulse":
			result.messages.append("%s emits a High-Density Pulse!" % attacker.data.monster_name)
		"Fission Strike":
			result.messages.append("%s strikes with Fission force!" % attacker.data.monster_name)
		"Synthetic Overdrive":
			result.messages.append("%s enters Synthetic Overdrive!" % attacker.data.monster_name)
		"X-Ray Impact":
			result.messages.append("%s hits with an X-Ray Impact!" % attacker.data.monster_name)
		"Orbital Smash":
			result.messages.append("%s unleashes an Orbital Smash!" % attacker.data.monster_name)
			
		"Hydrofluoric Etch":
			result.messages.append("%s fires a corrosive beam!" % attacker.data.monster_name)
		"Halon Extinguisher":
			result.messages.append("%s deploys fire suppressant!" % attacker.data.monster_name)
		"Relativistic Siphon":
			result.messages.append("%s siphons atomic energy!" % attacker.data.monster_name)

		"Control Array":
			result.messages.append("%s establishes a Control Array!" % attacker.data.monster_name)
		"Integrated Circuit":
			result.messages.append("%s links the team's circuitry!" % attacker.data.monster_name)
		"Transistor Gate":
			result.messages.append("%s routes action through the Vanguard!" % attacker.data.monster_name)
		"Doped Lattice":
			result.messages.append("%s dopes the target's debuffs!" % attacker.data.monster_name)
		"Thermal Barrier":
			result.messages.append("%s deploys a Thermal Barrier!" % attacker.data.monster_name)
		"P-N Junction":
			result.messages.append("%s converts Entropy into shields!" % attacker.data.monster_name)
		"Alpha Fission":
			result.messages.append("%s strikes with Radioactive force!" % attacker.data.monster_name)
			
		"Solar Vent":
			result.messages.append("%s vents solar energy!" % attacker.data.monster_name)
		"Anaesthetic Cloud":
			result.messages.append("%s releases an Anaesthetic Cloud!" % attacker.data.monster_name)
		"Relativistic Shell":
			result.messages.append("%s condenses time and space!" % attacker.data.monster_name)
		"Neon Beacon":
			result.messages.append("%s shines a Neon Beacon!" % attacker.data.monster_name)
		"Atmospheric Shield":
			result.messages.append("%s projects an Atmospheric Shield!" % attacker.data.monster_name)
		"Fluorescent Pulse":
			result.messages.append("%s emits a Fluorescent Pulse!" % attacker.data.monster_name)
		"Alpha Dispersion":
			result.messages.append("%s disperses unstable Alpha particles!" % attacker.data.monster_name)

		"Precursor Strike":
			if defender.has_status("radiation"):
				result.effects.append({"target": defender, "effect": "add_status_stacks", "status": "reduced", "amount": 2, "duration": 3})
				result.messages.append("Precursor Strike resonated with Radiation!")
		"Tidal Decay":
			if defender.has_status("radiation"):
				result.effects.append({"target": attacker, "effect": "add_atb", "amount": 15.0})
				result.messages.append("Transuranic Bridge grants Action Gauge!")
		"Alpha Glow":
			var r_stacks = 0
			for eff in defender.active_effects:
				if eff.get("type") == "status" and eff.get("status") == "reduced":
					r_stacks = eff.get("stacks", 1)
					break
			var burn_pct = 0.05 + (0.05 * r_stacks)
			result.effects.append({"target": defender, "status": "burn", "damage_percent": burn_pct, "duration": 3, "type": "status"})
		"Final Chain":
			result.effects.append({"effect": "final_chain"})
			result.messages.append("Consuming all Entropy and [R] stacks!")
		"Neutron Flux":
			result.effects.append({"effect": "double_r_stacks", "target": defender})
		"Periodic Pulse":
			var r_stacks = 0
			for eff in defender.active_effects:
				if eff.get("type") == "status" and eff.get("status") == "reduced":
					r_stacks = eff.get("stacks", 1)
					break
			if r_stacks + 1 == 8:
				result.effects.append({"target": defender, "status": "law_of_octets", "duration": 99, "type": "status"})
				result.messages.append("Law of Octets fulfilled!")
				
		"Beta Radiance":
			var r_stacks = 0
			for eff in defender.active_effects:
				if eff.get("type") == "status" and eff.get("status") == "reduced":
					r_stacks = eff.get("stacks", 1)
					break
			var rad_dmg = 0.05
			if r_stacks >= 5:
				rad_dmg = 0.10
				result.messages.append("Unstable Glow doubles Radiation!")
			result.effects.append({"target": defender, "status": "radiation", "damage_percent": rad_dmg, "duration": 3, "type": "status"})
		"Cobalt-Sam Siphon":
			var r_stacks = 0
			for eff in defender.active_effects:
				if eff.get("type") == "status" and eff.get("status") == "reduced":
					r_stacks = eff.get("stacks", 1)
					break
			if r_stacks > 0:
				result.effects.append({"target": attacker, "effect": "add_atb", "amount": 5.0 * r_stacks})
				result.effects.append({"target": defender, "effect": "add_atb", "amount": -5.0 * r_stacks})
				result.messages.append("Energy Draw stole Action Gauge!")
		"Hard-to-Get Bash":
			var r_stacks = 0
			for eff in defender.active_effects:
				if eff.get("type") == "status" and eff.get("status") == "reduced":
					r_stacks = eff.get("stacks", 1)
					break
			if r_stacks >= 3:
				result.effects.append({"target": attacker, "status": "guarded", "duration": 3, "type": "status"})
				result.messages.append("Magnetic Flux grants Guarded!")
		"Dense Decay":
			result.effects.append({"effect": "dense_decay_bonus", "target": defender, "base_damage": int(result.damage)})

	# Tier 2 V.I.E. Passive: Signal Amplification (Post-Transition Metals)
	if attacker.data.group == AtomicConfig.Group.POST_TRANSITION:
		var pt_count = 0
		if PlayerData:
			pt_count = PlayerData.get_combat_resonance(attacker.is_player, AtomicConfig.Group.POST_TRANSITION)
		var multiplier = 1.0 + (pt_count * 0.10)
		var amplified_any = false
		
		for effect in result.effects:
			var is_buff = false
			
			if effect.get("type") == "stat_mod" and effect.get("amount", 0) > 0:
				effect["amount"] = int(effect.get("amount", 0) * multiplier)
				effect["effect"] = "aoe_stat_mod"
				effect["target_team"] = "ally"
				is_buff = true
			elif effect.get("effect") == "aoe_stat_mod" and effect.get("amount", 0) > 0 and effect.get("target_team") == "ally":
				effect["amount"] = int(effect.get("amount", 0) * multiplier)
				is_buff = true
			elif effect.get("effect") == "add_shield":
				effect["amount"] = int(effect.get("amount", 0) * multiplier)
				effect["effect"] = "add_team_shield"
				is_buff = true
			elif effect.get("effect") == "add_team_shield":
				effect["amount"] = int(effect.get("amount", 0) * multiplier)
				is_buff = true
			elif effect.get("effect") in ["heal", "heal_overflow_shield"]:
				if effect.has("amount"): effect["amount"] = int(effect.get("amount", 0) * multiplier)
				if effect.get("effect") == "heal": effect["effect"] = "team_heal"
				elif effect.get("effect") == "heal_overflow_shield": effect["effect"] = "team_heal_overflow_shield"
				is_buff = true
			elif effect.get("effect") == "team_heal" or effect.get("effect") == "team_heal_overflow_shield":
				if effect.has("amount"): effect["amount"] = int(effect.get("amount", 0) * multiplier)
				is_buff = true
			elif effect.get("type") == "status" and effect.get("status") in ["invulnerable", "taunt", "physical_resist", "special_resist", "mirror_coat", "reflective_shell", "absorb_shield", "regeneration"]:
				effect["effect"] = "team_status"
				effect["target_team"] = "ally"
				is_buff = true
			elif effect.get("effect") == "team_status" and effect.get("target_team") == "ally":
				is_buff = true
				
			if is_buff:
				amplified_any = true
					
		if amplified_any:
			result.messages.append("Signal Amplification!")

	# Tier 2 V.I.E. Passive: Inert Barrier (Noble Gases)
	# Noble Gases are completely immune to debuffs and negative stat mods.
	var new_effects = []
	for effect in result.effects:
		var target = effect.get("target")
		var should_block = false
		
		if target and is_instance_valid(target) and target.data.group == AtomicConfig.Group.NOBLE_GAS:
			if effect.get("type") == "status":
				var s = effect.get("status")
				if s in ["poison", "stun", "silence_special", "vulnerable", "corrosion", "reactive_vapor", "radiation", "refracted", "insanity", "singularity_hazard", "chain_reaction_mark", "reduced", "processing_loop", "luminescent", "burn", "proton_charge", "spontaneous_fumes", "incendiary_flash", "contrast_shadow", "bio_poison", "decay_catalyst", "irradiated_lock", "smoke_detector", "law_of_octets", "mri_trace", "buff_lock", "suppressed", "inhibited"]:
					should_block = true
			elif effect.get("type") == "stat_mod" and effect.get("amount", 0) < 0:
				should_block = true
			elif effect.get("effect") == "swap_stats":
				should_block = true
				
		if target and is_instance_valid(target) and target.has_status("radiation_immunity"):
			if effect.get("type") == "status" and effect.get("status") == "radiation":
				should_block = true
		
		if should_block:
			result.messages.append("Inert Barrier!")
		else:
			new_effects.append(effect)
	result.effects = new_effects

func is_void(group: int) -> bool:
	return group in [
		AtomicConfig.Group.VOID_GRUNT,
		AtomicConfig.Group.VOID_ASSASSIN,
		AtomicConfig.Group.VOID_BRUTE,
		AtomicConfig.Group.VOID_COMMANDER,
		AtomicConfig.Group.VOID_KING
	]

func _apply_mastery_on_hit(attacker: BattleMonster, defender: BattleMonster, move: MoveData, result: Dictionary):
	# Framework for 100% Stability Bonuses (On Hit/Action)
	match attacker.data.group:
		# Add other groups as needed...
		_: pass

func is_metal(group: int) -> bool:
	return group in [
		AtomicConfig.Group.ALKALI_METAL,
		AtomicConfig.Group.ALKALINE_EARTH,
		AtomicConfig.Group.TRANSITION_METAL,
		AtomicConfig.Group.POST_TRANSITION,
		AtomicConfig.Group.ACTINIDE,
		AtomicConfig.Group.LANTHANIDE
	]

func is_nonmetal(group: int) -> bool:
	return group in [
		AtomicConfig.Group.NONMETAL,
		AtomicConfig.Group.HALOGEN,
		AtomicConfig.Group.NOBLE_GAS,
		AtomicConfig.Group.METALLOID
	]
