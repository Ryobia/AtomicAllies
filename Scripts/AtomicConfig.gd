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
	# Void Race (Entropic, Dark)
	VOID_GRUNT, VOID_ASSASSIN, VOID_BRUTE, VOID_COMMANDER, VOID_KING,
	# Eldritch Race (Psychic, Alien)
	ELDRITCH_GRUNT, ELDRITCH_ASSASSIN, ELDRITCH_BRUTE, ELDRITCH_COMMANDER, ELDRITCH_KING,
	# Chaos Race (Glitchy, Unpredictable)
	CHAOS_GRUNT, CHAOS_ASSASSIN, CHAOS_BRUTE, CHAOS_COMMANDER, CHAOS_KING,
	# Fission Race (Radioactive, Explosive)
	FISSION_GRUNT, FISSION_ASSASSIN, FISSION_BRUTE, FISSION_COMMANDER, FISSION_KING,
	# Brood Race (Swarm, Organic)
	BROOD_GRUNT, BROOD_ASSASSIN, BROOD_BRUTE, BROOD_COMMANDER, BROOD_KING
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
	
	# Void
	Group.VOID_GRUNT: Color("#4a4a4a"), Group.VOID_ASSASSIN: Color("#2a2a2a"),
	Group.VOID_BRUTE: Color("#2c3e50"), Group.VOID_COMMANDER: Color("#8b0000"),
	Group.VOID_KING: Color("#000000"),
	
	# Eldritch
	Group.ELDRITCH_GRUNT: Color("#4b0082"), Group.ELDRITCH_ASSASSIN: Color("#800080"),
	Group.ELDRITCH_BRUTE: Color("#2e0854"), Group.ELDRITCH_COMMANDER: Color("#9932cc"),
	Group.ELDRITCH_KING: Color("#483d8b"),
	
	# Chaos
	Group.CHAOS_GRUNT: Color("#ff00ff"), Group.CHAOS_ASSASSIN: Color("#00ffff"),
	Group.CHAOS_BRUTE: Color("#ffff00"), Group.CHAOS_COMMANDER: Color("#ff4500"),
	Group.CHAOS_KING: Color("#ffffff"),
	
	# Fission
	Group.FISSION_GRUNT: Color("#adff2f"), Group.FISSION_ASSASSIN: Color("#7fff00"),
	Group.FISSION_BRUTE: Color("#32cd32"), Group.FISSION_COMMANDER: Color("#006400"),
	Group.FISSION_KING: Color("#00ff00"),
	
	# Brood
	Group.BROOD_GRUNT: Color("#8b4513"), Group.BROOD_ASSASSIN: Color("#a0522d"),
	Group.BROOD_BRUTE: Color("#cd853f"), Group.BROOD_COMMANDER: Color("#d2691e"),
	Group.BROOD_KING: Color("#800000")
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
	
	# Enemy Baselines (Grunt=Low, King=Boss)
	# Void: Balanced
	Group.VOID_GRUNT:      { "hp": 4, "atk": 4, "def": 4, "spd": 4 },
	Group.VOID_ASSASSIN:   { "hp": 3, "atk": 7, "def": 2, "spd": 8 },
	Group.VOID_BRUTE:      { "hp": 8, "atk": 5, "def": 8, "spd": 2 },
	Group.VOID_COMMANDER:  { "hp": 7, "atk": 7, "def": 6, "spd": 6 },
	Group.VOID_KING:       { "hp": 10,"atk": 9, "def": 9, "spd": 5 },
	
	# Eldritch: High Special/Status (Simulated via Atk/Spd)
	Group.ELDRITCH_GRUNT:     { "hp": 3, "atk": 5, "def": 3, "spd": 5 },
	Group.ELDRITCH_ASSASSIN:  { "hp": 4, "atk": 8, "def": 3, "spd": 7 },
	Group.ELDRITCH_BRUTE:     { "hp": 9, "atk": 4, "def": 6, "spd": 3 },
	Group.ELDRITCH_COMMANDER: { "hp": 6, "atk": 9, "def": 5, "spd": 6 },
	Group.ELDRITCH_KING:      { "hp": 10,"atk": 10,"def": 8, "spd": 4 },
	
	# Chaos: High Variance/Speed
	Group.CHAOS_GRUNT:     { "hp": 2, "atk": 6, "def": 2, "spd": 7 },
	Group.CHAOS_ASSASSIN:  { "hp": 3, "atk": 9, "def": 1, "spd": 9 },
	Group.CHAOS_BRUTE:     { "hp": 8, "atk": 6, "def": 5, "spd": 4 },
	Group.CHAOS_COMMANDER: { "hp": 6, "atk": 8, "def": 4, "spd": 8 },
	Group.CHAOS_KING:      { "hp": 9, "atk": 10,"def": 5, "spd": 10 },
	
	# Fission: High Damage/Low Health
	Group.FISSION_GRUNT:   { "hp": 3, "atk": 7, "def": 2, "spd": 5 },
	Group.FISSION_ASSASSIN:{ "hp": 4, "atk": 9, "def": 2, "spd": 7 },
	Group.FISSION_BRUTE:   { "hp": 7, "atk": 6, "def": 8, "spd": 3 },
	Group.FISSION_COMMANDER:{ "hp": 6, "atk": 9, "def": 4, "spd": 6 },
	Group.FISSION_KING:    { "hp": 9, "atk": 10,"def": 6, "spd": 5 },
	
	# Brood: Swarm/Regen (High HP, Low Def)
	Group.BROOD_GRUNT:     { "hp": 5, "atk": 4, "def": 2, "spd": 6 },
	Group.BROOD_ASSASSIN:  { "hp": 4, "atk": 7, "def": 2, "spd": 8 },
	Group.BROOD_BRUTE:     { "hp": 10,"atk": 5, "def": 4, "spd": 3 },
	Group.BROOD_COMMANDER: { "hp": 8, "atk": 6, "def": 5, "spd": 6 },
	Group.BROOD_KING:      { "hp": 12,"atk": 8, "def": 6, "spd": 5 }
}

# Default Movesets based on Group
const GROUP_MOVES = {
	Group.ALKALI_METAL: [
		{ "name": "Electron Jettison", "power": 60, "accuracy": 90, "type": "Physical", "description": "High-speed dash. Deals massive damage but reduces Defense to zero for one turn." },
		{ "name": "Reactive Spark", "power": 40, "accuracy": 100, "type": "Physical", "is_snipe": true, "description": "Quick strike. Can hit any enemy." }
	],
	Group.ALKALINE_EARTH: [
		{ "name": "Oxidation Layer", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Self", "description": "Increases Defense for 3 turns." },
		{ "name": "Magnesium Flash", "power": 50, "accuracy": 95, "type": "Physical", "description": "Shield bash. Chance to stun the enemy. Guarenteed stun if unit is currently shielded" }
	],
	Group.TRANSITION_METAL: [
		{ "name": "Metallic Bond", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Ally", "description": "Raises attack of self and target ally by 20 Percent for 1 turn" },
		{ "name": "Heavy Impact", "power": 70, "accuracy": 90, "type": "Physical", "description": "Reliable, high-damage physical strike that scales with current HP." }
	],
	Group.POST_TRANSITION: [
		{ "name": "Thermal Conduction", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Ally", "description": "Cleanses all debuffs from target ally." },
		{ "name": "Alloy Reinforce", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Ally", "description": "Heals target ally, scales with attack. Excess healing becomes a shield." }
	],
	Group.METALLOID: [
		{ "name": "Semiconductor Flip", "power": 0, "accuracy": 100, "type": "Status_Hostile", "description": "Swaps the target's Attack and Defense for 2 turns." },
		{ "name": "Signal Scramble", "power": 20, "accuracy": 100, "type": "Special", "is_snipe": true, "description": "Slows enemy by 20% for 2 turns." }
	],
	Group.NONMETAL: [
		{ "name": "Covalent Link", "power": 0, "accuracy": 100, "type": "Status_Hostile", "description": "Marks enemy. Next attack from different element triggers triple damage." },
		{ "name": "Electronegativity", "power": 20, "accuracy": 100, "type": "Special", "is_snipe": true, "description": "Slows enemy by 20% for 2 turns." }
	],
	Group.HALOGEN: [
		{ "name": "Fluorine Acid", "power": 10, "accuracy": 90, "type": "Special", "is_snipe": true, "description": "Corrosive blast that triggers Halogen poison." },
		{ "name": "Reactive Vapor", "power": 40, "accuracy": 100, "type": "Special", "description": "Deals damage and creates a hazard that hurts attackers." }
	],
	Group.NOBLE_GAS: [
		{ "name": "Full Octet", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Self", "description": "Immune to all damage/status for 1 turn. But cannot act for 1 turn." },
		{ "name": "Neon Glow", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Self", "description": "Draws enemy aggro (Taunt) and raises Defense by 20%." }
	],
	Group.ACTINIDE: [
		{ "name": "Supercritical Blast", "power": 120, "accuracy": 85, "type": "Special", "description": "Deals massive damage but reduces HP by 10% after use." },
		{ "name": "Radioactive Decay", "power": 0, "accuracy": 0, "type": "Passive", "description": "Lose 10% HP but apply radiation debuff to enemies." }
	],
	Group.LANTHANIDE: [
		{ "name": "Optical Refraction", "power": 0, "accuracy": 100, "type": "Status_Hostile", "description": "Reduces enemy accuracy by 20% for 2 turns." },
		{ "name": "Rare Resonance", "power": 20, "accuracy": 100, "type": "Special", "description": "Deals damage multiplied by the number of different element groups on the team." }
	],
	Group.UNKNOWN: [],
	
	# --- Enemy Movesets (Defaults) ---
	# Void
	Group.VOID_GRUNT: [{ "name": "Void Scratch", "power": 20, "accuracy": 100, "type": "Physical", "description": "Basic void attack." }],
	Group.VOID_ASSASSIN: [{ "name": "Shadow Strike", "power": 40, "accuracy": 100, "type": "Physical", "is_snipe": true, "description": "Snipe attack that bypasses the frontline." }],
	Group.VOID_BRUTE: [{ "name": "Void Harden", "power": 0, "type": "Status_Friendly", "target_type": "Self" }, { "name": "Heavy Slam", "power": 50, "accuracy": 90, "type": "Physical" }],
	Group.VOID_COMMANDER: [{ "name": "Void Command", "power": 0, "type": "Status_Friendly", "target_type": "Ally" }, { "name": "Obliterate", "power": 80, "accuracy": 85, "type": "Special" }],
	Group.VOID_KING: [{ "name": "Entropy", "power": 100, "accuracy": 100, "type": "Special", "description": "Deals massive damage." }],
	
	# Eldritch
	Group.ELDRITCH_GRUNT: [{ "name": "Mind Poke", "power": 20, "accuracy": 100, "type": "Special", "description": "Basic psychic attack." }],
	Group.ELDRITCH_ASSASSIN: [{ "name": "Psychic Knife", "power": 45, "accuracy": 100, "type": "Special", "is_snipe": true, "description": "Snipe attack that bypasses the frontline." }],
	Group.ELDRITCH_BRUTE: [{ "name": "Tentacle Crush", "power": 55, "accuracy": 90, "type": "Physical", "description": "Strong physical attack." }],
	Group.ELDRITCH_COMMANDER: [{ "name": "Madness Aura", "power": 0, "type": "Status_Hostile", "description": "Applies a random debuff to all enemies." }],
	Group.ELDRITCH_KING: [{ "name": "Cosmic Horror", "power": 120, "accuracy": 80, "type": "Special", "description": "Deals damage and reduces sanity." }],
	
	# Chaos
	Group.CHAOS_GRUNT: [{ "name": "Glitch Hit", "power": 30, "accuracy": 80, "type": "Physical", "description": "Unstable physical attack." }],
	Group.CHAOS_ASSASSIN: [{ "name": "Pixel Stab", "power": 50, "accuracy": 90, "type": "Physical", "description": "Strong physical attack." }],
	Group.CHAOS_BRUTE: [{ "name": "Static Shield", "power": 0, "type": "Status_Friendly", "target_type": "Self", "description": "Grants a shield and reflects damage." }],
	Group.CHAOS_COMMANDER: [{ "name": "Scramble", "power": 40, "accuracy": 100, "type": "Special", "description": "Deals damage and shuffles the target team's positions." }],
	Group.CHAOS_KING: [{ "name": "Reality Break", "power": 99, "accuracy": 50, "type": "Special", "description": "Deals massive damage with low accuracy." }],
	
	# Fission
	Group.FISSION_GRUNT: [{ "name": "Rad Bite", "power": 25, "accuracy": 95, "type": "Physical", "description": "Radioactive bite." }],
	Group.FISSION_ASSASSIN: [{ "name": "Gamma Ray", "power": 45, "accuracy": 100, "type": "Special", "is_snipe": true, "description": "High-accuracy snipe attack." }],
	Group.FISSION_BRUTE: [{ "name": "Lead Wall", "power": 0, "type": "Status_Friendly", "target_type": "Self", "description": "Grants a massive shield to self." }],
	Group.FISSION_COMMANDER: [{ "name": "Chain Reaction", "power": 60, "accuracy": 90, "type": "Special", "description": "Deals damage and triggers a chain reaction." }],
	Group.FISSION_KING: [{ "name": "Meltdown", "power": 150, "accuracy": 100, "type": "Special" }],
	
	# Brood
	Group.BROOD_GRUNT: [{ "name": "Mandible Bite", "power": 25, "accuracy": 95, "type": "Physical", "description": "Physical bite attack." }],
	Group.BROOD_ASSASSIN: [{ "name": "Neurotoxin", "power": 35, "accuracy": 100, "type": "Special", "is_snipe": true, "description": "Snipe attack that poisons the target." }],
	Group.BROOD_BRUTE: [{ "name": "Chitin Shell", "power": 0, "type": "Status_Friendly", "target_type": "Self", "description": "Grants a shield and increases Defense." }],
	Group.BROOD_COMMANDER: [{ "name": "Pheromones", "power": 0, "type": "Status_Friendly", "target_type": "Ally", "description": "Buffs Attack and Speed of all allies." }],
	Group.BROOD_KING: [{ "name": "Hive Mind", "power": 90, "accuracy": 100, "type": "Special", "description": "Deals damage and calls for reinforcements." }]
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
	
	# Lanthanide Full Set Bonus: +10% All Stats to ALL elements
	if PlayerData:
		var lanth_count = PlayerData.class_resonance.get(Group.LANTHANIDE, 0)
		var total_lanth = 0
		if MonsterManifest:
			for m in MonsterManifest.all_monsters:
				if m.group == Group.LANTHANIDE:
					total_lanth += 1
		
		if lanth_count >= total_lanth and total_lanth > 0:
			hp_mult += 0.10
			atk_mult += 0.10
			def_mult += 0.10
			spd_mult += 0.10
	
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