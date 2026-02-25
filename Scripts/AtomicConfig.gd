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
	_VOID_RESERVED, # Kept to preserve enum indices for existing resources
	NULL_GRUNT,
	NULL_TANK,
	NULL_COMMANDER
}

# Group Colors for UI
const GROUP_COLORS = {
	Group.ALKALI_METAL: Color("#ff4d4d"), # Red
	Group.ALKALINE_EARTH: Color("#ff9360"), # Orange
	Group.TRANSITION_METAL: Color("#ffe600"), # Gold
	Group.POST_TRANSITION: Color("#a0a0a0"), # Grey/Silver
	Group.METALLOID: Color("#ff69b4"), # Pink
	Group.NONMETAL: Color("#60fafc"), # Cyan
	Group.HALOGEN: Color("#802680"), # Purple
	Group.NOBLE_GAS: Color("#1e90ff"), # Blue
	Group.ACTINIDE: Color("#6dc000"), # Radioactive Green
	Group.LANTHANIDE: Color("#175e17"), # Dark Green
	Group.UNKNOWN: Color("#333333"),
	Group.NULL_GRUNT: Color("#4a4a4a"), # Dark Grey
	Group.NULL_TANK: Color("#2c3e50"), # Dark Blue-Grey
	Group.NULL_COMMANDER: Color("#8b0000") # Dark Red
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
	Group.NULL_GRUNT:      { "hp": 4, "atk": 5, "def": 3, "spd": 5 }, # Weak but balanced
	Group.NULL_TANK:       { "hp": 8, "atk": 3, "def": 8, "spd": 2 }, # Tough but slow
	Group.NULL_COMMANDER:  { "hp": 7, "atk": 8, "def": 6, "spd": 6 }  # Strong all-rounder
}

# Default Movesets based on Group
const GROUP_MOVES = {
	Group.ALKALI_METAL: [
		{ "name": "Electron Jettison", "power": 80, "accuracy": 90, "type": "Physical", "description": "High-speed dash. Deals massive damage but reduces Defense to zero for one turn." },
		{ "name": "Reactive Spark", "power": 40, "accuracy": 100, "type": "Physical", "is_snipe": true, "description": "Quick strike. Deals bonus damage if the enemy has recently moved or attacked." }
	],
	Group.ALKALINE_EARTH: [
		{ "name": "Oxidation Layer", "power": 0, "accuracy": 100, "type": "Status_Friendly", "description": "Increases Defense and Stability for 3 turns. Slows attackers." },
		{ "name": "Magnesium Flash", "power": 50, "accuracy": 95, "type": "Physical", "description": "Shield bash. Chance to stun the enemy, forcing order onto chaotic movement." }
	],
	Group.TRANSITION_METAL: [
		{ "name": "Metallic Bond", "power": 0, "accuracy": 100, "type": "Status_Friendly", "description": "Links HP with an ally. Shares damage taken, but both gain Attack boost." },
		{ "name": "Heavy Impact", "power": 70, "accuracy": 90, "type": "Physical", "description": "Reliable, high-damage physical strike that scales with current HP." }
	],
	Group.POST_TRANSITION: [
		{ "name": "Thermal Conduction", "power": 0, "accuracy": 100, "type": "Status_Friendly", "description": "Transfers a positive buff to an ally, or steals a debuff to dissipate it." },
		{ "name": "Alloy Reinforce", "power": 0, "accuracy": 100, "type": "Status_Friendly", "description": "Heals an ally's Stability Gauge by reinforcing their atomic structure." }
	],
	Group.METALLOID: [
		{ "name": "Semiconductor Flip", "power": 0, "accuracy": 100, "type": "Status_Hostile", "description": "Inverts the target's highest and lowest stats for 2 turns." },
		{ "name": "Signal Scramble", "power": 30, "accuracy": 100, "type": "Special", "is_snipe": true, "description": "Prevents the enemy from using their Special move on the next turn." }
	],
	Group.NONMETAL: [
		{ "name": "Covalent Link", "power": 0, "accuracy": 100, "type": "Status_Hostile", "description": "Marks enemy. Next attack from different element triggers triple damage." },
		{ "name": "Electronegativity", "power": 20, "accuracy": 95, "type": "Special", "is_snipe": true, "description": "Pulls a distant enemy closer and reduces their movement range." }
	],
	Group.HALOGEN: [
		{ "name": "Fluorine Acid", "power": 15, "accuracy": 90, "type": "Special", "is_snipe": true, "description": "Deals low initial damage but applies Corrosion debuff ignoring Defense." },
		{ "name": "Reactive Vapor", "power": 40, "accuracy": 100, "type": "Special", "description": "Creates a cloud that deals damage to any enemy that passes through it." }
	],
	Group.NOBLE_GAS: [
		{ "name": "Full Octet", "power": 0, "accuracy": 100, "type": "Status_Friendly", "description": "Immune to all damage/status for 1 turn, but cannot act." },
		{ "name": "Neon Glow", "power": 0, "accuracy": 100, "type": "Status_Friendly", "description": "Passive-style move that draws enemy aggro without moving." }
	],
	Group.ACTINIDE: [
		{ "name": "Supercritical Blast", "power": 120, "accuracy": 85, "type": "Special", "description": "Deals massive damage in a large area. High risk." },
		{ "name": "Radioactive Decay", "power": 0, "accuracy": 0, "type": "Passive", "description": "20% chance after move to lose HP or revert to lower atomic number." }
	],
	Group.LANTHANIDE: [
		{ "name": "Paramagnetic Pull", "power": 0, "accuracy": 100, "type": "Status_Hostile", "description": "Moves all enemies toward a center point, setting up for AOE." },
		{ "name": "Rare Resonance", "power": 60, "accuracy": 100, "type": "Special", "description": "Deals damage based on how many different element groups are on team." }
	],
	Group.UNKNOWN: [],
	Group.NULL_GRUNT: [
		{ "name": "Void Scratch", "power": 30, "accuracy": 100, "type": "Physical", "description": "Basic void attack." }
	],
	Group.NULL_TANK: [
		{ "name": "Void Harden", "power": 0, "accuracy": 100, "type": "Status_Friendly", "description": "Increases Defense." },
		{ "name": "Heavy Slam", "power": 50, "accuracy": 90, "type": "Physical", "description": "Heavy physical attack." }
	],
	Group.NULL_COMMANDER: [
		{ "name": "Void Command", "power": 0, "accuracy": 100, "type": "Status_Friendly", "description": "Buffs ally attack." },
		{ "name": "Obliterate", "power": 80, "accuracy": 85, "type": "Special", "description": "Powerful void blast." }
	]
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