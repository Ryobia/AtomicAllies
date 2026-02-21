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
	UNKNOWN,
	VOID
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
	Group.UNKNOWN:         { "hp": 5, "atk": 5, "def": 5, "spd": 5 },
	Group.VOID:            { "hp": 4, "atk": 7, "def": 3, "spd": 6 }  # Null Walkers: Aggressive but fragile
}

# Calculates final stats based on Group Baseline, Atomic Number (Z), and Level.
static func calculate_stats(group: Group, atomic_number: int, level: int) -> Dictionary:
	var base = BASELINES.get(group, BASELINES[Group.UNKNOWN])
	
	var final_stats = {}
	
	# Simplified Linear Scaling
	# HP: Base (1-10) + Z (1-118) + Level (1-100)
	# Example: Base 5, Z 10, Level 10 -> (50) + (20) + (50) = 120 HP
	final_stats["max_hp"] = int((base.hp * 10.0) + (atomic_number * 2.0) + (level * 5.0))
	
	# Stats: Base (1-10) + Z (1-118) + Level (1-100)
	# Example: Base 5, Z 10, Level 10 -> (10) + (5) + (10) = 25 Stat
	final_stats["attack"] = int((base.atk * 2.0) + (atomic_number * 0.5) + (level * 1.0))
	final_stats["defense"] = int((base.def * 2.0) + (atomic_number * 0.5) + (level * 1.0))
	final_stats["speed"] = int((base.spd * 2.0) + (atomic_number * 0.2) + (level * 0.5))
	
	return final_stats

# Calculates the XP required to go from current_level to current_level + 1
static func calculate_xp_requirement(current_level: int) -> int:
	# Simplified: Linear cost
	# Level 1 -> 100 XP
	# Level 10 -> 1000 XP
	# Level 50 -> 5000 XP
	return current_level * 100