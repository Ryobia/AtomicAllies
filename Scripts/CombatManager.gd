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
	if not monster.moves.is_empty():
		return monster.moves
	
	# Fallback to AtomicConfig defaults
	var moves: Array = []
	if "group" in monster:
		var defaults = AtomicConfig.GROUP_MOVES.get(monster.group, [])
		for def in defaults:
			# Convert Dictionary to MoveData resource on the fly
			var m = MoveData.new()
			m.name = def.name
			m.power = def.get("power", 0)
			m.accuracy = def.get("accuracy", 100)
			m.type = def.get("type", "Physical")
			m.description = def.get("description", "")
			m.is_snipe = def.get("is_snipe", false)
			
			var t_str = def.get("target_type", "Enemy")
			match t_str:
				"Self": m.target_type = MoveData.TargetType.SELF
				"Ally": m.target_type = MoveData.TargetType.ALLY
				_: m.target_type = MoveData.TargetType.ENEMY
				
			moves.append(m)
	
	return moves

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
	
	if attacker.has_status("refracted"):
		hit_chance -= 20.0
	
	if hit_chance < 100 and randf() * 100 > hit_chance:
		result.success = false
		result.messages.append("%s missed!" % attacker.data.monster_name)
		return result
	
	result.hit = true

	# 2. Handle Damage
	if move.power > 0:
		_calculate_damage(attacker, defender, move, result)

	# 3. Apply Unique Effects defined by name
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
	
	# Actinide Passive: Deal bonus 10% max health damage
	if attacker.data.group == AtomicConfig.Group.ACTINIDE:
		final_damage += (attacker.max_hp * 0.1)
	
	# Covalent Link: Triple damage on cross-element hit
	if defender.has_status("marked_covalent") and attacker.data.group != defender.data.group:
		final_damage *= 3.0
		result.messages.append("Covalent Reaction! Triple Damage!")
		result.effects.append({ "target": defender, "effect": "remove_status", "status": "marked_covalent" })
	
	# Variance +/- 10%
	final_damage *= randf_range(0.9, 1.1)
	
	result.damage = int(final_damage)
	result.messages.append("It dealt %d damage!" % result.damage)

func _apply_unique_effects(attacker: BattleMonster, defender: BattleMonster, move: MoveData, result: Dictionary):
	
	# --- Class On-Hit Effects ---
	
	# Halogen: Poison
	if attacker.data.group == AtomicConfig.Group.HALOGEN:
		var count = PlayerData.class_resonance.get(AtomicConfig.Group.HALOGEN, 0)
		var bonus_dmg = 1.0 + (count * 0.01) # +1% damage per element
		var duration = 3
		
		var poison_dmg = int((defender.max_hp * 0.10) * bonus_dmg)
		result.effects.append({ "target": defender, "status": "poison", "damage": poison_dmg, "duration": duration, "type": "status" })
		
	# Metalloid: Stun
	if attacker.data.group == AtomicConfig.Group.METALLOID:
		if randf() < 0.10:
			result.effects.append({ "target": defender, "status": "stun", "duration": 1, "type": "status" })
			
	# Transition Metal: Double Hit
	if attacker.data.group == AtomicConfig.Group.TRANSITION_METAL:
		var count = PlayerData.class_resonance.get(AtomicConfig.Group.TRANSITION_METAL, 0)
		var chance = 0.02 * count # +2% chance per element
		
		if randf() < chance:
			result.damage = int(result.damage * 1.5) # 50% extra damage
			result.messages.append("Double Hit!")
			
	# Nonmetal: Chain Reaction
	if attacker.data.group == AtomicConfig.Group.NONMETAL:
		var count = PlayerData.class_resonance.get(AtomicConfig.Group.NONMETAL, 0)
		var chance = 0.05 * count # +5% chance per element
			
		if randf() < chance:
			result.effects.append({ "effect": "chain_reaction", "amount": result.damage })

	# Metalloid: +5% Debuff Effectiveness (Increase stat drop amount)
	if attacker.data.group == AtomicConfig.Group.METALLOID:
		var count = PlayerData.class_resonance.get(AtomicConfig.Group.METALLOID, 0)
		var multiplier = 1.0 + (count * 0.05)
		for effect in result.effects:
			if effect.get("type") == "stat_mod" and effect.get("amount", 0) < 0:
				effect.amount = int(effect.amount * multiplier)

	match move.name:
		"Electron Jettison":
			# Reduces Defense to zero
			var current_def = attacker.stats.defense
			result.effects.append({ "target": attacker, "stat": "defense", "amount": -current_def, "duration": 1, "type": "stat_mod" })
			result.messages.append("%s becomes unstable!" % attacker.data.monster_name)
			
		"Oxidation Layer":
			var amount = int(attacker.stats.defense * 0.5)
			result.effects.append({ "target": attacker, "stat": "defense", "amount": amount, "duration": 3, "type": "stat_mod" })
			result.messages.append("%s fortified its structure!" % attacker.data.monster_name)
			
		"Metallic Bond":
			# Buffs attack of the target (ally)
			var amount = int(defender.stats.attack * 0.2)
			result.effects.append({ "target": defender, "stat": "attack", "amount": amount, "duration": 1, "type": "stat_mod" })
			result.messages.append("%s shares its strength!" % attacker.data.monster_name)
			
			# Also buffs self if targeting a different ally
			if attacker != defender:
				var self_amount = int(attacker.stats.attack * 0.2)
				result.effects.append({ "target": attacker, "stat": "attack", "amount": self_amount, "duration": 1, "type": "stat_mod" })
			
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
			
		"Covalent Link":
			result.effects.append({ "target": defender, "status": "marked_covalent", "duration": 3, "type": "status" })
			result.messages.append("%s is marked for reaction!" % defender.data.monster_name)
			
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
			var chance = 0.5
			if attacker.get_meta("shield", 0) > 0:
				chance = 1.0
				
			if randf() < chance:
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
			
		"Fluorine Acid":
			result.effects.append({ "effect": "team_status", "status": "poison", "damage_percent": 0.1, "duration": 3, "type": "status" })
			result.messages.append("%s releases a toxic cloud!" % attacker.data.monster_name)
			
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

	# Post-Transition: +5% Buff Effectiveness (Increase stat buff amount)
	if attacker.data.group == AtomicConfig.Group.POST_TRANSITION:
		var count = PlayerData.class_resonance.get(AtomicConfig.Group.POST_TRANSITION, 0)
		var multiplier = 1.0 + (count * 0.05)
		for effect in result.effects:
			if (effect.get("type") == "stat_mod" and effect.get("amount", 0) > 0) or effect.get("effect") in ["heal", "heal_overflow_shield"]:
				effect.amount = int(effect.amount * multiplier)