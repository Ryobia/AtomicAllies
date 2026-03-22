extends Node

# NOTE: For this to work globally, add this script to your Project Settings -> Autoload tab.

# PvE Combat Logic (No Type Chart, No Surge)

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
						if eff.has("damage_multiplier") or s in ["poison", "stun", "silence_special", "vulnerable", "corrosion", "radiation", "refracted", "insanity", "singularity_hazard", "reactive_vapor"]:
							is_debuff = true
					elif eff.get("type") == "swap_stats":
						is_debuff = true
						
					if is_debuff:
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
		moves.append(_create_move_from_dict(def))
	
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
	
	if hit_chance < 100 and randf() * 100 > hit_chance:
		result.success = false
		result.messages.append("%s missed!" % attacker.data.monster_name)
		return result
	
	result.hit = true

	# 2. Handle Damage
	if move.power > 0:
		_calculate_damage(attacker, defender, move, result)

	# 3. Apply Data-Driven Effects (New System)
	_apply_data_driven_effects(attacker, defender, move, result)

	# 4. Apply Unique Effects defined by name (Legacy/Complex Logic)
	_apply_unique_effects(attacker, defender, move, result)

	if result.is_reaction:
		result.effects.insert(0, { "effect": "critical_mass_boost" })

	return result

func _calculate_damage(attacker: BattleMonster, defender: BattleMonster, move: MoveData, result: Dictionary):
	# Use current battle stats from BattleMonster nodes
	var effective_attack = attacker.stats.attack
	var effective_defense = defender.stats.defense

	# Move-specific defense ignore

	var ignore_def = move.get_meta("ignore_def_percent", 0.0)
		
	if ignore_def > 0.0:
		effective_defense = int(effective_defense * (1.0 - (ignore_def / 100.0)))

	# Formula: ((Base Attack * Scale) + Move Power) * Mitigation
	# Mitigation: 100 / (100 + Defense) -> Standard diminishing returns
	var raw_power = (effective_attack * move.damage_scale) + move.power
	
	if move.name == "Resonance Strike":
		var hp_bonus = attacker.current_hp * 0.2
		raw_power += hp_bonus
		result.messages.append("Resonance scaled by HP! (+%d)" % int(hp_bonus))
		
	if move.name == "Red-Shift Dash":
		effective_defense = int(effective_defense * 0.25) # Ignore 75% Defense
		result.messages.append("Armor penetrated!")
		
	var mitigation = (100.0 / (100.0 + effective_defense))
	var final_damage = raw_power * mitigation
	
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
				if effect.has("damage_multiplier") or s in ["poison", "stun", "silence_special", "marked_covalent", "vulnerable", "corrosion", "reactive_vapor", "radiation", "refracted", "insanity", "oxidized", "carbonized", "overload", "illuminated", "singularity_hazard", "chain_reaction_mark"]:
					is_debuff = true
			if is_debuff:
				has_debuff = true
				break
		if has_debuff:
			var mult = move.get_meta("damage_multiplier", 1.0)
			var bonus = (final_damage * mult) - final_damage
			final_damage *= mult
			result.messages.append("Bonus vs Debuffed! (+%d Dmg)" % int(bonus))
			result.is_reaction = true
	
	# Speed Scaling (Einsteinium)
	if move.get_meta("speed_scaling", false):
		var spd_diff = max(0, attacker.stats.speed - defender.stats.speed)
		if spd_diff > 0:
			var multiplier = 1.0 + (spd_diff * 0.05) # 5% per point of speed difference
			var bonus = (final_damage * multiplier) - final_damage
			final_damage *= multiplier
			result.messages.append("Relativistic Speed Bonus! (%.2fx, +%d Dmg)" % [multiplier, int(bonus)])
			
	var crit_mult = 1.5
	if attacker.data.group == AtomicConfig.Group.ALKALI_METAL and attacker.data.stability >= 100:
		crit_mult = 1.75

	# Critical Hit Calculation
	var crit_chance = attacker.stats.get("crit_chance", 5) + move.get_meta("crit_bonus", 0.0)
	if randf() * 100.0 < crit_chance:
		final_damage *= crit_mult
		result.is_crit = true
	
	# Alkali Metal Full Set Bonus: First attack is a guaranteed critical hit
	if attacker.data.group == AtomicConfig.Group.ALKALI_METAL:
		var alkali_count = 0
		if PlayerData:
			alkali_count = PlayerData.get_combat_resonance(attacker.is_player, AtomicConfig.Group.ALKALI_METAL)
		var total_alkali = 0
		if MonsterManifest:
			for m in MonsterManifest.all_monsters:
				if m.group == AtomicConfig.Group.ALKALI_METAL:
					total_alkali += 1
		
		if alkali_count >= total_alkali and total_alkali > 0:
			if not attacker.has_meta("full_set_crit_used"):
				if not result.is_crit:
					var prev = final_damage
					final_damage *= crit_mult
					var bonus = final_damage - prev
					result.is_crit = true
					result.messages.append("Full Set Critical! (+%d Dmg)" % int(bonus))
				else:
					result.messages.append("Full Set Critical!")
				attacker.set_meta("full_set_crit_used", true)
	
	# Check for physical resistance
	if move.type == "Physical":
		for effect in defender.active_effects:
			if effect.get("status") == "physical_resist":
				var reduction = effect.get("reduction_amount", 0.2)
				final_damage *= (1.0 - reduction)
				result.messages.append("%s resists the physical blow!" % defender.data.monster_name)
				break # Apply only once
	
	# Check for special resistance
	if move.type == "Special":
		for effect in defender.active_effects:
			if effect.get("status") == "special_resist":
				var reduction = effect.get("reduction_amount", 0.2)
				final_damage *= (1.0 - reduction)
				result.messages.append("%s resists the energy!" % defender.data.monster_name)
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

	# Tier 1 V.I.E. Passive: Oxidation Burst (Nonmetals)
	if is_nonmetal(attacker.data.group) and move.power > 0:
		var reduced_stacks = 0
		for eff in defender.active_effects:
			if eff.get("type") == "status" and eff.get("status") == "reduced":
				reduced_stacks = eff.get("stacks", 1)
				break
		
		if reduced_stacks > 0:
			var nonmetal_count = 0
			if PlayerData:
				for group in [AtomicConfig.Group.NONMETAL, AtomicConfig.Group.HALOGEN, AtomicConfig.Group.NOBLE_GAS, AtomicConfig.Group.METALLOID]:
					nonmetal_count += PlayerData.class_resonance.get(group, 0)
					
			var delta_x = 0.2 + (nonmetal_count * 0.05)
			var burst_multiplier = 1.0 + (delta_x * reduced_stacks)
			
			var bonus_dmg = (final_damage * burst_multiplier) - final_damage
			final_damage *= burst_multiplier
			
			result.messages.append("OXIDATION BURST! %.2fx Damage! (+%d)" % [burst_multiplier, int(bonus_dmg)])
			result.effects.append({ "target": defender, "effect": "remove_status", "status": "reduced" })
			result.is_reaction = true
			
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
	
	# Alkaline Earth Full Set Bonus: Immune to first instance of damage
	if defender.data.group == AtomicConfig.Group.ALKALINE_EARTH:
		var ae_count = PlayerData.get_combat_resonance(defender.is_player, AtomicConfig.Group.ALKALINE_EARTH)
		var total_ae = 0
		if MonsterManifest:
			for m in MonsterManifest.all_monsters:
				if m.group == AtomicConfig.Group.ALKALINE_EARTH:
					total_ae += 1
		
		if ae_count >= total_ae and total_ae > 0:
			if not defender.has_meta("full_set_immune_used"):
				final_damage = 0.0
				result.messages.append("Full Set Immunity!")
				defender.set_meta("full_set_immune_used", true)
	
	result.damage = int(final_damage)
	result.messages.append("It dealt %d damage!" % result.damage)

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
			var eff_crit_mult = 1.5
			if attacker.data.group == AtomicConfig.Group.ALKALI_METAL and attacker.data.stability >= 100:
				eff_crit_mult = 1.75
			effect["amount"] = int(effect.get("amount", 0) * eff_crit_mult)

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
			result.messages.append("%s applied %s!" % [target.data.monster_name, status.capitalize()])
	elif type == "stat_mod":
		var stat = effect.get("stat")
		var amt = effect.get("amount")
		var verb = "rose" if amt > 0 else "fell"
		result.messages.append("%s's %s %s!" % [target.data.monster_name, stat.capitalize(), verb])

func _apply_unique_effects(attacker: BattleMonster, defender: BattleMonster, move: MoveData, result: Dictionary):
	
	# --- Class On-Hit Effects ---
	
	# Halogen: Poison
	if attacker.data.group == AtomicConfig.Group.HALOGEN:
		var count = 0
		if PlayerData:
			count = PlayerData.get_combat_resonance(attacker.is_player, AtomicConfig.Group.HALOGEN)
		var bonus_pct = 1.0 + (count * 0.01) # +1% effectiveness per element
		var duration = 3
		
		# Full Set Bonus: Poison lasts an additional turn
		var total_halogen = 0
		if MonsterManifest:
			for m in MonsterManifest.all_monsters:
				if m.group == AtomicConfig.Group.HALOGEN:
					total_halogen += 1
		
		if count >= total_halogen and total_halogen > 0:
			duration += 1
		
		var pct = 0.10 * bonus_pct
		result.effects.append({ "target": defender, "status": "poison", "damage_percent": pct, "duration": duration, "type": "status" })
		
	# Metalloid: Stun
	if attacker.data.group == AtomicConfig.Group.METALLOID:
		var chance = 0.10
		# Mastery: Metalloids (100% Stability) -> Increase stun chance to 25%
		if attacker.data.stability >= 100:
			chance = 0.25
			
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
				if s in ["poison", "radiation", "corrosion"]:
					has_dots = true
					break
		
		if has_dots:
			var tm_count = 0
			if PlayerData:
				tm_count = PlayerData.get_combat_resonance(attacker.is_player, AtomicConfig.Group.TRANSITION_METAL)
			var total_tm = 0
			if MonsterManifest:
				for m in MonsterManifest.all_monsters:
					if m.group == AtomicConfig.Group.TRANSITION_METAL:
						total_tm += 1
			
			var ticks = 1
			if total_tm > 0 and tm_count >= total_tm:
				ticks = 2
				
			if attacker.data.stability >= 100:
				ticks += 1
				
			var dmg_mult = 1.0 + (tm_count * 0.02)
				
			result.effects.append({
				"effect": "catalyst_tick",
				"target": defender,
				"ticks": ticks,
				"multiplier": dmg_mult
			})
			result.messages.append("%s catalyzed the reactions!" % attacker.data.monster_name)
			result.is_reaction = true
			
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
		result.messages.append("%s primed the target! (+1 [R])" % attacker.data.monster_name)

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
			"lanth_count": lanth_count
		})

	# Mastery Effects (100% Stability)
	if attacker.data.stability >= 100:
		_apply_mastery_on_hit(attacker, defender, move, result)

	match move.name:
		"Alloy Reinforce":
			# Heals the target
			var heal_amount = int(attacker.stats.attack * 1.5)
			result.effects.append({ "target": defender, "effect": "heal_overflow_shield", "amount": heal_amount })
			result.messages.append("%s repairs the structure!" % attacker.data.monster_name)
			
		"Paramagnetic Pull":
			result.effects.append({ "target": defender, "status": "vulnerable", "duration": 2, "type": "status" })
			result.messages.append("%s is magnetized!" % defender.data.monster_name)
			
		"Photonic Bash":
			if attacker.has_status("anodic_barrier"):
				result.effects.append({ "target": defender, "status": "stun", "duration": 1, "type": "status" })
				result.messages.append("%s was blinded!" % defender.data.monster_name)
			
		"Supercritical Blast":
			result.effects.append({ "target": attacker, "effect": "recoil", "amount": int(attacker.max_hp * 0.1) })
			result.messages.append("%s takes recoil damage!" % attacker.data.monster_name)
			
		"Reactive Vapor":
			result.effects.append({ "effect": "team_status", "status": "reactive_vapor", "duration": 3, "type": "status" })
			result.messages.append("%s fills the area with reactive vapor!" % attacker.data.monster_name)
			
		"Rare Resonance":
			var unique_groups = {}
			var team_list = []
			
			if attacker.is_player:
				team_list = PlayerData.active_team
				if team_list.is_empty(): # Fallback for testing if active_team is not set
					team_list = PlayerData.owned_monsters
			else:
				team_list = PlayerData.pending_enemy_team
				
			for member in team_list:
				if member and "group" in member:
					unique_groups[member.group] = true
			
			var multiplier = clampi(unique_groups.size(), 1, 6)
			var bonus = (result.damage * multiplier) - result.damage
			result.damage *= multiplier
			result.messages.append("Resonance! %dx Damage! (+%d Dmg)" % [multiplier, int(bonus)])
			result.is_reaction = true
			
		"Violet Flare":
			var debuff_count = 0
			for effect in defender.active_effects:
				var is_debuff = false
				if effect.get("type") == "stat_mod" and effect.get("amount", 0) < 0:
					is_debuff = true
				elif effect.get("type") == "status":
					var s = str(effect.get("status", "")).to_lower()
					if effect.has("damage_multiplier") or s in ["poison", "stun", "silence_special", "marked_covalent", "vulnerable", "corrosion", "reactive_vapor", "radiation", "refracted", "insanity", "oxidized", "carbonized", "overload", "singularity_hazard", "chain_reaction_mark"]:
						is_debuff = true
				elif effect.get("effect") == "swap_stats":
					is_debuff = true
				
				if is_debuff:
					debuff_count += 1
			
			var multiplier = 1 + debuff_count
			if multiplier > 1:
				var bonus = (result.damage * multiplier) - result.damage
				result.damage *= multiplier
				result.messages.append("Flare intensified! %dx Damage! (+%d Dmg)" % [multiplier, int(bonus)])
				result.is_reaction = true

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

	# Tier 2 V.I.E. Passive: Signal Amplification (Post-Transition Metals)
	if attacker.data.group == AtomicConfig.Group.POST_TRANSITION:
		var pt_count = 0
		if PlayerData:
			pt_count = PlayerData.get_combat_resonance(attacker.is_player, AtomicConfig.Group.POST_TRANSITION)
		var multiplier = 1.0 + (pt_count * 0.10)
		
		var total_pt = 0
		if MonsterManifest:
			for m in MonsterManifest.all_monsters:
				if m.group == AtomicConfig.Group.POST_TRANSITION:
					total_pt += 1
		
		var extend_duration = (pt_count >= total_pt and total_pt > 0)
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
				if extend_duration and effect.has("duration"):
					effect["duration"] += 1
					
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
				if s in ["poison", "stun", "silence_special", "marked_covalent", "vulnerable", "corrosion", "reactive_vapor", "radiation", "refracted", "insanity", "singularity_hazard", "chain_reaction_mark", "volatile", "reduced"]:
					should_block = true
			elif effect.get("type") == "stat_mod" and effect.get("amount", 0) < 0:
				should_block = true
			elif effect.get("effect") == "swap_stats":
				should_block = true
		
		if should_block:
			result.messages.append("Inert Barrier!")
		else:
			new_effects.append(effect)
	result.effects = new_effects

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