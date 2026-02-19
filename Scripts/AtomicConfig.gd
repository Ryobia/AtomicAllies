class_name AtomicConfig
extends RefCounted

# The Atomic Classes (Groups) acting as Combat Roles
enum Group {
	ALKALI_METAL,
	ALKALINE_EARTH,
	TRANSITION_METAL,
	POST_TRANSITION,
	METALLOID,
	NONMETAL,
	HALOGEN,
	NOBLE_GAS,
	ACTINIDE,
	LANTHANIDE,
	UNKNOWN
}

# Baseline Stats (Scale 1-10) from the Design Document
const BASELINES = {
	Group.ALKALI_METAL:    { "hp": 3, "atk": 8, "def": 2, "spd": 9 }, # Glass Cannons
	Group.ALKALINE_EARTH:  { "hp": 6, "atk": 4, "def": 7, "spd": 3 }, # Sturdy Tanks
	Group.TRANSITION_METAL:{ "hp": 7, "atk": 6, "def": 6, "spd": 4 }, # Bruisers
	Group.POST_TRANSITION: { "hp": 5, "atk": 5, "def": 5, "spd": 5 }, # Utility
	Group.METALLOID:       { "hp": 4, "atk": 6, "def": 4, "spd": 7 }, # Disrupters
	Group.NONMETAL:        { "hp": 3, "atk": 3, "def": 3, "spd": 6 }, # Combo Primers
	Group.HALOGEN:         { "hp": 2, "atk": 7, "def": 2, "spd": 8 }, # DoT Assailants
	Group.NOBLE_GAS:       { "hp": 5, "atk": 1, "def": 10,"spd": 4 }, # Pure Walls
	Group.ACTINIDE:        { "hp": 8, "atk": 10,"def": 5, "spd": 2 }, # The Nukes
	Group.LANTHANIDE:      { "hp": 7, "atk": 9, "def": 5, "spd": 3 }, # Rare Earths (Similar to Actinides)
	Group.UNKNOWN:         { "hp": 5, "atk": 5, "def": 5, "spd": 5 }
}

# Calculates final stats based on Group Baseline, Atomic Number (Z), and Level.
static func calculate_stats(group: Group, atomic_number: int, level: int) -> Dictionary:
	var base = BASELINES.get(group, BASELINES[Group.UNKNOWN])
	
	# Tuning Constants
	# These multipliers ensure that a "10" in a baseline stat feels significantly stronger than a "1".
	var hp_mult = 15.0
	var stat_mult = 3.0
	
	# Z Scaling: How much the Atomic Number acts as a "Tier" multiplier.
	# Heavier elements will naturally have higher stats.
	var z_scaling = 0.5 
	
	# --- Level Scaling ---
	# Using a power curve makes late-game levels more impactful.
	const LEVEL_EXPONENT = 1.15
	const HP_LEVEL_SCALING = 4.0
	const STAT_LEVEL_SCALING = 1.5
	const SPD_LEVEL_SCALING = 0.25
	
	var final_stats = {}
	var level_power = pow(level, LEVEL_EXPONENT)
	
	# HP Calculation
	var hp_base = (base.hp * hp_mult) + (atomic_number * 2.0) + (level_power * HP_LEVEL_SCALING)
	final_stats["max_hp"] = int(hp_base)
	
	# Attack, Defense, Speed Calculations
	var atk_base = (base.atk * stat_mult) + (atomic_number * z_scaling) + (level_power * STAT_LEVEL_SCALING)
	final_stats["attack"] = int(atk_base)
	
	var def_base = (base.def * stat_mult) + (atomic_number * z_scaling) + (level_power * STAT_LEVEL_SCALING)
	final_stats["defense"] = int(def_base)
	
	# Speed scales less with level to prevent turn-order chaos in late game.
	var spd_base = (base.spd * stat_mult) + (atomic_number * 0.1) + (level_power * SPD_LEVEL_SCALING)
	final_stats["speed"] = int(spd_base)
	
	return final_stats

# Calculates the XP required to go from current_level to current_level + 1
# Scaling Factor: 2.3 (Steeper than stats to prevent early-game snowballing)
static func calculate_xp_requirement(current_level: int) -> int:
	const XP_BASE_COST = 50.0
	const XP_COST_EXPONENT = 2.3
	
	return int(XP_BASE_COST * pow(current_level, XP_COST_EXPONENT))