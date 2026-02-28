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
		{ "name": "Reactive Spark", "power": 40, "accuracy": 100, "type": "Physical", "is_snipe": true, "description": "Quick strike. Can hit any enemy." }
	],
	Group.ALKALINE_EARTH: [
		{ "name": "Oxidation Layer", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Self", "description": "Increases Defense and Stability for 3 turns. Slows attackers." },
		{ "name": "Magnesium Flash", "power": 50, "accuracy": 95, "type": "Physical", "description": "Shield bash. Chance to stun the enemy, forcing order onto chaotic movement." }
	],
	Group.TRANSITION_METAL: [
		{ "name": "Metallic Bond", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Ally", "description": "Links HP with an ally. Shares damage taken, but both gain Attack boost." },
		{ "name": "Heavy Impact", "power": 70, "accuracy": 90, "type": "Physical", "description": "Reliable, high-damage physical strike that scales with current HP." }
	],
	Group.POST_TRANSITION: [
		{ "name": "Thermal Conduction", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Ally", "description": "Transfers a positive buff to an ally, or steals a debuff to dissipate it." },
		{ "name": "Alloy Reinforce", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Ally", "description": "Heals an ally's Stability Gauge by reinforcing their atomic structure." }
	],
	Group.METALLOID: [
		{ "name": "Semiconductor Flip", "power": 0, "accuracy": 100, "type": "Status_Hostile", "description": "Inverts the target's highest and lowest stats for 2 turns." },
		{ "name": "Signal Scramble", "power": 30, "accuracy": 100, "type": "Special", "is_snipe": true, "description": "Prevents the enemy from using their Special move on the next turn." }
	],
	Group.NONMETAL: [
		{ "name": "Covalent Link", "power": 0, "accuracy": 100, "type": "Status_Hostile", "description": "Marks enemy. Next attack from different element triggers triple damage." },
		{ "name": "Electronegativity", "power": 20, "accuracy": 100, "type": "Special", "is_snipe": true, "description": "Pulls a distant enemy closer and reduces their speed." }
	],
	Group.HALOGEN: [
		{ "name": "Fluorine Acid", "power": 0, "accuracy": 90, "type": "Special", "is_snipe": true, "description": "Applies a poison to entire enemy team" },
		{ "name": "Reactive Vapor", "power": 40, "accuracy": 100, "type": "Special", "description": "Creates a cloud that deals damage to any enemy that passes through it." }
	],
	Group.NOBLE_GAS: [
		{ "name": "Full Octet", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Self", "description": "Immune to all damage/status for 1 turn, but cannot act." },
		{ "name": "Neon Glow", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Self", "description": "Passive-style move that draws enemy aggro without moving." }
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
		{ "name": "Void Scratch", "power": 20, "accuracy": 100, "type": "Physical", "description": "Basic void attack." }
	],
	Group.NULL_TANK: [
		{ "name": "Void Harden", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Self", "description": "Increases Defense." },
		{ "name": "Heavy Slam", "power": 50, "accuracy": 90, "type": "Physical", "description": "Heavy physical attack." }
	],
	Group.NULL_COMMANDER: [
		{ "name": "Void Command", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Ally", "description": "Buffs ally attack." },
		{ "name": "Obliterate", "power": 80, "accuracy": 85, "type": "Special", "description": "Powerful void blast." }
	]
}

# Calculates final stats based on Group Baseline, Atomic Number (Z), and Stability.
static func calculate_stats(group: Group, atomic_number: int, stability: int = 0) -> Dictionary:
	var base = BASELINES.get(group, BASELINES[Group.UNKNOWN])
	
	var final_stats = {}
	
	# 1. Resonance Bonus (Set Bonus): Scales based on total owned elements of this group
	var resonance_count = 0
	if PlayerData:
		resonance_count = PlayerData.class_resonance.get(group, 0)
	
	# Default Multipliers
	var hp_mult = 1.0
	var atk_mult = 1.0
	var def_mult = 1.0
	var spd_mult = 1.0
	
	match group:
		Group.ALKALINE_EARTH:
			def_mult += (resonance_count * 0.05) # +5% Def per element
		Group.NOBLE_GAS:
			hp_mult += (resonance_count * 0.05) # +5% HP per element
		Group.ACTINIDE:
			spd_mult += (resonance_count * 0.01) # +1% Speed per element
		Group.LANTHANIDE:
			var bonus = resonance_count * 0.01 # +1% All Stats per element
			hp_mult += bonus
			atk_mult += bonus
			def_mult += bonus
			spd_mult += bonus
	
	# 2. Stability Bonus: Scales stats up to +50% at 100 stability
	var stability_multiplier = 1.0 + (float(stability) / 200.0)
	
	# 3. Mastery Buff: At 100% Stability, unlock Class Potential (+10% extra stats)
	if stability >= 100:
		stability_multiplier += 0.1
		
	# Simplified Linear Scaling
	# HP: Base (1-10)
	# Example: Base 5 -> 50 HP
	final_stats["max_hp"] = int((base.hp * 10.0) * stability_multiplier * hp_mult)
	
	# Stats: Base (1-10)
	# Example: Base 5 -> 10 Stat
	final_stats["attack"] = int((base.atk * 2.0) * stability_multiplier * atk_mult)
	final_stats["defense"] = int((base.def * 2.0) * stability_multiplier * def_mult)
	final_stats["speed"] = int((base.spd * 2.0) * stability_multiplier * spd_mult)
	
	return final_stats

# Calculates the Binding Energy cost to fuse a new element
static func calculate_fusion_cost(target_z: int) -> int:
	# Cost scales exponentially/polynomially with Atomic Number.
	# Using quadratic scaling: 50 * Z^2. This ensures 1 Run ~= 1 Fusion.
	return int(50 * pow(target_z, 2))