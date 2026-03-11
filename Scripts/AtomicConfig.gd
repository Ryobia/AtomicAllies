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
	Group.ALKALI_METAL: {"hp": 2, "atk": 8, "def": 2, "spd": 8}, # Glass Cannons
	Group.ALKALINE_EARTH: {"hp": 6, "atk": 4, "def": 7, "spd": 3}, # Sturdy Tanks
	Group.TRANSITION_METAL: {"hp": 6, "atk": 5, "def": 5, "spd": 4}, # Bruisers
	Group.POST_TRANSITION: {"hp": 5, "atk": 5, "def": 5, "spd": 5}, # Utility
	Group.METALLOID: {"hp": 4, "atk": 6, "def": 4, "spd": 6}, # Disrupters
	Group.NONMETAL: {"hp": 4, "atk": 4, "def": 4, "spd": 7}, # Combo Primers
	Group.HALOGEN: {"hp": 3, "atk": 5, "def": 3, "spd": 8}, # DoT Assailants
	Group.NOBLE_GAS: {"hp": 5, "atk": 1, "def": 10, "spd": 4}, # Pure Walls
	Group.ACTINIDE: {"hp": 8, "atk": 10, "def": 5, "spd": 2}, # The Nukes
	Group.LANTHANIDE: {"hp": 7, "atk": 9, "def": 5, "spd": 3}, # Rare Earths (Similar to Actinides)
	Group.UNKNOWN: {"hp": 5, "atk": 5, "def": 5, "spd": 5},
	
	# Enemy Baselines (Grunt=Low, King=Boss)
	# Void: Balanced
	Group.VOID_GRUNT: {"hp": 4, "atk": 4, "def": 4, "spd": 4},
	Group.VOID_ASSASSIN: {"hp": 3, "atk": 7, "def": 2, "spd": 8},
	Group.VOID_BRUTE: {"hp": 8, "atk": 5, "def": 8, "spd": 2},
	Group.VOID_COMMANDER: {"hp": 7, "atk": 7, "def": 6, "spd": 6},
	Group.VOID_KING: {"hp": 10, "atk": 9, "def": 9, "spd": 5},
	
	# Eldritch: High Special/Status (Simulated via Atk/Spd)
	Group.ELDRITCH_GRUNT: {"hp": 3, "atk": 5, "def": 3, "spd": 5},
	Group.ELDRITCH_ASSASSIN: {"hp": 4, "atk": 8, "def": 3, "spd": 7},
	Group.ELDRITCH_BRUTE: {"hp": 9, "atk": 4, "def": 6, "spd": 3},
	Group.ELDRITCH_COMMANDER: {"hp": 6, "atk": 9, "def": 5, "spd": 6},
	Group.ELDRITCH_KING: {"hp": 10, "atk": 10, "def": 8, "spd": 4},
	
	# Chaos: High Variance/Speed
	Group.CHAOS_GRUNT: {"hp": 2, "atk": 6, "def": 2, "spd": 7},
	Group.CHAOS_ASSASSIN: {"hp": 3, "atk": 9, "def": 1, "spd": 9},
	Group.CHAOS_BRUTE: {"hp": 8, "atk": 6, "def": 5, "spd": 4},
	Group.CHAOS_COMMANDER: {"hp": 6, "atk": 8, "def": 4, "spd": 8},
	Group.CHAOS_KING: {"hp": 9, "atk": 10, "def": 5, "spd": 10},
	
	# Fission: High Damage/Low Health
	Group.FISSION_GRUNT: {"hp": 3, "atk": 7, "def": 2, "spd": 5},
	Group.FISSION_ASSASSIN: {"hp": 4, "atk": 9, "def": 2, "spd": 7},
	Group.FISSION_BRUTE: {"hp": 7, "atk": 6, "def": 8, "spd": 3},
	Group.FISSION_COMMANDER: {"hp": 6, "atk": 9, "def": 4, "spd": 6},
	Group.FISSION_KING: {"hp": 9, "atk": 10, "def": 6, "spd": 5},
	
	# Brood: Swarm/Regen (High HP, Low Def)
	Group.BROOD_GRUNT: {"hp": 5, "atk": 4, "def": 2, "spd": 6},
	Group.BROOD_ASSASSIN: {"hp": 4, "atk": 7, "def": 2, "spd": 8},
	Group.BROOD_BRUTE: {"hp": 10, "atk": 5, "def": 4, "spd": 3},
	Group.BROOD_COMMANDER: {"hp": 8, "atk": 6, "def": 5, "spd": 6},
	Group.BROOD_KING: {"hp": 12, "atk": 8, "def": 6, "spd": 5}
}

# Mastery Bonus Descriptions (100% Stability)
const MASTERY_BONUSES = {
	Group.ALKALI_METAL: "Mastery: Gain a free turn at the start of combat.",
	Group.ALKALINE_EARTH: "Mastery: Begin combat with a shield equal to 25% of Max HP.",
	Group.TRANSITION_METAL: "Mastery: The second hit from a double-attack deals full damage.",
	Group.POST_TRANSITION: "Mastery: Healing an ally also deals that much damage to a random enemy.",
	Group.METALLOID: "Mastery: Increases the chance to stun on-hit to 25%.",
	Group.NONMETAL: "Mastery: Chain Reactions can now also spread status effects.",
	Group.HALOGEN: "Mastery: At the start of combat, poisons a random enemy.",
	Group.NOBLE_GAS: "Mastery: Doubles passive HP regeneration to 10% per turn.",
	Group.ACTINIDE: "Mastery: Reduces passive HP decay from 10% to 5%.",
	Group.LANTHANIDE: "Mastery: Can now absorb stats from fallen allies as well as enemies."
}

# Default Movesets based on Group
const GROUP_MOVES = {
	Group.ALKALI_METAL: [
		{"name": "Electron Jettison", "power": 35, "accuracy": 90, "type": "Physical", "description": "High-speed dash. Deals massive damage but reduces Defense to zero for one turn.", "cooldown": 3, "effects": [{"type": "stat_mod", "stat": "defense", "amount": -100, "percent": true, "duration": 2, "target": "Attacker"}]},
		{"name": "Reactive Spark", "power": 30, "accuracy": 100, "type": "Physical", "is_snipe": true, "description": "Quick strike. Can hit any enemy.", "cooldown": 2}
	],
	Group.ALKALINE_EARTH: [
		{"name": "Oxidation Layer", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Self", "description": "Increases Defense for 3 turns.", "cooldown": 3, "effects": [{"type": "stat_mod", "stat": "defense", "amount": 50, "percent": true, "duration": 3, "target": "Self"}]},
		{"name": "Magnesium Flash", "power": 25, "accuracy": 95, "type": "Physical", "description": "Shield bash. Stuns the enemy if unit is currently shielded.", "cooldown": 2}
	],
	Group.TRANSITION_METAL: [
		{"name": "Metallic Bond", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Ally", "description": "Raises attack of self and target ally by 20 Percent for 1 turn", "cooldown": 3},
		{"name": "Heavy Impact", "power": 30, "accuracy": 90, "type": "Physical", "description": "Reliable, high-damage physical strike that scales with current HP.", "cooldown": 2}
	],
	Group.POST_TRANSITION: [
		{"name": "Thermal Conduction", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Ally", "description": "Cleanses 1 debuff from target ally.", "cooldown": 3, "effects": [{"effect": "cleanse", "target": "Ally", "amount": 1}]},
		{"name": "Alloy Reinforce", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Ally", "description": "Heals target ally, scales with attack. Excess healing becomes a shield.", "cooldown": 2}
	],
	Group.METALLOID: [
		{"name": "Semiconductor Flip", "power": 0, "accuracy": 100, "type": "Status_Hostile", "description": "Swaps the target's Attack and Defense for 2 turns.", "cooldown": 2, "effects": [{"effect": "swap_stats", "stats": ["attack", "defense"], "duration": 2}]},
		{"name": "Signal Scramble", "power": 20, "accuracy": 100, "type": "Special", "is_snipe": true, "description": "Slows enemy by 20% for 2 turns.", "cooldown": 2, "effects": [{"type": "stat_mod", "stat": "speed", "amount": -20, "percent": true, "duration": 2}]}
	],
	Group.NONMETAL: [
		{
			"name": "Covalent Link",
			"power": 0,
			"accuracy": 100,
			"type": "Status_Hostile",
			"description": "Marks enemy. Next attack from a different element deals bonus damage.",
			"effects": [ {
				"type": "status", "status": "marked_covalent", "duration": 3, "damage_multiplier": 1.2, "condition": "cross_element", "reaction_name": "Covalent Reaction", "message": "%s is marked for reaction!"
			}],
			"cooldown": 2
		},
		{"name": "Electronegativity", "power": 20, "accuracy": 100, "type": "Special", "is_snipe": true, "description": "Slows enemy by 20% for 2 turns.", "cooldown": 2, "effects": [{"type": "stat_mod", "stat": "speed", "amount": -20, "percent": true, "duration": 2}]}
	],
	Group.HALOGEN: [
		{"name": "Fluorine Acid", "power": 10, "accuracy": 90, "type": "Special", "is_snipe": true, "description": "Corrosive blast that triggers Halogen poison.", "cooldown": 2},
		{"name": "Reactivity", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Self", "description": "Increases Speed for 3 turns.", "effects": [{"type": "stat_mod", "stat": "speed", "amount": 25, "percent": true, "duration": 3}], "cooldown": 3}
	],
	Group.NOBLE_GAS: [
		{"name": "Full Octet", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Self", "description": "Blocks the next instance of damage. Consumed on hit.", "cooldown": 3, "effects": [{"type": "status", "status": "guarded", "duration": 3}]},
		{"name": "Neon Glow", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Self", "description": "Raises Defense by 20%.", "cooldown": 2, "effects": [{"type": "stat_mod", "stat": "defense", "amount": 20, "percent": true, "duration": 2}]}
	],
	Group.ACTINIDE: [
		{"name": "Supercritical Blast", "power": 80, "accuracy": 85, "type": "Special", "description": "Deals massive damage but reduces HP by 10% after use.", "cooldown": 3},
		{"name": "Radioactive Decay", "power": 0, "accuracy": 100, "type": "Status_Hostile", "is_snipe": true, "description": "Irradiates a specific target.", "effects": [{"type": "status", "status": "radiation", "damage_percent": 0.05, "duration": 3}], "cooldown": 2}
	],
	Group.LANTHANIDE: [
		{"name": "Optical Refraction", "power": 0, "accuracy": 100, "type": "Status_Hostile", "description": "Reduces enemy accuracy by 20% for 2 turns.", "cooldown": 2, "effects": [{"type": "status", "status": "refracted", "duration": 2}]},
		{"name": "Rare Resonance", "power": 10, "accuracy": 100, "type": "Special", "description": "Deals damage multiplied by the number of different element groups on the team.", "cooldown": 2}
	],
	Group.UNKNOWN: [],
	
	# --- Enemy Movesets (Defaults) ---
	# Void
	Group.VOID_GRUNT: [ {"name": "Void Scratch", "power": 20, "accuracy": 100, "type": "Physical", "description": "Basic void attack."}],
	Group.VOID_ASSASSIN: [ {"name": "Shadow Strike", "power": 40, "accuracy": 100, "type": "Physical", "is_snipe": true, "description": "Snipe attack that bypasses the frontline."}],
	Group.VOID_BRUTE: [ {"name": "Void Harden", "power": 0, "type": "Status_Friendly", "target_type": "Self", "effects": [{"type": "stat_mod", "stat": "defense", "amount": 20, "percent": true, "duration": 3}]}, {"name": "Heavy Slam", "power": 50, "accuracy": 90, "type": "Physical"}],
	Group.VOID_COMMANDER: [ {"name": "Void Command", "power": 0, "type": "Status_Friendly", "target_type": "Ally", "effects": [{"type": "stat_mod", "stat": "attack", "amount": 20, "percent": true, "duration": 3}, {"type": "stat_mod", "stat": "speed", "amount": 20, "percent": true, "duration": 3}]}, {"name": "Obliterate", "power": 80, "accuracy": 85, "type": "Special"}],
	Group.VOID_KING: [ {"name": "Entropy", "power": 100, "accuracy": 100, "type": "Special", "description": "Deals massive damage."}],
	
	# Eldritch
	Group.ELDRITCH_GRUNT: [ {"name": "Mind Poke", "power": 20, "accuracy": 100, "type": "Special", "description": "Basic psychic attack."}],
	Group.ELDRITCH_ASSASSIN: [ {"name": "Psychic Knife", "power": 45, "accuracy": 100, "type": "Special", "is_snipe": true, "description": "Snipe attack that bypasses the frontline."}],
	Group.ELDRITCH_BRUTE: [ {"name": "Tentacle Crush", "power": 55, "accuracy": 90, "type": "Physical", "description": "Strong physical attack."}],
	Group.ELDRITCH_COMMANDER: [ {"name": "Madness Aura", "power": 0, "type": "Status_Hostile", "description": "Applies a random debuff to all enemies."}],
	Group.ELDRITCH_KING: [ {"name": "Cosmic Horror", "power": 120, "accuracy": 80, "type": "Special", "description": "Deals damage and reduces sanity."}],
	
	# Chaos
	Group.CHAOS_GRUNT: [ {"name": "Glitch Hit", "power": 30, "accuracy": 80, "type": "Physical", "description": "Unstable physical attack."}],
	Group.CHAOS_ASSASSIN: [ {"name": "Pixel Stab", "power": 50, "accuracy": 90, "type": "Physical", "description": "Strong physical attack."}],
	Group.CHAOS_BRUTE: [ {"name": "Static Shield", "power": 0, "type": "Status_Friendly", "target_type": "Self", "description": "Grants a shield and reflects damage."}],
	Group.CHAOS_COMMANDER: [ {"name": "Scramble", "power": 40, "accuracy": 100, "type": "Special", "description": "Deals damage and shuffles the target team's positions."}],
	Group.CHAOS_KING: [ {"name": "Reality Break", "power": 99, "accuracy": 50, "type": "Special", "description": "Deals massive damage with low accuracy."}],
	
	# Fission
	Group.FISSION_GRUNT: [ {"name": "Rad Bite", "power": 25, "accuracy": 95, "type": "Physical", "description": "Radioactive bite."}],
	Group.FISSION_ASSASSIN: [ {"name": "Gamma Ray", "power": 45, "accuracy": 100, "type": "Special", "is_snipe": true, "description": "High-accuracy snipe attack."}],
	Group.FISSION_BRUTE: [ {"name": "Lead Wall", "power": 0, "type": "Status_Friendly", "target_type": "Self", "description": "Grants a massive shield to self."}],
	Group.FISSION_COMMANDER: [ {"name": "Chain Reaction", "power": 60, "accuracy": 90, "type": "Special", "description": "Deals damage and triggers a chain reaction."}],
	Group.FISSION_KING: [ {"name": "Meltdown", "power": 150, "accuracy": 100, "type": "Special"}],
	
	# Brood
	Group.BROOD_GRUNT: [ {"name": "Mandible Bite", "power": 25, "accuracy": 95, "type": "Physical", "description": "Physical bite attack."}],
	Group.BROOD_ASSASSIN: [ {"name": "Neurotoxin", "power": 35, "accuracy": 100, "type": "Special", "is_snipe": true, "description": "Snipe attack that poisons the target."}],
	Group.BROOD_BRUTE: [ {"name": "Chitin Shell", "power": 0, "type": "Status_Friendly", "target_type": "Self", "description": "Grants a shield and increases Defense."}],
	Group.BROOD_COMMANDER: [ {"name": "Pheromones", "power": 0, "type": "Status_Friendly", "target_type": "Ally", "description": "Buffs Attack and Speed of all allies."}],
	Group.BROOD_KING: [ {"name": "Hive Mind", "power": 90, "accuracy": 100, "type": "Special", "description": "Deals damage and calls for reinforcements."}]
}

# Unique Moves (Z -> Move Dictionary) - Placeholder for 118 elements
# This allows every element to have a signature move without manual resource creation.
const UNIQUE_MOVES = {
	1: { # Hydrogen
		"name": "Proton Pulse",
		"power": 25,
		"accuracy": 100,
		"type": "Special",
		"description": "A burst of raw energy. The target becomes unstable, taking 20% more damage from the next attack.",
		"effects": [ {"type": "status", "status": "unstable", "duration": 2, "damage_multiplier": 1.2, "message": "%s becomes unstable!"}],
		"cooldown": 2
	},
	2: { # Helium
		"name": "Atmospheric Veil",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"target_type": "Ally",
		"description": "Grants a shield equal to User's Defense to an ally.",
		"effects": [ {"effect": "add_shield", "scale_stat": "defense", "scale_factor": 1.0}],
		"cooldown": 2
	},
	3: { # Lithium
		"name": "Alkali Burst",
		"power": 15,
		"accuracy": 100,
		"type": "Physical",
		"description": "A quick double strike.",
		"target_type": "Enemy",
		"hit_count": 2,
		"effects": [],
		"cooldown": 2
	},
	4: { # Beryllium
		"name": "Emerald Fortify",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Doubles Defense and reflects 10% of incoming damage.",
		"target_type": "Self",
		"effects": [ 
			{"type": "stat_mod", "stat": "defense", "amount": 100, "percent": true, "duration": 3},
			{"type": "status", "status": "static_reflection", "damage_percent": 0.1, "duration": 3}
		],
		"cooldown": 3
	},
	5: { # Boron
		"name": "Boron Blast",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals damage and reduces Defense by 20%.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "defense", "amount": -20, "percent": true, "duration": 2}],
		"cooldown": 2
	},
	6: { # Carbon
		"name": "Carbonize",
		"power": 30,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals damage and makes the target unstable, taking 25% more damage.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "carbonized", "duration": 2, "damage_multiplier": 1.25, "message": "%s becomes carbonized!"}],
		"cooldown": 2
	},
	7: { # Nitrogen
		"name": "Nitrogen Nudge",
		"power": 30,
		"accuracy": 100,
		"type": "Status_Hostile",
		"description": "Reduces enemy Attack for 2 turns.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "attack", "amount": - 10, "percent": true, "duration": 2}],
		"cooldown": 2
	},
	8: { # Oxygen
		"name": "Oxidation Trap",
		"power": 30,
		"accuracy": 100,
		"type": "Special",
		"description": "Increases next instance of damage taken by target by 25%",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "oxidized", "duration": 2, "damage_multiplier": 1.25, "message": "%s becomes oxidized!"}],
		"cooldown": 2
	},
	9: { # Fluorine
		"name": "Reactive Corrosive",
		"power": 20,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals damage and applies a strong corrosive poison.",
		"target_type": "Enemy",
		"effects": [ 
			{"type": "status", "status": "poison", "damage_percent": 0.1, "duration": 3, "message": "%s is corroding!"},
			{"effect": "damage_percent", "amount": 0.1, "color": "#802680"}
		],
		"cooldown": 2
	},
	10: { # Neon
		"name": "Neon Distraction",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Taunts all enemies and increases Defense by 10%.",
		"target_type": "Self",
		"effects": [
			{"type": "status", "status": "taunt", "duration": 2},
			{"type": "stat_mod", "stat": "defense", "amount": 10, "percent": true, "duration": 2}
		],
		"cooldown": 3
	},
	11: { # Sodium
		"name": "Saline Surge",
		"power": 35,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and increases Speed by 10%.",
		"target_type": "Enemy",
		"effects": [
			{"type": "stat_mod", "stat": "speed", "amount": 10, "percent": true, "duration": 2, "target": "Attacker"}
		],
		"cooldown": 2
	},
	12: { # Magnesium
		"name": "Magnesium Flare",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Grants a shield equal to 30% of Max HP.",
		"target_type": "Self",
		"effects": [ {"effect": "add_shield", "scale_stat": "max_hp", "scale_factor": 0.3}],
		"cooldown": 3
	},
	13: { # Aluminum
		"name": "Alloy Coating",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Cleanses 1 debuff and grants 20% physical resistance for 3 turns.",
		"target_type": "Ally",
		"effects": [
			{"effect": "cleanse", "amount": 1},
			{"type": "status", "status": "physical_resist", "reduction_amount": 0.2, "duration": 3}
		],
		"cooldown": 3
	},
	14: { # Silicon
		"name": "Silicon Spike",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and reduces enemy Attack by 20%.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "attack", "amount": -20, "percent": true, "duration": 2}],
		"cooldown": 2
	},
	15: { # Phosphorus
		"name": "White Phosphorus",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Marks enemy for explosion. Next attack against them deals 30% bonus damage.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "explosive", "duration": 2, "damage_multiplier": 1.3, "message": "%s becomes explosive!"}],
		"cooldown": 2
	},
	16: { # Sulfur
		"name": "Sulfur Spray",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "A noxious spray that reduces enemy defense.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "defense", "amount": - 20, "percent": true, "duration": 2}],
		"cooldown": 2
	},
	17: { # Chlorine
		"name": "Chlorine Cloud",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Hostile",
		"description": "Applies a corrosive debuff.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "corrosion", "damage_percent": 0.05, "duration": 3}],
		"cooldown": 2
	},
	18: { # Argon
		"name": "Argon Aura",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Increases ally Defense for 2 turns.",
		"target_type": "Ally",
		"effects": [ {"type": "stat_mod", "stat": "defense", "amount": 10, "percent": true, "duration": 2}],
		"cooldown": 2
	},
	19: { # Potassium
		"name": "Potassium Power",
		"power": 60,
		"accuracy": 90,
		"type": "Physical",
		"description": "A powerful, explosive strike.",
		"target_type": "Enemy",
		"effects": [],
		"cooldown": 2
	},
	20: { # Calcium
		"name": "Calcium Carapace",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Grants a significant shield.",
		"target_type": "Self",
		"effects": [ {"type": "add_shield", "amount": 0.25}],
		"cooldown": 2
	},
	21: { # Scandium
		"name": "Scandium Slash",
		"power": 50,
		"accuracy": 100,
		"type": "Physical",
		"description": "A quick, precise attack.",
		"target_type": "Enemy",
		"effects": [],
		"cooldown": 2
	},
	22: { # Titanium
		"name": "Titanium Tackle",
		"power": 70,
		"accuracy": 85,
		"type": "Physical",
		"description": "Charges and slams into the enemy.",
		"target_type": "Enemy",
		"effects": []
	},
	23: { # Vanadium
		"name": "Vanadium Volley",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Fires multiple small projectiles.",
		"target_type": "Enemy",
		"effects": []
	},
	24: { # Chromium
		"name": "Chromium Crush",
		"power": 65,
		"accuracy": 90,
		"type": "Physical",
		"description": "A heavy, crushing blow.",
		"target_type": "Enemy",
		"effects": []
	},
	25: { # Manganese
		"name": "Manganese Mangle",
		"power": 55,
		"accuracy": 95,
		"type": "Physical",
		"description": "Tears at the enemy with sharp claws.",
		"target_type": "Enemy",
		"effects": []
	},
	26: { # Iron
		"name": "Ironclad Impact",
		"power": 75,
		"accuracy": 80,
		"type": "Physical",
		"description": "A devastating, armor-piercing attack.",
		"target_type": "Enemy",
		"effects": []
	},
	27: { # Cobalt
		"name": "Cobalt Coil",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Increases ally Speed for 2 turns.",
		"target_type": "Ally",
		"effects": [ {"type": "stat_mod", "stat": "speed", "amount": 10, "percent": true, "duration": 2}]
	},
	28: { # Nickel
		"name": "Nickel Nuke",
		"power": 80,
		"accuracy": 75,
		"type": "Special",
		"description": "A powerful, unstable energy burst.",
		"target_type": "Enemy",
		"effects": []
	},
	29: { # Copper
		"name": "Copper Current",
		"power": 45,
		"accuracy": 100,
		"type": "Special",
		"description": "Electrifies the enemy.",
		"target_type": "Enemy",
		"effects": []
	},
	30: { # Zinc
		"name": "Zinc Zone",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Creates a defensive zone, raising ally Defense.",
		"target_type": "Ally",
		"effects": [ {"type": "stat_mod", "stat": "defense", "amount": 10, "percent": true, "duration": 2}]
	},
	31: { # Gallium
		"name": "Gallium Goo",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Hostile",
		"description": "Slows enemy Speed for 2 turns.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "speed", "amount": - 10, "percent": true, "duration": 2}]
	},
	32: { # Germanium
		"name": "Germanium Glitch",
		"power": 50,
		"accuracy": 90,
		"type": "Special",
		"description": "A disruptive energy attack with a chance to stun.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "stun", "duration": 1, "chance": 0.15}]
	},
	33: { # Arsenic
		"name": "Arsenic Arrow",
		"power": 60,
		"accuracy": 95,
		"type": "Special",
		"description": "Fires a toxic projectile.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "poison", "damage_percent": 0.06, "duration": 3, "chance": 0.3}]
	},
	34: { # Selenium
		"name": "Photonic Overload",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Overloads the target's senses, making them unstable and take 40% more damage from the next attack.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "overload", "duration": 2, "damage_multiplier": 1.4, "message": "%s senses were overloaded!"}],
		"cooldown": 2
	},
	35: { # Bromine
		"name": "Bromine Barrage",
		"power": 55,
		"accuracy": 90,
		"type": "Special",
		"description": "Unleashes a volley of corrosive energy.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "corrosion", "damage_percent": 0.06, "duration": 3}]
	},
	36: { # Krypton
		"name": "Krypton Cloak",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Increases Evasion (Speed) for 2 turns.",
		"target_type": "Self",
		"effects": [ {"type": "stat_mod", "stat": "speed", "amount": 20, "percent": true, "duration": 2}]
	},
	37: { # Rubidium
		"name": "Rubidium Rupture",
		"power": 65,
		"accuracy": 85,
		"type": "Physical",
		"description": "A devastating, high-impact attack.",
		"target_type": "Enemy",
		"effects": []
	},
	38: { # Strontium
		"name": "Strontium Stance",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Greatly raises Defense for 2 turns.",
		"target_type": "Self",
		"effects": [ {"type": "stat_mod", "stat": "defense", "amount": 20, "percent": true, "duration": 2}]
	},
	39: { # Yttrium
		"name": "Yttrium Yield",
		"power": 50,
		"accuracy": 100,
		"type": "Physical",
		"description": "A balanced offensive move.",
		"target_type": "Enemy",
		"effects": []
	},
	40: { # Zirconium
		"name": "Zirconium Zone",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Creates a protective field, granting a shield to all allies.",
		"target_type": "Ally",
		"effects": [ {"type": "add_shield", "amount": 0.1}]
	},
	41: { # Niobium
		"name": "Niobium Nullify",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Hostile",
		"description": "Reduces enemy Attack and Defense for 2 turns.",
		"target_type": "Enemy",
		"effects": [ 
			{"type": "stat_mod", "stat": "attack", "amount": - 10, "percent": true, "duration": 2}, 
			{"type": "stat_mod", "stat": "defense", "amount": - 10, "percent": true, "duration": 2}
		]
	},
	42: { # Molybdenum
		"name": "Molybdenum Maelstrom",
		"power": 70,
		"accuracy": 85,
		"type": "Special",
		"description": "Unleashes a swirling vortex of energy.",
		"target_type": "Enemy",
		"effects": []
	},
	43: { # Technetium
		"name": "Technetium Tangle",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Hostile",
		"description": "Applies a debuff that reduces enemy Speed.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "speed", "amount": - 15, "percent": true, "duration": 2}]
	},
	44: { # Ruthenium
		"name": "Ruthenium Rush",
		"power": 60,
		"accuracy": 95,
		"type": "Physical",
		"description": "A rapid, piercing attack.",
		"target_type": "Enemy",
		"effects": []
	},
	45: { # Rhodium
		"name": "Rhodium Radiance",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Heals a moderate amount of HP to an ally.",
		"target_type": "Ally",
		"effects": [ {"type": "heal", "amount": 40}]
	},
	46: { # Palladium
		"name": "Palladium Pulse",
		"power": 50,
		"accuracy": 100,
		"type": "Special",
		"description": "Emits a wave of energy that can stun.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "stun", "duration": 1, "chance": 0.2}]
	},
	47: { # Silver
		"name": "Silver Shard",
		"power": 55,
		"accuracy": 90,
		"type": "Physical",
		"description": "Hurls a sharp, reflective shard.",
		"target_type": "Enemy",
		"effects": []
	},
	48: { # Cadmium
		"name": "Cadmium Cage",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Hostile",
		"description": "Traps an enemy, preventing them from acting for 1 turn.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "stun", "duration": 1}]
	},
	49: { # Indium
		"name": "Indium Infusion",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Increases ally Defense and Speed for 2 turns.",
		"target_type": "Ally",
		"effects": [ 
			{"type": "stat_mod", "stat": "defense", "amount": 10, "percent": true, "duration": 2}, 
			{"type": "stat_mod", "stat": "speed", "amount": 10, "percent": true, "duration": 2}
		]
	},
	50: { # Tin
		"name": "Tin Tangle",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "A sticky, slowing attack.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "speed", "amount": - 10, "percent": true, "duration": 2, "chance": 0.5}]
	},
	51: { # Antimony
		"name": "Antimony Aura",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Hostile",
		"description": "Reduces enemy Attack for 2 turns.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "attack", "amount": - 15, "percent": true, "duration": 2}]
	},
	52: { # Tellurium
		"name": "Tellurium Tremor",
		"power": 60,
		"accuracy": 90,
		"type": "Special",
		"description": "Causes a localized tremor, damaging all enemies.",
		"target_type": "Enemy",
		"effects": []
	},
	53: { # Iodine
		"name": "Iodine Implosion",
		"power": 70,
		"accuracy": 85,
		"type": "Special",
		"description": "A powerful, corrosive explosion.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "corrosion", "damage_percent": 0.08, "duration": 3}]
	},
	54: { # Xenon
		"name": "Xenon X-Ray",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Hostile",
		"description": "Reveals enemy weaknesses, increasing damage taken.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "vulnerable", "duration": 2}]
	},
	55: { # Cesium
		"name": "Cesium Cascade",
		"power": 80,
		"accuracy": 80,
		"type": "Physical",
		"description": "A highly volatile, chain reaction attack.",
		"target_type": "Enemy",
		"effects": []
	},
	56: { # Barium
		"name": "Barium Bulwark",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Grants a massive shield to an ally.",
		"target_type": "Ally",
		"effects": [ {"type": "add_shield", "amount": 0.35}]
	},
	57: { # Lanthanum
		"name": "Lanthanum Lure",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Hostile",
		"description": "Draws enemy attention (Taunt) to a target.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "taunt", "duration": 2}]
	},
	58: { # Cerium
		"name": "Cerium Charge",
		"power": 60,
		"accuracy": 95,
		"type": "Physical",
		"description": "A strong, direct attack.",
		"target_type": "Enemy",
		"effects": []
	},
	59: { # Praseodymium
		"name": "Praseodymium Pierce",
		"power": 55,
		"accuracy": 100,
		"type": "Physical",
		"description": "Pierces enemy defenses.",
		"target_type": "Enemy",
		"effects": []
	},
	60: { # Neodymium
		"name": "Neodymium Nova",
		"power": 70,
		"accuracy": 85,
		"type": "Special",
		"description": "Unleashes a powerful energy burst.",
		"target_type": "Enemy",
		"effects": []
	},
	61: { # Promethium
		"name": "Promethium Pulse",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Heals all allies for a small amount.",
		"target_type": "Ally",
		"effects": [ {"type": "heal", "amount": 25, "target": "All_Allies"}]
	},
	62: { # Samarium
		"name": "Samarium Smash",
		"power": 80,
		"accuracy": 80,
		"type": "Physical",
		"description": "A heavy, concussive blow.",
		"target_type": "Enemy",
		"effects": []
	},
	63: { # Europium
		"name": "Europium Embrace",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Grants invulnerability for 1 turn.",
		"target_type": "Self",
		"effects": [ {"type": "status", "status": "invulnerable", "duration": 1}],
		"cooldown": 4
	},
	64: { # Gadolinium
		"name": "Gadolinium Glare",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Hostile",
		"description": "Reduces enemy accuracy.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "refracted", "duration": 2}]
	},
	65: { # Terbium
		"name": "Terbium Torrent",
		"power": 65,
		"accuracy": 90,
		"type": "Special",
		"description": "A continuous stream of damaging energy.",
		"target_type": "Enemy",
		"effects": []
	},
	66: { # Dysprosium
		"name": "Dysprosium Drain",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Drains HP from the enemy.",
		"target_type": "Enemy",
		"effects": [ {"type": "heal", "amount": 20, "target": "Attacker"}]
	},
	67: { # Holmium
		"name": "Holmium Hammer",
		"power": 75,
		"accuracy": 85,
		"type": "Physical",
		"description": "A crushing, powerful attack.",
		"target_type": "Enemy",
		"effects": []
	},
	68: { # Erbium
		"name": "Erbium Echo",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Copies a positive status effect from an ally.",
		"target_type": "Ally",
		"effects": []
	},
	69: { # Thulium
		"name": "Thulium Thrust",
		"power": 50,
		"accuracy": 100,
		"type": "Physical",
		"description": "A precise, rapid thrust.",
		"target_type": "Enemy",
		"effects": []
	},
	70: { # Ytterbium
		"name": "Ytterbium Yield",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Increases ally Attack and Defense for 2 turns.",
		"target_type": "Ally",
		"effects": [ 
			{"type": "stat_mod", "stat": "attack", "amount": 10, "percent": true, "duration": 2}, 
			{"type": "stat_mod", "stat": "defense", "amount": 10, "percent": true, "duration": 2}
		]
	},
	71: { # Lutetium
		"name": "Lutetium Lacerate",
		"power": 60,
		"accuracy": 95,
		"type": "Physical",
		"description": "Slashes the enemy with sharp edges.",
		"target_type": "Enemy",
		"effects": []
	},
	72: { # Hafnium
		"name": "Hafnium Halt",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Hostile",
		"description": "Stuns an enemy for 1 turn.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "stun", "duration": 1}]
	},
	73: { # Tantalum
		"name": "Tantalum Tangle",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Hostile",
		"description": "Reduces enemy Speed and Defense for 2 turns.",
		"target_type": "Enemy",
		"effects": [ 
			{"type": "stat_mod", "stat": "speed", "amount": - 10, "percent": true, "duration": 2}, 
			{"type": "stat_mod", "stat": "defense", "amount": - 10, "percent": true, "duration": 2}
		]
	},
	74: { # Tungsten
		"name": "Tungsten Tremor",
		"power": 85,
		"accuracy": 75,
		"type": "Physical",
		"description": "A ground-shaking, powerful attack.",
		"target_type": "Enemy",
		"effects": []
	},
	75: { # Rhenium
		"name": "Rhenium Rupture",
		"power": 70,
		"accuracy": 90,
		"type": "Special",
		"description": "Creates a localized rupture, dealing damage.",
		"target_type": "Enemy",
		"effects": []
	},
	76: { # Osmium
		"name": "Osmium Overload",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Greatly increases ally Attack for 2 turns.",
		"target_type": "Ally",
		"effects": [ {"type": "stat_mod", "stat": "attack", "amount": 20, "percent": true, "duration": 2}]
	},
	77: { # Iridium
		"name": "Iridium Impale",
		"power": 60,
		"accuracy": 95,
		"type": "Physical",
		"description": "Impales the enemy with a sharp spike.",
		"target_type": "Enemy",
		"effects": []
	},
	78: { # Platinum
		"name": "Platinum Plating",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Grants a strong shield to an ally.",
		"target_type": "Ally",
		"effects": [ {"type": "add_shield", "amount": 0.3}]
	},
	79: { # Gold
		"name": "Golden Glow",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Heals a large amount of HP to an ally.",
		"target_type": "Ally",
		"effects": [ {"type": "heal", "amount": 60}]
	},
	80: { # Mercury
		"name": "Mercury Muddle",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Hostile",
		"description": "Confuses enemy, reducing accuracy and speed.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "insanity", "duration": 2}]
	},
	81: { # Thallium
		"name": "Thallium Toxin",
		"power": 50,
		"accuracy": 95,
		"type": "Special",
		"description": "A highly toxic attack with a strong poison.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "poison", "damage_percent": 0.08, "duration": 4}]
	},
	82: { # Lead
		"name": "Lead Lull",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Hostile",
		"description": "Greatly reduces enemy Speed for 2 turns.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "speed", "amount": - 20, "percent": true, "duration": 2}]
	},
	83: { # Bismuth
		"name": "Bismuth Burst",
		"power": 70,
		"accuracy": 85,
		"type": "Special",
		"description": "A colorful, damaging explosion.",
		"target_type": "Enemy",
		"effects": []
	},
	84: { # Polonium
		"name": "Polonium Plague",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Hostile",
		"description": "Applies a potent corrosive debuff to all enemies.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "corrosion", "damage_percent": 0.08, "duration": 4, "target": "All_Enemies"}]
	},
	85: { # Astatine
		"name": "Astatine Assault",
		"power": 80,
		"accuracy": 80,
		"type": "Special",
		"description": "A highly radioactive, damaging attack.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "radiation", "damage_percent": 0.05, "duration": 3}]
	},
	86: { # Radon
		"name": "Radon Repel",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Grants invulnerability to an ally for 1 turn.",
		"target_type": "Ally",
		"effects": [ {"type": "status", "status": "invulnerable", "duration": 1}]
	},
	87: { # Francium
		"name": "Francium Flare",
		"power": 90,
		"accuracy": 75,
		"type": "Physical",
		"description": "An extremely powerful, volatile strike.",
		"target_type": "Enemy",
		"effects": []
	},
	88: { # Radium
		"name": "Radium Radiance",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Heals all allies for a moderate amount.",
		"target_type": "Ally",
		"effects": [ {"type": "heal", "amount": 50, "target": "All_Allies"}]
	},
	89: { # Actinium
		"name": "Actinium Annihilate",
		"power": 100,
		"accuracy": 70,
		"type": "Special",
		"description": "A devastating, high-recoil attack.",
		"target_type": "Enemy",
		"effects": [ {"type": "recoil", "amount": 0.15, "percent": true, "target": "Attacker"}]
	},
	90: { # Thorium
		"name": "Thorium Tremor",
		"power": 80,
		"accuracy": 85,
		"type": "Physical",
		"description": "Causes a massive tremor, damaging all enemies.",
		"target_type": "Enemy",
		"effects": [ {"type": "damage", "amount": 60, "target": "All_Enemies"}]
	},
	91: { # Protactinium
		"name": "Protactinium Pierce",
		"power": 70,
		"accuracy": 90,
		"type": "Physical",
		"description": "Pierces through enemy defenses.",
		"target_type": "Enemy",
		"effects": []
	},
	92: { # Uranium
		"name": "Uranium Unleash",
		"power": 110,
		"accuracy": 65,
		"type": "Special",
		"description": "Unleashes a highly unstable, massive energy burst.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "radiation", "damage_percent": 0.1, "duration": 4}]
	},
	93: { # Neptunium
		"name": "Neptunium Nova",
		"power": 95,
		"accuracy": 70,
		"type": "Special",
		"description": "A powerful, wide-area energy explosion.",
		"target_type": "Enemy",
		"effects": [ {"type": "damage", "amount": 70, "target": "All_Enemies"}]
	},
	94: { # Plutonium
		"name": "Plutonium Pulse",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Hostile",
		"description": "Applies a potent corrosive and radiation debuff.",
		"target_type": "Enemy",
		"effects": [ 
			{"type": "status", "status": "corrosion", "damage_percent": 0.1, "duration": 4}, 
			{"type": "status", "status": "radiation", "damage_percent": 0.1, "duration": 4}
		]
	},
	95: { # Americium
		"name": "Americium Amplify",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Greatly increases ally Attack and Speed for 2 turns.",
		"target_type": "Ally",
		"effects": [ 
			{"type": "stat_mod", "stat": "attack", "amount": 20, "percent": true, "duration": 2}, 
			{"type": "stat_mod", "stat": "speed", "amount": 20, "percent": true, "duration": 2}
		]
	},
	96: { # Curium
		"name": "Curium Crush",
		"power": 105,
		"accuracy": 70,
		"type": "Physical",
		"description": "A crushing blow that ignores defense.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "defense", "amount": - 100, "percent": true, "duration": 1, "target": "Defender"}]
	},
	97: { # Berkelium
		"name": "Berkelium Barrage",
		"power": 85,
		"accuracy": 80,
		"type": "Special",
		"description": "Fires a barrage of highly energetic particles.",
		"target_type": "Enemy",
		"effects": []
	},
	98: { # Californium
		"name": "Californium Cataclysm",
		"power": 120,
		"accuracy": 60,
		"type": "Special",
		"description": "A devastating, wide-area energy attack.",
		"target_type": "Enemy",
		"effects": [ {"type": "damage", "amount": 80, "target": "All_Enemies"}],
		"cooldown": 3
	},
	99: { # Einsteinium
		"name": "Einsteinium Enigma",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Hostile",
		"description": "Swaps enemy Attack and Speed for 2 turns.",
		"target_type": "Enemy",
		"effects": [ {"type": "swap_stats", "stats": ["attack", "speed"], "duration": 2}]
	},
	100: { # Fermium
		"name": "Fermium Force",
		"power": 90,
		"accuracy": 75,
		"type": "Physical",
		"description": "A raw, brute force attack.",
		"target_type": "Enemy",
		"effects": []
	},
	101: { # Mendelevium
		"name": "Mendelevium Mind",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Hostile",
		"description": "Applies a potent confusion debuff.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "insanity", "duration": 3}]
	},
	102: { # Nobelium
		"name": "Nobelium Nova",
		"power": 100,
		"accuracy": 70,
		"type": "Special",
		"description": "A brilliant, destructive energy burst.",
		"target_type": "Enemy",
		"effects": []
	},
	103: { # Lawrencium
		"name": "Lawrencium Lacerate",
		"power": 80,
		"accuracy": 85,
		"type": "Physical",
		"description": "Slashes with extreme precision and power.",
		"target_type": "Enemy",
		"effects": []
	},
	104: { # Rutherfordium
		"name": "Rutherfordium Rupture",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Hostile",
		"description": "Creates a void rupture, dealing damage over time.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "corrosion", "damage_percent": 0.1, "duration": 5}]
	},
	105: { # Dubnium
		"name": "Dubnium Drain",
		"power": 60,
		"accuracy": 95,
		"type": "Special",
		"description": "Drains HP and Energy from the enemy.",
		"target_type": "Enemy",
		"effects": [ {"type": "heal", "amount": 30, "target": "Attacker"}]
	},
	106: { # Seaborgium
		"name": "Seaborgium Surge",
		"power": 115,
		"accuracy": 60,
		"type": "Physical",
		"description": "A massive, overwhelming physical attack.",
		"target_type": "Enemy",
		"effects": []
	},
	107: { # Bohrium
		"name": "Bohrium Barrier",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Grants a powerful shield to all allies.",
		"target_type": "Ally",
		"effects": [ {"type": "add_shield", "amount": 0.2, "target": "All_Allies"}]
	},
	108: { # Hassium
		"name": "Hassium Hammer",
		"power": 100,
		"accuracy": 70,
		"type": "Physical",
		"description": "A crushing blow that can stun.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "stun", "duration": 1, "chance": 0.25}]
	},
	109: { # Meitnerium
		"name": "Meitnerium Maelstrom",
		"power": 120,
		"accuracy": 55,
		"type": "Special",
		"description": "Unleashes a chaotic, high-damage energy storm.",
		"target_type": "Enemy",
		"effects": []
	},
	110: { # Darmstadtium
		"name": "Darmstadtium Disperse",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Hostile",
		"description": "Disperses enemy buffs, removing them.",
		"target_type": "Enemy",
		"effects": [ {"type": "cleanse_buffs", "target": "Enemy"}]
	},
	111: { # Roentgenium
		"name": "Roentgenium Ray",
		"power": 90,
		"accuracy": 75,
		"type": "Special",
		"description": "Fires a concentrated, piercing energy ray.",
		"target_type": "Enemy",
		"effects": []
	},
	112: { # Copernicium
		"name": "Copernicium Coil",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Increases ally Speed and Attack for 2 turns.",
		"target_type": "Ally",
		"effects": [ 
			{"type": "stat_mod", "stat": "speed", "amount": 15, "percent": true, "duration": 2}, 
			{"type": "stat_mod", "stat": "attack", "amount": 15, "percent": true, "duration": 2}
		]
	},
	113: { # Nihonium
		"name": "Nihonium Nullify",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Hostile",
		"description": "Nullifies enemy abilities, silencing them for 2 turns.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "silence_special", "duration": 2}]
	},
	114: { # Flerovium
		"name": "Flerovium Flare",
		"power": 130,
		"accuracy": 50,
		"type": "Special",
		"description": "A blinding, high-damage energy flare.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "stun", "duration": 1, "chance": 0.3}]
	},
	115: { # Moscovium
		"name": "Moscovium Maelstrom",
		"power": 100,
		"accuracy": 65,
		"type": "Physical",
		"description": "A chaotic, multi-hit physical attack.",
		"target_type": "Enemy",
		"effects": []
	},
	116: { # Livermorium
		"name": "Livermorium Lunge",
		"power": 110,
		"accuracy": 60,
		"type": "Physical",
		"description": "A powerful, reckless lunge.",
		"target_type": "Enemy",
		"effects": [ {"type": "recoil", "amount": 0.2, "percent": true, "target": "Attacker"}]
	},
	117: { # Tennessine
		"name": "Tennessine Tangle",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Hostile",
		"description": "Applies a complex debuff, reducing all enemy stats.",
		"target_type": "Enemy",
		"effects": [ 
			{"type": "stat_mod", "stat": "attack", "amount": - 10, "percent": true, "duration": 3}, 
			{"type": "stat_mod", "stat": "defense", "amount": - 10, "percent": true, "duration": 3}, 
			{"type": "stat_mod", "stat": "speed", "amount": - 10, "percent": true, "duration": 3}
		]
	},
	118: { # Oganesson
		"name": "Oganesson Oblivion",
		"power": 150,
		"accuracy": 40,
		"type": "Special",
		"description": "A catastrophic, highly unstable attack with massive damage.",
		"target_type": "Enemy",
		"effects": [ {"type": "recoil", "amount": 0.3, "percent": true, "target": "Attacker"}],
		"cooldown": 5
	}
}

# Calculates final stats based on Group Baseline, Atomic Number (Z), and Stability.
static func calculate_stats(group: Group, atomic_number: int, stability: int = 0) -> Dictionary:
	var result = calculate_stats_with_breakdown(group, atomic_number, stability)
	return result["final_stats"]

static func calculate_stats_with_breakdown(group: Group, atomic_number: int, stability: int = 0) -> Dictionary:
	var base = BASELINES.get(group, BASELINES[Group.UNKNOWN])
	
	var breakdown = {
		"hp": {"base": base.hp * 10.0, "stability": 0.0, "resonance": 0.0, "ship_upgrade": 0.0, "lanthanide_set": 0.0},
		"atk": {"base": base.atk * 2.0, "stability": 0.0, "resonance": 0.0, "ship_upgrade": 0.0, "lanthanide_set": 0.0},
		"def": {"base": base.def * 2.0, "stability": 0.0, "resonance": 0.0, "ship_upgrade": 0.0, "lanthanide_set": 0.0},
		"spd": {"base": base.spd * 2.0, "stability": 0.0, "resonance": 0.0, "ship_upgrade": 0.0, "lanthanide_set": 0.0},
	}
	
	# 1. Resonance Bonus (Set Bonus): Scales based on total owned elements of this group
	var resonance_count = 0
	if PlayerData:
		resonance_count = PlayerData.class_resonance.get(group, 0)
	
	# Default Multipliers
	var hp_mult = 1.0
	var atk_mult = 1.0
	var def_mult = 1.0
	var spd_mult = 1.0
	
	# Ship Upgrades (Combat)
	if PlayerData:
		breakdown.hp.ship_upgrade = PlayerData.get_upgrade_level("combat_hull") * 0.05
		breakdown.atk.ship_upgrade = PlayerData.get_upgrade_level("combat_optics") * 0.05
		breakdown.def.ship_upgrade = PlayerData.get_upgrade_level("combat_shielding") * 0.05
		hp_mult += breakdown.hp.ship_upgrade
		atk_mult += breakdown.atk.ship_upgrade
		def_mult += breakdown.def.ship_upgrade
	
	match group:
		Group.ALKALINE_EARTH:
			breakdown.def.resonance = (resonance_count * 0.05) # +5% Def per element
			def_mult += breakdown.def.resonance
		Group.NOBLE_GAS:
			breakdown.hp.resonance = (resonance_count * 0.05) # +5% HP per element
			hp_mult += breakdown.hp.resonance
		Group.ACTINIDE:
			breakdown.spd.resonance = (resonance_count * 0.01) # +1% Speed per element
			spd_mult += breakdown.spd.resonance
		Group.LANTHANIDE:
			var bonus = resonance_count * 0.01 # +1% All Stats per element
			breakdown.hp.resonance = bonus; breakdown.atk.resonance = bonus; breakdown.def.resonance = bonus; breakdown.spd.resonance = bonus
			hp_mult += bonus; atk_mult += bonus; def_mult += bonus; spd_mult += bonus
	
	# Lanthanide Full Set Bonus: +10% All Stats to ALL elements
	if PlayerData:
		var lanth_count = PlayerData.class_resonance.get(Group.LANTHANIDE, 0)
		var total_lanth = 0
		if MonsterManifest:
			for m in MonsterManifest.all_monsters:
				if m.get("group") == Group.LANTHANIDE or (m.has_method("get_group") and m.get_group() == Group.LANTHANIDE):
					total_lanth += 1
		
		if lanth_count >= total_lanth and total_lanth > 0:
			breakdown.hp.lanthanide_set = 0.10; breakdown.atk.lanthanide_set = 0.10;
			breakdown.def.lanthanide_set = 0.10; breakdown.spd.lanthanide_set = 0.10;
			hp_mult += 0.10; atk_mult += 0.10; def_mult += 0.10; spd_mult += 0.10
	
	# 2. Stability Bonus: Scales stats up to +50% at 100 stability
	var stability_multiplier = 1.0 + (float(stability) / 200.0)
	var stability_bonus = stability_multiplier - 1.0
	
	# 3. Mastery Buff: At 100% Stability, unlock Class Potential (+10% extra stats)
	if stability >= 100:
		stability_multiplier += 0.1
		stability_bonus += 0.1
	
	breakdown.hp.stability = stability_bonus
	breakdown.atk.stability = stability_bonus
	breakdown.def.stability = stability_bonus
	breakdown.spd.stability = stability_bonus
	
	var final_stats = {}
	# Simplified Linear Scaling
	# HP: Base (1-10)
	# Example: Base 5 -> 50 HP
	final_stats["max_hp"] = int((base.hp * 10.0) * stability_multiplier * hp_mult)
	
	# Stats: Base (1-10)
	# Example: Base 5 -> 10 Stat
	final_stats["attack"] = int((base.atk * 2.0) * stability_multiplier * atk_mult)
	final_stats["defense"] = int((base.def * 2.0) * stability_multiplier * def_mult)
	final_stats["speed"] = int((base.spd * 2.0) * stability_multiplier * spd_mult)
	
	return {"final_stats": final_stats, "breakdown": breakdown}

# Calculates the Binding Energy cost to fuse a new element
static func calculate_fusion_cost(target_z: int) -> int:
	# Cost scales exponentially/polynomially with Atomic Number.
	# Using quadratic scaling: 50 * Z^2. This ensures 1 Run ~= 1 Fusion.
	return int(50 * pow(target_z, 2))