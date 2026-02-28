class_name DamageCalculator
extends RefCounted

# --- Constants ---
const WEAKNESS_MULTIPLIER = 2.0
const RESISTANCE_MULTIPLIER = 0.5
const CRIT_MULTIPLIER = 1.5

# --- Main Calculation Function ---
static func calculate_damage(attacker: BattleMonster, defender: BattleMonster, move: MoveData) -> Dictionary:
	var result = {
		"damage": 0,
		"is_crit": false,
		"effectiveness": 1.0,
		"reaction": ""
	}
	
	# 1. Get Stats
	var atk = attacker.stats.get("attack", 10)
	var def = defender.stats.get("defense", 10)
	var spd_atk = attacker.stats.get("speed", 10)
	var spd_def = defender.stats.get("speed", 10)
	
	# Class Buff: Alkali Metals ignore defense based on collection (1% per element)
	if attacker.data.group == AtomicConfig.Group.ALKALI_METAL:
		var alkali_count = 0
		if PlayerData:
			alkali_count = PlayerData.class_resonance.get(AtomicConfig.Group.ALKALI_METAL, 0)
		var penetration = 0.05 + (alkali_count * 0.01)
		def = int(def * (1.0 - penetration))
	
	# 2. Base Damage Formula
	# Using the Diminishing Returns formula: Damage = Attack * (100 / (100 + Defense))
	# Scaled by Move Power. We normalize Move Power (e.g., 40 is standard)
	var mitigation = 100.0 / (100.0 + def)
	var base_damage = (atk * (move.power / 20.0)) * mitigation
	
	# 3. Elemental Effectiveness
	var effectiveness = get_effectiveness(attacker.data.group, defender.data.group)
	result["effectiveness"] = effectiveness
	result["reaction"] = get_reaction_name(attacker.data.group, defender.data.group)
	
	var damage = base_damage * effectiveness
	
	# 4. Critical Hit Chance
	# Faster monsters have higher crit chance. Base 5%.
	var crit_chance = 0.05 + ((spd_atk - spd_def) * 0.005)
	crit_chance = clamp(crit_chance, 0.0, 0.5) # Cap at 50%
	
	if randf() < crit_chance:
		damage *= CRIT_MULTIPLIER
		result["is_crit"] = true
		
	# 5. Variance (+/- 5%)
	var variance = randf_range(0.95, 1.05)
	damage *= variance
	
	# Final Integer Cast
	result["damage"] = int(max(1, damage))
	
	return result

# --- Elemental Logic ---
static func get_effectiveness(atk_group: int, def_group: int) -> float:
	# Noble Gases are Inert (Resistant to everything)
	if def_group == AtomicConfig.Group.NOBLE_GAS:
		return RESISTANCE_MULTIPLIER
		
	match atk_group:
		AtomicConfig.Group.ALKALI_METAL:
			# Volatile: Strong against Halogens & Nonmetals (Reactions)
			if def_group == AtomicConfig.Group.HALOGEN: return WEAKNESS_MULTIPLIER
			if def_group == AtomicConfig.Group.NONMETAL: return WEAKNESS_MULTIPLIER
			
		AtomicConfig.Group.HALOGEN:
			# Corrosive: Strong against Metals
			if is_metal(def_group): return WEAKNESS_MULTIPLIER
			
		AtomicConfig.Group.NONMETAL:
			# Oxidizer: Strong against Transition Metals
			if def_group == AtomicConfig.Group.TRANSITION_METAL: return WEAKNESS_MULTIPLIER
			
		AtomicConfig.Group.ACTINIDE:
			# Radioactive: Strong against everything but Noble Gases
			if def_group != AtomicConfig.Group.NOBLE_GAS: return WEAKNESS_MULTIPLIER
			
	return 1.0

static func get_reaction_name(atk_group: int, def_group: int) -> String:
	if def_group == AtomicConfig.Group.NOBLE_GAS: return "Inert"
	match atk_group:
		AtomicConfig.Group.ALKALI_METAL:
			if def_group == AtomicConfig.Group.HALOGEN: return "Salt Formation"
			if def_group == AtomicConfig.Group.NONMETAL: return "Explosive Reaction"
		AtomicConfig.Group.HALOGEN:
			if is_metal(def_group): return "Corrosion"
		AtomicConfig.Group.NONMETAL:
			if def_group == AtomicConfig.Group.TRANSITION_METAL: return "Oxidation"
		AtomicConfig.Group.ACTINIDE:
			return "Irradiation"
	return ""

static func is_metal(group: int) -> bool:
	return group in [
		AtomicConfig.Group.ALKALI_METAL,
		AtomicConfig.Group.ALKALINE_EARTH,
		AtomicConfig.Group.TRANSITION_METAL,
		AtomicConfig.Group.POST_TRANSITION,
		AtomicConfig.Group.ACTINIDE,
		AtomicConfig.Group.LANTHANIDE
	]