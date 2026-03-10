extends Node

# NOTE: For this to work globally, add this script to your Project Settings -> Autoload tab.

# PvE Combat Logic (No Type Chart, No Surge)

# --- Battle Items ---
const ITEM_DATA = {
	"repair_nanites": { "name": "Repair Nanites", "target": "Ally", "effect": "heal_percent", "amount": 0.5 },
	"adrenaline_shot": { "name": "Adrenaline Shot", "target": "Ally", "effect": "buff_stat", "stat": "attack", "amount": 20, "duration": 3 },
	"emergency_shield": { "name": "Emergency Shield", "target": "Ally", "effect": "add_shield", "amount": 0.3 }
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
		"hit": false,
		"messages": [],
		"effects": [] # List of effects applied
	}

	# 1. Accuracy Check
	var hit_chance = float(move.accuracy)
	
	if attacker.has_status("refracted") or attacker.has_status("insanity"):
		hit_chance -= 20.0
	
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

	return result

func _calculate_damage(attacker: BattleMonster, defender: BattleMonster, move: MoveData, result: Dictionary):
	# Use current battle stats from BattleMonster nodes
	var effective_attack = attacker.stats.attack
	var effective_defense = defender.stats.defense

	# Class Buff: Alkali Metals ignore 5% defense per element owned
	if attacker.data.group == AtomicConfig.Group.ALKALI_METAL:
		var alkali_count = 0
		if PlayerData:
			alkali_count = PlayerData.class_resonance.get(AtomicConfig.Group.ALKALI_METAL, 0)
		var penetration = alkali_count * 0.05
		effective_defense = int(effective_defense * (1.0 - penetration))

	# Transition Metal Passive: Consecutive attacks deal 5% more damage
	if attacker.data.group == AtomicConfig.Group.TRANSITION_METAL:
		var consec = attacker.get_meta("consecutive_attacks", 0)
		if consec > 0:
			effective_attack = int(effective_attack * (1.0 + (consec * 0.05)))
		attacker.set_meta("consecutive_attacks", consec + 1)
	else:
		attacker.set_meta("consecutive_attacks", 0)

	# Formula: (Base Attack + Move Power) * Mitigation
	# Formula: (Base Attack + Move Power) * Mitigation
	# Mitigation: 100 / (100 + Defense) -> Standard diminishing returns
	var raw_power = effective_attack + move.power
	
	if move.name == "Heavy Impact":
		var hp_bonus = attacker.current_hp * 0.2
		raw_power += hp_bonus
		result.messages.append("Impact scaled by HP! (+%d)" % int(hp_bonus))
		
	var mitigation = (100.0 / (100.0 + effective_defense))
	var final_damage = raw_power * mitigation
	
	# Alkali Metal Full Set Bonus: First attack deals 2x damage
	if attacker.data.group == AtomicConfig.Group.ALKALI_METAL:
		var alkali_count = PlayerData.class_resonance.get(AtomicConfig.Group.ALKALI_METAL, 0)
		var total_alkali = 0
		if MonsterManifest:
			for m in MonsterManifest.all_monsters:
				if m.group == AtomicConfig.Group.ALKALI_METAL:
					total_alkali += 1
		
		if alkali_count >= total_alkali and total_alkali > 0:
			if not attacker.has_meta("full_set_crit_used"):
				final_damage *= 2.0
				result.messages.append("Full Set Critical!")
				attacker.set_meta("full_set_crit_used", true)
	
	# Actinide Passive: Deal bonus 10% max health damage
	if attacker.data.group == AtomicConfig.Group.ACTINIDE:
		final_damage += (attacker.max_hp * 0.1)
	
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
					final_damage *= multiplier
					
					var reaction_name = effect.get("reaction_name", "Reaction")
					result.messages.append("%s! Bonus Damage!" % reaction_name)
					result.effects.append({ "target": defender, "effect": "remove_status", "status": effect.get("status") })
	
	# Variance +/- 10%
	final_damage *= randf_range(0.9, 1.1)
	
	# Alkaline Earth Full Set Bonus: Immune to first instance of damage
	if defender.data.group == AtomicConfig.Group.ALKALINE_EARTH:
		var ae_count = PlayerData.class_resonance.get(AtomicConfig.Group.ALKALINE_EARTH, 0)
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
		# Check chance
		var chance = effect_def.get("chance", 1.0)
		if randf() > chance: continue
		
		# Determine Target
		var target_scope = effect_def.get("target", "Defender") # "Defender", "Attacker"
		var target = defender if target_scope == "Defender" else attacker
		
		# Build effect dictionary for BattleManager
		var effect = effect_def.duplicate()
		
		# Resolve relative values (e.g. "amount": 20 with "percent": true)
		if effect.get("type") == "stat_mod":
			if effect.get("percent", false):
				var stat_name = effect.get("stat")
				var base_val = target.stats.get(stat_name, 10)
				effect["amount"] = int(base_val * (effect.get("amount") / 100.0))
				
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
		var count = PlayerData.class_resonance.get(AtomicConfig.Group.HALOGEN, 0)
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
			
	# Transition Metal: Double Hit
	if attacker.data.group == AtomicConfig.Group.TRANSITION_METAL:
		var count = PlayerData.class_resonance.get(AtomicConfig.Group.TRANSITION_METAL, 0)
		var chance = 0.02 * count # +2% chance per element
		
		# Full Set Bonus: +15% chance to attack twice
		var total_tm = 0
		if MonsterManifest:
			for m in MonsterManifest.all_monsters:
				if m.group == AtomicConfig.Group.TRANSITION_METAL:
					total_tm += 1
		
		if count >= total_tm and total_tm > 0:
			chance += 0.15
		
		if randf() < chance:
			var multiplier = 1.5
			var msg = "Double Hit!"
			
			# Mastery: Transition Metals (100% Stability) -> Second hit deals full damage
			if attacker.data.stability >= 100:
				multiplier = 2.0
				msg = "Perfect Double Hit!"
			
			result.damage = int(result.damage * multiplier)
			result.messages.append(msg)
			
	# Nonmetal: Chain Reaction
	if attacker.data.group == AtomicConfig.Group.NONMETAL:
		var count = PlayerData.class_resonance.get(AtomicConfig.Group.NONMETAL, 0)
		var chance = 0.05 * count # +5% chance per element
		
		# Full Set Bonus: Guaranteed Chain Reaction
		var total_nm = 0
		if MonsterManifest:
			for m in MonsterManifest.all_monsters:
				if m.group == AtomicConfig.Group.NONMETAL:
					total_nm += 1
		
		if count >= total_nm and total_nm > 0:
			chance = 1.0
			
		if randf() < chance:
			var chain_effect = { "effect": "chain_reaction", "amount": result.damage }
			
			# Mastery: Nonmetals (100% Stability) -> Status effects chain react
			if attacker.data.stability >= 100:
				chain_effect["copy_status"] = true
				
			result.effects.append(chain_effect)

	# Metalloid: +5% Debuff Effectiveness (Increase stat drop amount)
	if attacker.data.group == AtomicConfig.Group.METALLOID:
		var count = PlayerData.class_resonance.get(AtomicConfig.Group.METALLOID, 0)
		var multiplier = 1.0 + (count * 0.05)
		
		# Full Set Bonus: Debuffs last an additional turn
		var total_metalloid = 0
		if MonsterManifest:
			for m in MonsterManifest.all_monsters:
				if m.group == AtomicConfig.Group.METALLOID:
					total_metalloid += 1
		
		var extend_duration = (count >= total_metalloid and total_metalloid > 0)
		
		for effect in result.effects:
			var is_debuff = false
			if effect.get("type") == "stat_mod" and effect.get("amount", 0) < 0:
				effect.amount = int(effect.amount * multiplier)
				is_debuff = true
			elif effect.get("type") == "status" and effect.get("status") in ["poison", "stun", "silence_special", "marked_covalent", "vulnerable", "corrosion", "reactive_vapor", "radiation", "refracted", "insanity"]:
				is_debuff = true
			elif effect.get("effect") == "swap_stats":
				is_debuff = true
				
			if extend_duration and is_debuff and effect.has("duration"):
				effect.duration += 1

	# Mastery Effects (100% Stability)
	if attacker.data.stability >= 100:
		_apply_mastery_on_hit(attacker, defender, move, result)

	match move.name:
		"Electron Jettison":
			# Reduces Defense to zero
			var current_def = attacker.stats.defense
			result.effects.append({ "target": attacker, "stat": "defense", "amount": -current_def, "duration": 2, "type": "stat_mod" })
			result.messages.append("%s becomes unstable!" % attacker.data.monster_name)
			
		"Oxidation Layer":
			var amount = int(attacker.stats.defense * 0.5)
			result.effects.append({ "target": attacker, "stat": "defense", "amount": amount, "duration": 3, "type": "stat_mod" })
			result.messages.append("%s fortified its structure!" % attacker.data.monster_name)
			
		"Metallic Bond":
			# Buffs attack of the target (ally)
			var amount = int(defender.stats.attack * 0.2)
			var duration = 2 if attacker == defender else 1
			result.effects.append({ "target": defender, "stat": "attack", "amount": amount, "duration": duration, "type": "stat_mod" })
			result.messages.append("%s shares its strength!" % attacker.data.monster_name)
			
			# Also buffs self if targeting a different ally
			if attacker != defender:
				var self_amount = int(attacker.stats.attack * 0.2)
				result.effects.append({ "target": attacker, "stat": "attack", "amount": self_amount, "duration": 2, "type": "stat_mod" })
			
		"Thermal Conduction":
			# Cleanses status effects from target
			result.effects.append({ "target": defender, "effect": "cleanse" })
			result.messages.append("%s stabilizes temperature!" % attacker.data.monster_name)
			
		"Alloy Reinforce":
			# Heals the target
			var heal_amount = int(attacker.stats.attack * 1.5)
			result.effects.append({ "target": defender, "effect": "heal_overflow_shield", "amount": heal_amount })
			result.messages.append("%s repairs the structure!" % attacker.data.monster_name)
			
		"Semiconductor Flip":
			result.effects.append({ "target": defender, "effect": "swap_stats", "stats": ["attack", "defense"], "duration": 2 })
			result.messages.append("%s's Attack and Defense were swapped!" % defender.data.monster_name)
			
		"Signal Scramble":
			var reduction = int(defender.stats.speed * 0.2)
			# Safety clamp: Ensure speed doesn't drop below 1
			if defender.stats.speed - reduction < 1:
				reduction = max(0, defender.stats.speed - 1)
			
			result.effects.append({ "target": defender, "stat": "speed", "amount": -reduction, "duration": 2, "type": "stat_mod" })
			result.messages.append("%s's signals are jammed!" % defender.data.monster_name)
			
		"Electronegativity":
			var reduction = int(defender.stats.speed * 0.2)
			# Safety clamp: Ensure speed doesn't drop below 1
			if defender.stats.speed - reduction < 1:
				reduction = max(0, defender.stats.speed - 1)
				
			result.effects.append({ "target": defender, "stat": "speed", "amount": -reduction, "duration": 2, "type": "stat_mod" })
			result.messages.append("%s is being pulled in!" % defender.data.monster_name)
			
		"Paramagnetic Pull":
			result.effects.append({ "target": defender, "status": "vulnerable", "duration": 2, "type": "status" })
			result.messages.append("%s is magnetized!" % defender.data.monster_name)
			
		"Magnesium Flash":
			# Only stun if shielded (Flash relies on reflective shielding)
			if attacker.get_meta("shield", 0) > 0:
				result.effects.append({ "target": defender, "status": "stun", "duration": 1, "type": "status" })
				result.messages.append("%s was blinded!" % defender.data.monster_name)
		
		"Full Octet":
			result.effects.append({ "target": attacker, "status": "stun", "duration": 2, "type": "status" })
			result.effects.append({ "target": attacker, "status": "invulnerable", "duration": 2, "type": "status" })
			result.messages.append("%s becomes completely inert!" % attacker.data.monster_name)
			
		"Neon Glow":
			result.effects.append({ "target": attacker, "status": "taunt", "duration": 2, "type": "status" })
			var amount = int(attacker.stats.defense * 0.2)
			result.effects.append({ "target": attacker, "stat": "defense", "amount": amount, "duration": 2, "type": "stat_mod" })
			result.messages.append("%s shines brightly!" % attacker.data.monster_name)
			
		"Supercritical Blast":
			result.effects.append({ "target": attacker, "effect": "recoil", "amount": int(attacker.max_hp * 0.1) })
			result.messages.append("%s takes recoil damage!" % attacker.data.monster_name)
			
		"Reactive Vapor":
			result.effects.append({ "effect": "team_status", "status": "reactive_vapor", "duration": 3, "type": "status" })
			result.messages.append("%s fills the area with reactive vapor!" % attacker.data.monster_name)
			
		"Void Harden":
			var amount = int(attacker.stats.defense * 0.2)
			result.effects.append({ "target": attacker, "stat": "defense", "amount": amount, "duration": 3, "type": "stat_mod" })
			result.messages.append("%s hardens its shell!" % attacker.data.monster_name)
			
		"Void Command":
			var atk_amount = int(defender.stats.attack * 0.2)
			result.effects.append({ "target": defender, "stat": "attack", "amount": atk_amount, "duration": 3, "type": "stat_mod" })
			
			var spd_amount = int(defender.stats.speed * 0.2)
			result.effects.append({ "target": defender, "stat": "speed", "amount": spd_amount, "duration": 3, "type": "stat_mod" })
			result.messages.append("%s commands the void!" % attacker.data.monster_name)
			
		"Optical Refraction":
			result.effects.append({ "target": defender, "status": "refracted", "duration": 2, "type": "status" })
			result.messages.append("%s's vision is distorted!" % defender.data.monster_name)
			
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
			result.damage *= multiplier
			result.messages.append("Resonance! %dx Damage!" % multiplier)
			
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
			
		"Chain Reaction":
			result.effects.append({ "effect": "chain_reaction", "amount": result.damage })
			result.messages.append("%s starts a reaction!" % attacker.data.monster_name)
			
		"Neurotoxin":
			result.effects.append({ "target": defender, "status": "poison", "damage_percent": 0.1, "duration": 3, "type": "status" })
			result.messages.append("%s injects a deadly toxin!" % attacker.data.monster_name)
			
		"Static Shield":
			var shield_amount = int(attacker.max_hp * 0.3)
			result.effects.append({ "target": attacker, "effect": "add_shield", "amount": shield_amount })
			result.effects.append({ "target": attacker, "status": "static_reflection", "duration": 3, "type": "status" })
			result.messages.append("%s charges up a static field!" % attacker.data.monster_name)
			
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

	# Post-Transition: +5% Buff Effectiveness (Increase stat buff amount)
	if attacker.data.group == AtomicConfig.Group.POST_TRANSITION:
		var count = PlayerData.class_resonance.get(AtomicConfig.Group.POST_TRANSITION, 0)
		var multiplier = 1.0 + (count * 0.05)
		
		# Full Set Bonus: Buffs last an additional turn
		var total_pt = 0
		if MonsterManifest:
			for m in MonsterManifest.all_monsters:
				if m.group == AtomicConfig.Group.POST_TRANSITION:
					total_pt += 1
		
		var extend_duration = (count >= total_pt and total_pt > 0)
		
		for effect in result.effects:
			var is_buff = false
			if (effect.get("type") == "stat_mod" and effect.get("amount", 0) > 0):
				effect.amount = int(effect.amount * multiplier)
				is_buff = true
			elif effect.get("effect") in ["heal", "heal_overflow_shield"]:
				effect.amount = int(effect.amount * multiplier)
			elif effect.get("type") == "status" and effect.get("status") in ["invulnerable", "taunt"]:
				is_buff = true
				
			if extend_duration and is_buff and effect.has("duration"):
				effect.duration += 1

	# Noble Gas Full Set Bonus: Immune to debuffs
	# Check if we need to filter effects based on collection status
	var ng_count = PlayerData.class_resonance.get(AtomicConfig.Group.NOBLE_GAS, 0)
	var total_ng = 0
	if MonsterManifest:
		for m in MonsterManifest.all_monsters:
			if m.group == AtomicConfig.Group.NOBLE_GAS:
				total_ng += 1
	
	if ng_count >= total_ng and total_ng > 0:
		var new_effects = []
		for effect in result.effects:
			var target = effect.get("target")
			var should_block = false
			
			if target and is_instance_valid(target) and target.data.group == AtomicConfig.Group.NOBLE_GAS:
				if effect.get("type") == "status":
					var s = effect.get("status")
					if s in ["poison", "stun", "silence_special", "marked_covalent", "vulnerable", "corrosion", "reactive_vapor", "radiation", "refracted", "insanity"]:
						should_block = true
				elif effect.get("type") == "stat_mod" and effect.get("amount", 0) < 0:
					should_block = true
				elif effect.get("effect") == "swap_stats":
					should_block = true
			
			if should_block:
				result.messages.append("Noble Gas Immunity!")
			else:
				new_effects.append(effect)
		result.effects = new_effects

func _apply_mastery_on_hit(attacker: BattleMonster, defender: BattleMonster, move: MoveData, result: Dictionary):
	# Framework for 100% Stability Bonuses (On Hit/Action)
	match attacker.data.group:
		# Add other groups as needed...
		_: pass