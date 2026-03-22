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
	Group.ALKALI_METAL: {"hp": 2, "atk": 7, "def": 2, "spd": 8, "crit": 10}, # Glass Cannons
	Group.ALKALINE_EARTH: {"hp": 6, "atk": 4, "def": 7, "spd": 3, "crit": 5}, # Sturdy Tanks
	Group.TRANSITION_METAL: {"hp": 6, "atk": 5, "def": 5, "spd": 4, "crit": 5}, # Bruisers
	Group.POST_TRANSITION: {"hp": 5, "atk": 5, "def": 5, "spd": 5, "crit": 5}, # Utility
	Group.METALLOID: {"hp": 4, "atk": 6, "def": 4, "spd": 6, "crit": 5}, # Disrupters
	Group.NONMETAL: {"hp": 4, "atk": 4, "def": 4, "spd": 7, "crit": 5}, # Combo Primers
	Group.HALOGEN: {"hp": 3, "atk": 5, "def": 3, "spd": 8, "crit": 10}, # DoT Assailants
	Group.NOBLE_GAS: {"hp": 5, "atk": 1, "def": 10, "spd": 4, "crit": 0}, # Pure Walls
	Group.ACTINIDE: {"hp": 8, "atk": 10, "def": 5, "spd": 2, "crit": 5}, # The Nukes
	Group.LANTHANIDE: {"hp": 7, "atk": 9, "def": 5, "spd": 3, "crit": 5}, # Rare Earths (Similar to Actinides)
	Group.UNKNOWN: {"hp": 5, "atk": 5, "def": 5, "spd": 5, "crit": 5},
	
	# Enemy Baselines (Grunt=Low, King=Boss)
	# Void: Balanced
	Group.VOID_GRUNT: {"hp": 4, "atk": 4, "def": 4, "spd": 4, "crit": 5},
	Group.VOID_ASSASSIN: {"hp": 3, "atk": 7, "def": 2, "spd": 8, "crit": 15},
	Group.VOID_BRUTE: {"hp": 8, "atk": 5, "def": 8, "spd": 2, "crit": 0},
	Group.VOID_COMMANDER: {"hp": 7, "atk": 7, "def": 6, "spd": 6, "crit": 5},
	Group.VOID_KING: {"hp": 10, "atk": 9, "def": 9, "spd": 5, "crit": 5},
	
	# Eldritch: High Special/Status (Simulated via Atk/Spd)
	Group.ELDRITCH_GRUNT: {"hp": 3, "atk": 5, "def": 3, "spd": 5, "crit": 5},
	Group.ELDRITCH_ASSASSIN: {"hp": 4, "atk": 8, "def": 3, "spd": 7, "crit": 10},
	Group.ELDRITCH_BRUTE: {"hp": 9, "atk": 4, "def": 6, "spd": 3, "crit": 5},
	Group.ELDRITCH_COMMANDER: {"hp": 6, "atk": 9, "def": 5, "spd": 6, "crit": 5},
	Group.ELDRITCH_KING: {"hp": 10, "atk": 10, "def": 8, "spd": 4, "crit": 5},
	
	# Chaos: High Variance/Speed
	Group.CHAOS_GRUNT: {"hp": 2, "atk": 6, "def": 2, "spd": 7, "crit": 10},
 	Group.CHAOS_ASSASSIN: {"hp": 3, "atk": 8, "def": 1, "spd": 9, "crit": 20},
	Group.CHAOS_BRUTE: {"hp": 8, "atk": 6, "def": 5, "spd": 4, "crit": 5},
	Group.CHAOS_COMMANDER: {"hp": 6, "atk": 8, "def": 4, "spd": 8, "crit": 10},
	Group.CHAOS_KING: {"hp": 9, "atk": 10, "def": 5, "spd": 10, "crit": 15},
	
	# Fission: High Damage/Low Health
	Group.FISSION_GRUNT: {"hp": 3, "atk": 7, "def": 2, "spd": 5, "crit": 5},
	Group.FISSION_ASSASSIN: {"hp": 4, "atk": 8, "def": 2, "spd": 7, "crit": 10},
	Group.FISSION_BRUTE: {"hp": 7, "atk": 6, "def": 8, "spd": 3, "crit": 5},
	Group.FISSION_COMMANDER: {"hp": 6, "atk": 9, "def": 4, "spd": 6, "crit": 5},
	Group.FISSION_KING: {"hp": 9, "atk": 10, "def": 6, "spd": 5, "crit": 10},
	
	# Brood: Swarm/Regen (High HP, Low Def)
	Group.BROOD_GRUNT: {"hp": 5, "atk": 4, "def": 2, "spd": 6, "crit": 5},
	Group.BROOD_ASSASSIN: {"hp": 4, "atk": 7, "def": 2, "spd": 8, "crit": 10},
	Group.BROOD_BRUTE: {"hp": 10, "atk": 5, "def": 4, "spd": 3, "crit": 0},
	Group.BROOD_COMMANDER: {"hp": 8, "atk": 6, "def": 5, "spd": 6, "crit": 5},
	Group.BROOD_KING: {"hp": 12, "atk": 8, "def": 6, "spd": 5, "crit": 10}
}

# Mastery Bonus Descriptions (100% Stability)
const MASTERY_BONUSES = {
	Group.ALKALI_METAL: "Mastery: Critical strikes deal 1.75x damage instead of 1.5x.",
	Group.ALKALINE_EARTH: "Mastery: Begin combat with a shield equal to 25% of Max HP.",
	Group.TRANSITION_METAL: "Mastery: Catalysis causes debuffs to tick an additional time.",
	Group.POST_TRANSITION: "Mastery: Healing an ally also deals that much damage to a random enemy.",
	Group.METALLOID: "Mastery: Increases the chance to stun on-hit to 25%.",
	Group.NONMETAL: "Mastery: Gain a free turn at the start of combat.",
	Group.HALOGEN: "Mastery: At the start of combat, poisons a random enemy.",
	Group.NOBLE_GAS: "Mastery: Restores 5% Max HP at the start of every turn.",
	Group.ACTINIDE: "Mastery: Reduces passive HP decay from 10% to 5%.",
	Group.LANTHANIDE: "Mastery: Can now absorb stats from fallen allies as well as enemies."
}

# Default Movesets based on Group
const GROUP_MOVES = {
	Group.ALKALI_METAL: [
		{"name": "Valence Jettison", "power": 40, "accuracy": 90, "type": "Physical", "description": "A reckless high-speed dash that transfers mass electron density. Applies 4 Reduced [R] stacks but reduces the user's Defense by 100% for 2 turns.", "cooldown": 3, "effects": [{"type": "stat_mod", "stat": "defense", "amount": -100, "percent": true, "duration": 2, "target": "Attacker"}, {"effect": "add_status_stacks", "status": "reduced", "amount": 3, "duration": 3, "target": "Defender"}]},
		{"name": "Ionic Surge", "power": 15, "accuracy": 100, "type": "Physical", "description": "A rhythmic strike that excites the user's atomic shell. Applies 1 Reduced [R] stack and increases the user's Speed and Attack by 10% (Stacks up to 50%).", "cooldown": 2, "effects": [{"type": "stat_mod", "stat": "attack", "amount": 10, "percent": true, "duration": 99, "target": "Attacker"}, {"type": "stat_mod", "stat": "speed", "amount": 10, "percent": true, "duration": 99, "target": "Attacker"}]}
	],
	Group.ALKALINE_EARTH: [
		{"name": "Anodic Barrier", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Self", "description": "Develops a protective oxide skin. Increases Defense by 50% for 3 turns. While active, any enemy that hits the user is applied with 1 Reduced [R] stack.", "cooldown": 3, "effects": [{"type": "stat_mod", "stat": "defense", "amount": 50, "percent": true, "duration": 3, "target": "Self"}, {"type": "status", "status": "anodic_barrier", "duration": 3}]},
		{"name": "Photonic Bash", "power": 30, "accuracy": 95, "type": "Physical", "description": "A blinding shield strike. Applies 1 Reduced [R] stack. If the user has Anodic Barrier active, the target is Stunned for 1 turn.", "cooldown": 2}
	],
	Group.TRANSITION_METAL: [
		{"name": "Catalytic Bond", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Ally", "description": "Lowers the activation energy of the squad. Reduces the target ally's cooldowns by 1 and increases their Action Gauge by 20%.", "cooldown": 3, "effects": [{"effect": "reduce_cooldowns", "amount": 1}, {"effect": "add_atb", "amount": 20.0}]},
		{"name": "Resonance Strike", "power": 35, "accuracy": 90, "type": "Physical", "description": "A dense strike that vibrates the target's atomic structure. Applies 1 Reduced [R] stack and refreshes the duration of all existing [R] stacks on the enemy.", "cooldown": 2}
	],
	Group.POST_TRANSITION: [
		{"name": "Thermal Conduction", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Ally", "description": "Cleanses 1 debuff from target ally.", "cooldown": 3, "effects": [{"effect": "cleanse", "target": "Ally", "amount": 1}]},
		{"name": "Alloy Reinforce", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Ally", "description": "Heals target ally, scales with attack. Excess healing becomes a shield.", "cooldown": 2}
	],
	Group.METALLOID: [
		{"name": "Thermal Transistor", "power": 0, "accuracy": 100, "type": "Status_Hostile", "description": "Reduces enemy Attack and Defense by 20%.", "cooldown": 2, "effects": [{"type": "stat_mod", "stat": "attack", "amount": -20, "percent": true, "duration": 2}, {"type": "stat_mod", "stat": "defense", "amount": -20, "percent": true, "duration": 2}]},
		{"name": "Signal Scramble", "power": 20, "accuracy": 100, "type": "Special", "is_snipe": true, "description": "Slows enemy by 20% for 2 turns.", "cooldown": 2, "effects": [{"type": "stat_mod", "stat": "speed", "amount": -20, "percent": true, "duration": 2}]}
	],
	Group.NONMETAL: [
		{
			"name": "Chain Reaction",
			"power": 15,
			"accuracy": 100,
			"type": "Special",
			"description": "A weak attack that marks the enemy. The next attack against them will trigger a chain reaction.",
			"effects": [ {
				"type": "status", "status": "chain_reaction_mark", "duration": 3, "message": "%s is primed for a chain reaction!"
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
		{"name": "Inert Strike", "power": 20, "accuracy": 100, "type": "Physical", "description": "A weak attack that raises the user's Defense by 15%.", "effects": [{"type": "stat_mod", "stat": "defense", "amount": 15, "percent": true, "duration": 2, "target": "Attacker"}]}
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
	Group.VOID_GRUNT: [
		{"name": "Void Scratch", "power": 20, "accuracy": 100, "type": "Physical", "description": "Basic void attack."},
		{"name": "Void Fortify", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Self", "description": "Increases Defense.", "cooldown": 3, "effects": [{"type": "stat_mod", "stat": "defense", "amount": 25, "percent": true, "duration": 3}]}
	],
	Group.VOID_ASSASSIN: [
		{"name": "Quick Slash", "power": 25, "accuracy": 100, "type": "Physical", "description": "Fast physical strike."},
		{"name": "Shadow Strike", "power": 45, "accuracy": 100, "type": "Physical", "is_snipe": true, "description": "Snipe attack that bypasses the frontline.", "cooldown": 3}
	],
	Group.VOID_BRUTE: [
		{"name": "Heavy Slam", "power": 50, "accuracy": 90, "type": "Physical", "description": "A heavy physical attack."},
		{"name": "Void Harden", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Self", "description": "Increases Defense heavily.", "cooldown": 4, "effects": [{"type": "stat_mod", "stat": "defense", "amount": 40, "percent": true, "duration": 3}]}
	],
	Group.VOID_COMMANDER: [
		{"name": "Void Strike", "power": 40, "accuracy": 100, "type": "Physical", "description": "Strong void attack."},
		{"name": "Void Command", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Ally", "description": "Buffs an ally's Attack and Speed.", "cooldown": 4, "effects": [{"type": "stat_mod", "stat": "attack", "amount": 20, "percent": true, "duration": 3}, {"type": "stat_mod", "stat": "speed", "amount": 20, "percent": true, "duration": 3}]},
		{"name": "Obliterate", "power": 80, "accuracy": 85, "type": "Special", "description": "Devastating special attack.", "cooldown": 3}
	],
	Group.VOID_KING: [
		{"name": "Royal Strike", "power": 50, "accuracy": 100, "type": "Physical", "description": "A commanding physical blow."},
		{"name": "Entropy", "power": 100, "accuracy": 100, "type": "Special", "description": "Deals massive damage to a single target.", "cooldown": 4}
	],
	
	# Eldritch
	Group.ELDRITCH_GRUNT: [
		{"name": "Mind Poke", "power": 20, "accuracy": 100, "type": "Special", "description": "Basic psychic attack."},
		{"name": "Weird Chant", "power": 0, "accuracy": 100, "type": "Status_Hostile", "description": "Slows the target.", "cooldown": 3, "effects": [{"type": "stat_mod", "stat": "speed", "amount": -20, "percent": true, "duration": 2}]}
	],
	Group.ELDRITCH_ASSASSIN: [
		{"name": "Tentacle Slap", "power": 25, "accuracy": 100, "type": "Physical", "description": "A quick physical slap."},
		{"name": "Psychic Knife", "power": 45, "accuracy": 100, "type": "Special", "is_snipe": true, "description": "Snipe attack that bypasses the frontline.", "cooldown": 3}
	],
	Group.ELDRITCH_BRUTE: [
		{"name": "Tentacle Crush", "power": 55, "accuracy": 90, "type": "Physical", "description": "Strong physical attack."},
		{"name": "Eldritch Guard", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Self", "description": "Grants a protective shield.", "cooldown": 4, "effects": [{"effect": "add_shield", "scale_stat": "max_hp", "scale_factor": 0.25}]}
	],
	Group.ELDRITCH_COMMANDER: [
		{"name": "Eldritch Blast", "power": 40, "accuracy": 100, "type": "Special", "description": "Standard energy blast."},
		{"name": "Madness Aura", "power": 0, "accuracy": 100, "type": "Status_Hostile", "description": "Applies a random debuff to all enemies.", "cooldown": 4, "effects": [{"effect": "madness_aura"}]}
	],
	Group.ELDRITCH_KING: [
		{"name": "Mind Flay", "power": 50, "accuracy": 100, "type": "Special", "description": "A powerful psychic assault."},
		{"name": "Cosmic Horror", "power": 120, "accuracy": 80, "type": "Special", "description": "Deals massive damage and reduces sanity.", "cooldown": 4}
	],
	
	# Chaos
	Group.CHAOS_GRUNT: [
		{"name": "Glitch Hit", "power": 30, "accuracy": 80, "type": "Physical", "description": "Unstable physical attack."},
		{"name": "Stat Scramble", "power": 0, "accuracy": 100, "type": "Status_Hostile", "description": "Swaps the target's Attack and Defense.", "cooldown": 3, "effects": [{"effect": "swap_stats", "stats": ["attack", "defense"], "duration": 2}]}
	],
	Group.CHAOS_ASSASSIN: [
		{"name": "Pixel Stab", "power": 50, "accuracy": 90, "type": "Physical", "description": "Strong physical attack."},
		{"name": "Blink Strike", "power": 40, "accuracy": 100, "type": "Physical", "is_snipe": true, "description": "Teleports behind the vanguard.", "cooldown": 3}
	],
	Group.CHAOS_BRUTE: [
		{"name": "Glitch Smash", "power": 45, "accuracy": 90, "type": "Physical", "description": "A heavy, glitchy smash."},
		{"name": "Static Shield", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Self", "description": "Grants a shield and reflects damage.", "cooldown": 4, "effects": [{"effect": "add_shield", "scale_stat": "max_hp", "scale_factor": 0.3}, {"type": "status", "status": "static_reflection", "damage_percent": 0.3, "duration": 3, "message": "%s charges up a static field!"}]}
	],
	Group.CHAOS_COMMANDER: [
		{"name": "Data Corruption", "power": 40, "accuracy": 100, "type": "Special", "description": "Corrupts the target."},
		{"name": "Scramble", "power": 40, "accuracy": 100, "type": "Special", "description": "Deals damage and shuffles the target team's positions.", "cooldown": 4, "effects": [{"effect": "scramble_team"}]}
	],
	Group.CHAOS_KING: [
		{"name": "Chaos Beam", "power": 50, "accuracy": 100, "type": "Special", "description": "A wild energy beam."},
		{"name": "Reality Break", "power": 99, "accuracy": 50, "type": "Special", "description": "Deals massive damage with low accuracy.", "cooldown": 2}
	],
	
	# Fission
	Group.FISSION_GRUNT: [
		{"name": "Rad Bite", "power": 25, "accuracy": 95, "type": "Physical", "description": "Radioactive bite."},
		{"name": "Toxic Spit", "power": 0, "accuracy": 90, "type": "Status_Hostile", "description": "Poisons the target.", "cooldown": 3, "effects": [{"type": "status", "status": "poison", "damage_percent": 0.1, "duration": 3}]}
	],
	Group.FISSION_ASSASSIN: [
		{"name": "Fast Decay", "power": 30, "accuracy": 100, "type": "Special", "description": "Quick burst of radiation."},
		{"name": "Gamma Ray", "power": 45, "accuracy": 100, "type": "Special", "is_snipe": true, "description": "High-accuracy snipe attack.", "cooldown": 3}
	],
	Group.FISSION_BRUTE: [
		{"name": "Heavy Fission", "power": 45, "accuracy": 95, "type": "Physical", "description": "A heavy, glowing slam."},
		{"name": "Lead Wall", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Self", "description": "Grants a massive shield to self.", "cooldown": 4, "effects": [{"effect": "add_shield", "scale_stat": "max_hp", "scale_factor": 0.4}]}
	],
	Group.FISSION_COMMANDER: [
		{"name": "Isotope Toss", "power": 40, "accuracy": 100, "type": "Physical", "description": "Throws a volatile isotope."},
		{"name": "Chain Reaction", "power": 60, "accuracy": 90, "type": "Special", "description": "Deals damage and triggers a chain reaction.", "cooldown": 4, "effects": [{"effect": "chain_reaction", "amount": 60}]}
	],
	Group.FISSION_KING: [
		{"name": "Nuclear Pulse", "power": 50, "accuracy": 100, "type": "Special", "description": "A constant wave of heat and radiation."},
		{"name": "Meltdown", "power": 150, "accuracy": 100, "type": "Special", "description": "Catastrophic damage to the entire battlefield.", "cooldown": 5, "effects": [{"effect": "meltdown", "amount": 80}]}
	],
	
	# Brood
	Group.BROOD_GRUNT: [
		{"name": "Mandible Bite", "power": 25, "accuracy": 95, "type": "Physical", "description": "Physical bite attack."},
		{"name": "Swarm Call", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Self", "description": "Increases Attack.", "cooldown": 3, "effects": [{"type": "stat_mod", "stat": "attack", "amount": 25, "percent": true, "duration": 3}]}
	],
	Group.BROOD_ASSASSIN: [
		{"name": "Sting", "power": 30, "accuracy": 100, "type": "Physical", "description": "A sharp, venomous sting."},
		{"name": "Neurotoxin", "power": 35, "accuracy": 100, "type": "Special", "is_snipe": true, "description": "Snipe attack that poisons the target.", "cooldown": 3, "effects": [{"type": "status", "status": "poison", "damage_percent": 0.1, "duration": 3}]}
	],
	Group.BROOD_BRUTE: [
		{"name": "Slam", "power": 45, "accuracy": 95, "type": "Physical", "description": "Throws its heavy body into the enemy."},
		{"name": "Chitin Shell", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Self", "description": "Grants a shield and increases Defense.", "cooldown": 4, "effects": [{"effect": "add_shield", "scale_stat": "max_hp", "scale_factor": 0.25}, {"type": "stat_mod", "stat": "defense", "amount": 20, "percent": true, "duration": 3}]}
	],
	Group.BROOD_COMMANDER: [
		{"name": "Acid Spray", "power": 40, "accuracy": 100, "type": "Special", "description": "Sprays corrosive acid."},
		{"name": "Pheromones", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Ally", "description": "Buffs Attack and Speed of all allies.", "cooldown": 4, "effects": [{"effect": "pheromones"}]}
	],
	Group.BROOD_KING: [
		{"name": "Royal Mandible", "power": 50, "accuracy": 100, "type": "Physical", "description": "A vicious bite from the sovereign."},
		{"name": "Hive Mind", "power": 90, "accuracy": 100, "type": "Special", "description": "Deals damage and calls for reinforcements.", "cooldown": 5, "effects": [{"effect": "call_reinforcements"}]}
	]
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
		"description": "Increases Defense and reflects 10% of incoming damage.",
		"target_type": "Self",
		"effects": [ 
			{"type": "stat_mod", "stat": "defense", "amount": 20, "percent": true, "duration": 3},
			{"type": "status", "status": "static_reflection", "damage_percent": 0.1, "duration": 3}
		],
		"cooldown": 3
	},
	5: { # Boron
		"name": "Boron Blast",
		"power": 30,
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
		"description": "Deals damage and applies corrosion (5% Max HP damage and -10% Defense).",
		"target_type": "Enemy",
		"effects": [ 
			{"type": "status", "status": "corrosion", "damage_percent": 0.05, "duration": 3, "message": "%s is corroding!"},
			{"type": "stat_mod", "stat": "defense", "amount": -10, "percent": true, "duration": 3}
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
		"name": "Bleach Cloud",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Hostile",
		"description": "Creates a hazardous cloud. Enemies take damage when attacking.",
		"target_type": "Enemy",
		"effects": [ {"effect": "team_status", "status": "reactive_vapor", "duration": 3, "message": "The air turns toxic!"}],
		"cooldown": 3
	},
	18: { # Argon
		"name": "Inert Gas Barrier",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Grants a shield to all allies.",
		"target_type": "Self",
		"effects": [ {"effect": "add_team_shield", "scale_stat": "max_hp", "scale_factor": 0.2}],
		"cooldown": 3
	},
	19: { # Potassium
		"name": "Violet Flare",
		"power": 15,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals extra damage for every debuff on the enemy.",
		"target_type": "Enemy",
		"effects": [],
		"cooldown": 2
	},
	20: { # Calcium
		"name": "Calcium Carapace",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Grants a shield equal to 35% of Max HP.",
		"target_type": "Self",
		"effects": [ {"effect": "add_shield", "scale_stat": "max_hp", "scale_factor": 0.35}],
		"cooldown": 2
	},
	21: { # Scandium
		"name": "Light-Alloy Strike",
		"power": 30,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and raises Defense by 10%.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "defense", "amount": 10, "percent": true, "duration": 1, "target": "Attacker"}],
		"cooldown": 2
	},
	22: { # Titanium
		"name": "Hardened Bash",
		"power": 30,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and raises Defense by 10%.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "defense", "amount": 10, "percent": true, "duration": 1, "target": "Attacker"}]
	},
	23: { # Vanadium
		"name": "Refined Edge",
		"power": 30,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and raises Attack by 10%.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "attack", "amount": 10, "percent": true, "duration": 1, "target": "Attacker"}]
	},
	24: { # Chromium
		"name": "Mirror Finish",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Reflects the next incoming attack.",
		"target_type": "Self",
		"effects": [ {"type": "status", "status": "mirror_coat", "duration": 3}],
		"cooldown": 3
	},
	25: { # Manganese
		"name": "Ferro-Impact",
		"power": 30,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and raises Attack by 10%.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "attack", "amount": 10, "percent": true, "duration": 1, "target": "Attacker"}]
	},
	26: { # Iron
		"name": "Magnetic Slam",
		"power": 30,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and grants a shield (25% of damage dealt).",
		"target_type": "Enemy",
		"effects": [ {"effect": "add_shield", "scale_stat": "damage_dealt", "scale_factor": 0.25, "target": "Attacker"}]
	},
	27: { # Cobalt
		"name": "Blue-Steel Guard",
		"power": 30,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and grants a shield (25% of damage dealt).",
		"target_type": "Enemy",
		"effects": [ {"effect": "add_shield", "scale_stat": "damage_dealt", "scale_factor": 0.25, "target": "Attacker"}]
	},
	28: { # Nickel
		"name": "Plated Guard",
		"power": 30,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and lowers enemy Defense by 10%.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "defense", "amount": -10, "percent": true, "duration": 1}]
	},
	29: { # Copper
		"name": "Conductive Whip",
		"power": 30,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and raises Speed by 10%.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "speed", "amount": 10, "percent": true, "duration": 1, "target": "Attacker"}]
	},
	30: { # Zinc
		"name": "Galvanized Shield",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Reflects the next incoming attack.",
		"target_type": "Self",
		"effects": [ {"type": "status", "status": "mirror_coat", "duration": 3}],
		"cooldown": 3
	},
	31: { # Gallium
		"name": "Liquid Metal Shift",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Swaps position with an ally and increases their Speed.",
		"target_type": "Ally",
		"effects": [
			{"effect": "swap_position"},
			{"type": "stat_mod", "stat": "speed", "amount": 20, "percent": true, "duration": 2}
		],
		"cooldown": 2
	},
	32: { # Germanium
		"name": "Semiconductor Flip",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Hostile",
		"description": "Swaps the target's Attack and Defense for 2 turns.",
		"target_type": "Enemy",
		"effects": [ {"effect": "swap_stats", "stats": ["attack", "defense"], "duration": 2}],
		"cooldown": 2
	},
	33: { # Arsenic
		"name": "Toxic Feedback",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "For 3 turns, any enemy that attacks this unit has their Attack reduced by 40%.",
		"target_type": "Self",
		"effects": [ {"type": "status", "status": "toxic_feedback", "duration": 3, "debuff_stat": "attack", "debuff_amount": -40, "debuff_percent": true, "debuff_duration": 2}],
		"cooldown": 3
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
		"name": "Sedative Vapor",
		"power": 30,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals damage. 30% chance to Stun if target is Poisoned.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "stun", "duration": 1, "chance": 0.3, "condition_status": "poison"}],
		"cooldown": 2
	},
	36: { # Krypton
		"name": "Laser Refraction",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Grants a 25% HP shield and reflects 40% damage for 1 turn.",
		"target_type": "Self",
		"effects": [
			{"effect": "add_shield", "scale_stat": "max_hp", "scale_factor": 0.25},
			{"type": "status", "status": "static_reflection", "damage_percent": 0.4, "duration": 1}
		],
		"cooldown": 3
	},
	37: { # Rubidium
		"name": "Red-Shift Dash",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals 40 damage with high armor penetration.",
		"target_type": "Enemy",
		"effects": [],
		"cooldown": 2
	},
	38: { # Strontium
		"name": "Crimson Lockdown",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and reduces Speed of all enemies.",
		"target_type": "Enemy",
		"effects": [
			{"effect": "aoe_stat_mod", "stat": "speed", "amount": -20, "percent": true, "duration": 2, "message": "The enemy team is slowed!"}
		],
		"cooldown": 3
	},
	39: { # Yttrium
		"name": "Luminescent Arc",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and increases Crit Chance by 15%.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "crit_chance", "amount": 15, "duration": 2, "target": "Attacker"}],
		"cooldown": 2
	},
	40: { # Zirconium
		"name": "Gemstone Guard",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and raises Defense by 15% for 1 turn.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "defense", "amount": 15, "percent": true, "duration": 1, "target": "Attacker"}],
		"cooldown": 2
	},
	41: { # Niobium
		"name": "Super-Conduct",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and raises Speed by 15% for 1 turn.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "speed", "amount": 15, "percent": true, "duration": 1, "target": "Attacker"}],
		"cooldown": 2
	},
	42: { # Molybdenum
		"name": "Heat-Sink Bash",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and lowers enemy Defense by 15%.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "defense", "amount": -15, "percent": true, "duration": 2}],
		"cooldown": 2
	},
	43: { # Technetium
		"name": "Isotope Pulse",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and increases Crit Chance by 15%.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "crit_chance", "amount": 15, "duration": 2, "target": "Attacker"}],
		"cooldown": 2
	},
	44: { # Ruthenium
		"name": "Catalytic Blast",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and lowers enemy Defense by 15%.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "defense", "amount": -15, "percent": true, "duration": 2}],
		"cooldown": 2
	},
	45: { # Rhodium
		"name": "Reflective Shell",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Negates next hit and reflects 30% damage.",
		"target_type": "Self",
		"effects": [ {"type": "status", "status": "reflective_shell", "duration": 3}],
		"cooldown": 3
	},
	46: { # Palladium
		"name": "H-Absorb Shield",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Absorbs next hit, healing for 30% of damage.",
		"target_type": "Self",
		"effects": [ {"type": "status", "status": "absorb_shield", "duration": 3}],
		"cooldown": 3
	},
	47: { # Silver
		"name": "Sterling Flash",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and raises Speed by 15% for 1 turn.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "speed", "amount": 15, "percent": true, "duration": 1, "target": "Attacker"}],
		"cooldown": 2
	},
	48: { # Cadmium Transition Metal
		"name": "Neutron Dampener",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and reduces enemy Attack by 15%.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "attack", "amount": -15, "percent": true, "duration": 2}],
		"cooldown": 2
	},
	49: { # Indium Post-Transition Metal
		"name": "Soft-Metal Pulse",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Increases Speed of all allies by 10% for 1 turn.",
		"target_type": "Self",
		"effects": [
			{"effect": "aoe_stat_mod", "stat": "speed", "amount": 10, "percent": true, "duration": 1, "target_team": "ally", "message": "Allies accelerate!"}
		],
		"cooldown": 2
	},
	50: { # Tin Post-Transition Metal
		"name": "Casing Reinforce",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Grants a 30% HP shield that deals damage when broken.",
		"target_type": "Self",
		"effects": [ {"effect": "add_shield", "scale_stat": "max_hp", "scale_factor": 0.3, "explode_on_break": true}],
		"cooldown": 3
	},
	51: { # Antimony Metalloid
		"name": "Inhibitor Wave",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Hostile",
		"description": "Reduces Attack of all enemies by 20%.",
		"target_type": "Enemy",
		"effects": [ {"effect": "aoe_stat_mod", "stat": "attack", "amount": -20, "percent": true, "duration": 2, "message": "Enemy Attack weakened!"}],
		"cooldown": 2
	},
	52: { # Tellurium Metalloid
		"name": "Solar Flare",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals damage and blinds the enemy.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "refracted", "duration": 2}],
		"cooldown": 2
	},
	53: { # Iodine Halogen
		"name": "Antiseptic Burn",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Heals an ally for 10% Max HP every turn for 3 turns.",
		"target_type": "Ally",
		"effects": [ {"type": "status", "status": "regeneration", "heal_percent": 0.1, "duration": 3}],
		"cooldown": 3
	},
	54: { # Xenon Noble Gas
		"name": "Stasis Flash",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Absorbs the next hit, converting 60% of damage to Health.",
		"target_type": "Self",
		"effects": [ {"type": "status", "status": "absorb_shield", "duration": 3, "absorb_percent": 0.6}],
		"cooldown": 3
	},
	55: { # Cesium Alkali Metal
		"name": "Atomic Clock",
		"power": 50,
		"accuracy": 90,
		"type": "Physical",
		"description": "A quick attack that increases the users's speed",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "speed", "amount": 15, "percent": true, "duration": 1, "target": "Attacker"}],
		"cooldown": 3
	},
	56: { # Barium Alkaline Earth Metal
		"name": "Barium Bulwark",
		"power": 50,
		"accuracy": 100,
		"type": "Physical",
		"description": "Bashes enemy and grants the user a 25% HP shield.",
		"target_type": "Enemy",
		"effects": [ {"effect": "add_shield", "scale_stat": "max_hp", "scale_factor": 0.25, "target": "Attacker"}],
		"cooldown": 3
	},
	57: { # Lanthanum Lanthanide
		"name": "Lanth-Lens",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Next attack on target cannot miss.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "illuminated", "duration": 2}],
		"cooldown": 3
	},
	58: { # Cerium
		"name": "Cerous Spark",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "+5% team Crit chance permanent.",
		"target_type": "Enemy",
		"effects": [ {"effect": "aoe_stat_mod", "stat": "crit_chance", "amount": 5, "duration": 99, "target_team": "ally", "message": "Team Crit Chance increased!"}],
		"cooldown": 3
	},
	59: { # Praseodymium
		"name": "Didymium Flash",
		"power": 0,
		"accuracy": 100,
		"type": "Physical",
		"description": "40 power AoE damage.",
		"target_type": "Enemy", # Targets one to cast, hits all via effect
		"effects": [ {"effect": "aoe_power_attack", "power": 40}],
		"cooldown": 3
	},
	60: { # Neodymium
		"name": "Magnetic Pull",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "A precise snipe attack.",
		"is_snipe": true,
		"target_type": "Enemy",
		"effects": [],
		"cooldown": 3
	},
	61: { # Promethium
		"name": "Lume-Decay",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Lowers target Evasion.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "illuminated", "duration": 2, "message": "%s is illuminated!"}],
		"cooldown": 3
	},
	62: { # Samarium
		"name": "Samar-Shield",
		"power": 50,
		"accuracy": 100,
		"type": "Physical",
		"description": "Increases team defense by 10%.",
		"target_type": "Enemy",
		"effects": [ {"effect": "aoe_stat_mod", "stat": "defense", "amount": 10, "percent": true, "duration": 3, "target_team": "ally"}],
		"cooldown": 3
	},
	63: { # Europium
		"name": "Fluorescent Ray",
		"power": 50,
		"accuracy": 100,
		"type": "Special",
		"description": "+30% damage vs debuffed targets.",
		"target_type": "Enemy",
		"effects": [],
		"bonus_damage_condition": "debuffed",
		"damage_multiplier": 1.3,
		"cooldown": 3
	},
	64: { # Gadolinium
		"name": "Neutron Sponge",
		"power": 50,
		"accuracy": 100,
		"type": "Physical",
		"description": "Absorbs 20% of next hit.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "absorb_shield", "duration": 2, "absorb_percent": 0.2, "target": "Attacker"}],
		"cooldown": 3
	},
	65: { # Terbium
		"name": "Green-Shift",
		"power": 50,
		"accuracy": 100,
		"type": "Special",
		"description": "+15% team Speed.",
		"target_type": "Enemy",
		"effects": [ {"effect": "aoe_stat_mod", "stat": "speed", "amount": 15, "percent": true, "duration": 3, "target_team": "ally"}],
		"cooldown": 3
	},
	66: { # Dysprosium
		"name": "Hard-Magnet Slam",
		"power": 50,
		"accuracy": 100,
		"type": "Physical",
		"description": "40% Stun chance.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "stun", "duration": 1, "chance": 0.4}],
		"cooldown": 3
	},
	67: { # Holmium
		"name": "Holm-Flux",
		"power": 60,
		"accuracy": 100,
		"type": "Physical",
		"description": "Steals 10% target DEF.",
		"target_type": "Enemy",
		"effects": [ 
			{"type": "stat_mod", "stat": "defense", "amount": -10, "percent": true, "duration": 3},
			{"type": "stat_mod", "stat": "defense", "amount": 10, "percent": true, "duration": 3, "target": "Attacker"}
		],
		"cooldown": 3
	},
	68: { # Erbium
		"name": "Amplifier Beam",
		"power": 60,
		"accuracy": 100,
		"type": "Special",
		"description": "Extends debuffs on target by 1 turn.",
		"target_type": "Enemy",
		"effects": [ {"effect": "extend_debuffs", "amount": 1}],
		"cooldown": 3
	},
	69: { # Thulium
		"name": "Thul-Thumper",
		"power": 65,
		"accuracy": 100,
		"type": "Physical",
		"description": "Ignores 20% Defense.",
		"target_type": "Enemy",
		"effects": [],
		"ignore_def_percent": 20.0,
		"cooldown": 3
	},
	70: { # Ytterbium
		"name": "Resonance Wave",
		"power": 30,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals 50% splash damage to other enemies.",
		"target_type": "Enemy",
		"effects": [ {"effect": "splash_damage", "percent": 0.5}],
		"cooldown": 3
	},
	71: { # Lutetium
		"name": "Apex Rare-Earth",
		"power": 70,
		"accuracy": 100,
		"type": "Physical",
		"description": "A powerful finishing strike.",
		"target_type": "Enemy",
		"effects": [],
		"cooldown": 3
	},
	72: { # Hafnium
		"name": "Control-Rod Bash",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals 40 damage and reduces target ATK by 20%.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "attack", "amount": -20, "percent": true, "duration": 2}],
		"cooldown": 3
	},
	73: { # Tantalum
		"name": "Capacitor Discharge",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals 40 damage and increases user SPD by 20% for 1 turn.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "speed", "amount": 20, "percent": true, "duration": 1, "target": "Attacker"}],
		"cooldown": 3
	},
	74: { # Tungsten
		"name": "Heavy-Density Slam",
		"power": 30,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals 30 damage and stuns the target for 1 turn.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "stun", "duration": 1}],
		"cooldown": 3
	},
	75: { # Rhenium
		"name": "Alloy Reinforce",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals 40 damage and increases user DEF by 20% for 1 turn.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "defense", "amount": 20, "percent": true, "duration": 1, "target": "Attacker"}],
		"cooldown": 3
	},
	76: { # Osmium
		"name": "Osmium Pressure",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals 40 damage and reduces target SPD by 20%.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "speed", "amount": -20, "percent": true, "duration": 2}],
		"cooldown": 3
	},
	77: { # Iridium
		"name": "Iridescent Guard",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Reflects 60% of incoming damage for 2 turns.",
		"target_type": "Self",
		"effects": [ {"type": "status", "status": "static_reflection", "damage_percent": 0.6, "duration": 2}],
		"cooldown": 3
	},
	78: { # Platinum
		"name": "Noble Catalyst",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals 40 damage and increases user Crit Chance by 25%.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "crit_chance", "amount": 25, "duration": 2, "target": "Attacker"}],
		"cooldown": 3
	},
	79: { # Gold
		"name": "Aurum Radiance",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals 40 damage and heals team for 10% of damage dealt.",
		"target_type": "Enemy",
		"effects": [ {"effect": "team_heal", "scale_stat": "damage_dealt", "scale_factor": 0.1}],
		"cooldown": 3
	},
	80: { # Mercury
		"name": "Liquid Metal Coil",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals 40 damage and applies a potent poison to the target.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "poison", "damage_percent": 0.1, "duration": 3}],
		"cooldown": 3
	},
	81: { # Thallium
		"name": "Prism Strike",
		"power": 0,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals damage equal to 20% of the target's Max HP.",
		"target_type": "Enemy",
		"effects": [ {"effect": "percent_damage", "percent": 0.2}],
		"cooldown": 3
	},
	82: { # Lead
		"name": "Isotope Shielding",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Applies a permanent 10% defense buff to all allies.",
		"target_type": "Self",
		"effects": [ {"effect": "aoe_stat_mod", "stat": "defense", "amount": 10, "percent": true, "duration": 99, "target_team": "ally", "message": "Ally defenses increased!"}],
		"cooldown": 3
	},
	83: { # Bismuth
		"name": "Spiral Structure",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Swaps position with an ally, increasing their Attack and Defense by 10% for 3 turns.",
		"target_type": "Ally",
		"effects": [
			{"effect": "swap_position"},
			{"type": "stat_mod", "stat": "attack", "amount": 10, "percent": true, "duration": 3},
			{"type": "stat_mod", "stat": "defense", "amount": 10, "percent": true, "duration": 3}
		],
		"cooldown": 2
	},
	84: { # Polonium
		"name": "Alpha Decay Burst",
		"power": 0,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals 20 AoE damage and slows all enemies by 10%.",
		"target_type": "Enemy",
		"effects": [ 
			{"effect": "aoe_power_attack", "power": 20},
			{"effect": "aoe_stat_mod", "stat": "speed", "amount": -10, "percent": true, "duration": 2, "target_team": "enemy"}
		]
	},
	85: { # Astatine
		"name": "Isotope Decay",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals 40 damage and applies radiation.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "radiation", "damage_percent": 0.05, "duration": 3}]
	},
	86: { # Radon
		"name": "Radioactive Shell",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Grants self a 30% Max HP shield and applies radiation to attacking enemies for 3 turns.",
		"target_type": "Self",
		"effects": [
			{"effect": "add_shield", "scale_stat": "max_hp", "scale_factor": 0.3},
			{"type": "status", "status": "radiation_feedback", "duration": 3}
		],
		"cooldown": 3
	},
	87: { # Francium
		"name": "Unstable Overload",
		"power": 70,
		"accuracy": 85,
		"type": "Physical",
		"description": "An extremely powerful strike, deals 10% recoil damage to self.",
		"target_type": "Enemy",
		"effects": [ {"effect": "recoil", "scale_stat": "damage_dealt", "scale_factor": 0.1, "target": "Attacker"} ],
		"cooldown": 3
	},
	88: { # Radium
		"name": "Irradiated Bastion",
		"power": 0,
		"accuracy": 100,
		"type": "Special",
		"description": "Steals 10% of enemy Max HP and heals all allies for the same amount.",
		"target_type": "Enemy",
		"effects": [ {"effect": "steal_hp_team", "percent": 0.1} ],
		"cooldown": 3
	},
	89: { # Actinium
		"name": "Glow Strike",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals damage and applies radiation.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "radiation", "damage_percent": 0.05, "duration": 3}],
		"cooldown": 3
	},
	90: { # Thorium
		"name": "Breeder Pulse",
		"power": 20,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals damage and permanently increases user's Attack by 5%.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "attack", "amount": 5, "percent": true, "duration": 99, "target": "Attacker"}],
		"cooldown": 2
	},
	91: { # Protactinium
		"name": "Fission Spike",
		"power": 50,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals high damage, ignoring 50% of the enemy's defense.",
		"target_type": "Enemy",
		"effects": [],
		"ignore_def_percent": 50.0,
		"cooldown": 3
	},
	92: { # Uranium
		"name": "Enriched Blast",
		"power": 30,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals damage and 50% splash damage to all other enemies.",
		"target_type": "Enemy",
		"effects": [ {"effect": "splash_damage", "percent": 0.5}],
		"cooldown": 3
	},
	93: { # Neptunium
		"name": "Transuranic Hit",
		"power": 20,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals damage, applying poison and radiation.",
		"target_type": "Enemy",
		"effects": [
			{"type": "status", "status": "poison", "damage_percent": 0.1, "duration": 3},
			{"type": "status", "status": "radiation", "damage_percent": 0.05, "duration": 3}
		],
		"cooldown": 3
	},
	94: { # Plutonium
		"name": "Critical Mass",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals moderate damage with a heavily increased chance to critical strike.",
		"target_type": "Enemy",
		"effects": [],
		"crit_bonus": 50.0,
		"cooldown": 3
	},
	95: { # Americium
		"name": "Ionization Beam",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals moderate damage and removes all buffs from the enemy.",
		"target_type": "Enemy",
		"effects": [ {"effect": "cleanse_buffs", "target": "Enemy"}],
		"cooldown": 3
	},
	96: { # Curium
		"name": "Curie-Blast",
		"power": 50,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals high damage. Takes 10% recoil damage.",
		"target_type": "Enemy",
		"effects": [ {"effect": "recoil", "scale_stat": "damage_dealt", "scale_factor": 0.1, "target": "Attacker"}],
		"cooldown": 3
	},
	97: { # Berkelium
		"name": "Alpha-Wave",
		"power": 35,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals moderate damage with a 50% chance to stun.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "stun", "duration": 1, "chance": 0.5}],
		"cooldown": 3
	},
	98: { # Californium
		"name": "Neutron Flux",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals moderate damage and executes the target if their HP is below 15%.",
		"target_type": "Enemy",
		"effects": [ {"effect": "execute", "threshold": 0.15}],
		"cooldown": 3
	},
	99: { # Einsteinium
		"name": "Relativistic Slam",
		"power": 30,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage. Deals more damage the faster the user is than the target.",
		"target_type": "Enemy",
		"effects": [],
		"speed_scaling": true,
		"cooldown": 3
	},
	100: { # Fermium
		"name": "Sub-Atomic Void",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals moderate damage and prevents the target from healing for 3 turns.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "heal_block", "duration": 3}],
		"cooldown": 3
	},
	101: { # Mendelevium
		"name": "Creator's Wrath",
		"power": 20,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals damage to the target, and hits 2 random enemies.",
		"target_type": "Enemy",
		"effects": [ {"effect": "random_multi_hit", "hits": 2, "power": 20}],
		"cooldown": 3
	},
	102: { # Nobelium
		"name": "Dynamite Decay",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals moderate damage. Applies Death Bomb: target explodes for 20% Max HP AoE damage to their team on death.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "death_bomb", "duration": 3, "damage_percent": 0.2}],
		"cooldown": 3
	},
	103: { # Lawrencium
		"name": "Cyclotron Nuke",
		"power": 0,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals damage to all enemies.",
		"target_type": "Enemy",
		"effects": [ {"effect": "aoe_power_attack", "power": 30}],
		"cooldown": 4
	},
	104: { # Rutherfordium
		"name": "Alpha Strike",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals 40 damage with an increased chance to critical strike.",
		"target_type": "Enemy",
		"effects": [],
		"crit_bonus": 50.0,
		"cooldown": 3
	},
	105: { # Dubnium
		"name": "Nucleus Hammer",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals 40 damage and stuns the target for 1 turn.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "stun", "duration": 1}],
		"cooldown": 3
	},
	106: { # Seaborgium
		"name": "Seaborg Shell",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals 40 damage and increases Defense by 30% for 2 turns.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "defense", "amount": 30, "percent": true, "duration": 2, "target": "Attacker"}],
		"cooldown": 3
	},
	107: { # Bohrium
		"name": "Resonance Blade",
		"power": 35,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals 35 damage and increases Speed by 30% for 2 turns.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "speed", "amount": 30, "percent": true, "duration": 2, "target": "Attacker"}],
		"cooldown": 3
	},
	108: { # Hassium
		"name": "High-Density Pulse",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals 40 damage and reduces target's Attack by 30%.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "attack", "amount": -30, "percent": true, "duration": 2}],
		"cooldown": 3
	},
	109: { # Meitnerium
		"name": "Fission Strike",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals 40 damage and 50% splash damage to all other enemies.",
		"target_type": "Enemy",
		"effects": [ {"effect": "splash_damage", "percent": 0.5}],
		"cooldown": 3
	},
	110: { # Darmstadtium
		"name": "Synthetic Overdrive",
		"power": 35,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals 35 damage and increases Defense by 40% for 2 turns.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "defense", "amount": 40, "percent": true, "duration": 2, "target": "Attacker"}],
		"cooldown": 3
	},
	111: { # Roentgenium
		"name": "X-Ray Impact",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals 40 damage, ignoring 50% of the enemy's defense.",
		"target_type": "Enemy",
		"effects": [],
		"ignore_def_percent": 50.0,
		"cooldown": 3
	},
	112: { # Copernicium
		"name": "Orbital Smash",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals 40 damage. 50% chance to reset move cooldowns.",
		"target_type": "Enemy",
		"effects": [ {"effect": "reset_cooldowns", "chance": 0.5, "target": "Attacker"}],
		"cooldown": 3
	},
	113: { # Nihonium
		"name": "Rising Sun Strike",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals 40 damage and heals the lowest health ally (including benched) for 100% of damage dealt.",
		"target_type": "Enemy",
		"effects": [ {"effect": "heal_lowest_ally", "scale_stat": "damage_dealt", "scale_factor": 1.0}],
		"cooldown": 3
	},
	114: { # Flerovium
		"name": "Dense Inertia",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Grants a shield scaling with Attack to an ally. Attackers are slowed by 20% for 2 turns.",
		"target_type": "Ally",
		"effects": [
			{"effect": "add_shield", "scale_stat": "attack", "scale_factor": 1.5},
			{"type": "status", "status": "inertia_feedback", "duration": 3}
		],
		"cooldown": 3
	},
	115: { # Moscovium
		"name": "Phase Shift Strike",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals 40 damage. Swaps places with the lowest health ally (including benched) and heals them for 100% of damage dealt.",
		"target_type": "Enemy",
		"effects": [ {"effect": "swap_and_heal_lowest_ally", "scale_stat": "damage_dealt", "scale_factor": 1.0}],
		"cooldown": 3
	},
	116: { # Livermorium
		"name": "Mass Stabilization",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Heals all allies (including benched). Healing amount scales with the user's Attack.",
		"target_type": "Self",
		"effects": [ {"effect": "team_heal", "scale_stat": "attack", "scale_factor": 1.5, "include_bench": true}],
		"cooldown": 3
	},
	117: { # Tennessine
		"name": "Singularity Halide",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Hostile",
		"description": "Creates a singularity hazard. Attacking enemies are poisoned and slowed by 20% for 1 turn.",
		"target_type": "Enemy",
		"effects": [ {"effect": "team_status", "status": "singularity_hazard", "duration": 3, "message": "A singularity forms on the battlefield!"}],
		"cooldown": 3
	},
	118: { # Oganesson
		"name": "Noble Collapse",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Ultimate Shield: Grants invulnerability to all damage and negative effects for 1 turn.",
		"target_type": "Self",
		"effects": [ {"type": "status", "status": "invulnerable", "duration": 1}],
		"cooldown": 3
	}
}

# Calculates final stats based on Group Baseline, Atomic Number (Z), and Stability.
static func calculate_stats(group: Group, atomic_number: int, stability: int = 0) -> Dictionary:
	var result = calculate_stats_with_breakdown(group, atomic_number, stability)
	return result["final_stats"]

static func calculate_stats_with_breakdown(group: Group, atomic_number: int, stability: int = 0) -> Dictionary:
	var base = BASELINES.get(group, BASELINES[Group.UNKNOWN])
	
	var breakdown = {
		"hp": {"base": base.hp * 20.0, "stability": 0.0, "resonance": 0.0, "ship_upgrade": 0.0, "lanthanide_set": 0.0},
		"atk": {"base": base.atk * 2.0, "stability": 0.0, "resonance": 0.0, "ship_upgrade": 0.0, "lanthanide_set": 0.0},
		"def": {"base": base.def * 2.0, "stability": 0.0, "resonance": 0.0, "ship_upgrade": 0.0, "lanthanide_set": 0.0},
		"spd": {"base": base.spd * 2.0, "stability": 0.0, "resonance": 0.0, "ship_upgrade": 0.0, "lanthanide_set": 0.0},
		"crit": {"base": float(base.get("crit", 5)), "stability": 0.0, "resonance": 0.0, "ship_upgrade": 0.0, "lanthanide_set": 0.0}
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
		breakdown.spd.ship_upgrade = PlayerData.get_upgrade_level("gravimetric_sensor") * 0.05
		breakdown.crit.ship_upgrade = PlayerData.get_upgrade_level("cybernetic_implant") * 2.0 # Flat 2% per level
		
		hp_mult += breakdown.hp.ship_upgrade
		atk_mult += breakdown.atk.ship_upgrade
		def_mult += breakdown.def.ship_upgrade
		spd_mult += breakdown.spd.ship_upgrade
	
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
	
	# Crit Chance grows at a higher rate: Base * 5 at 100 stability (+400%)
	var crit_stability_multiplier = 1.0 + (float(stability) / 25.0)
	var crit_stability_bonus = crit_stability_multiplier - 1.0

	# 3. Mastery Buff: At 100% Stability, unlock Class Potential (+10% extra stats)
	if stability >= 100:
		stability_multiplier += 0.1
		stability_bonus += 0.1
		crit_stability_bonus += 0.1
	
	breakdown.hp.stability = stability_bonus
	breakdown.atk.stability = stability_bonus
	breakdown.def.stability = stability_bonus
	breakdown.spd.stability = stability_bonus
	breakdown.crit.stability = crit_stability_bonus
	
	var final_stats = {}
	# Simplified Linear Scaling
	# HP: Base (1-10)
	# Example: Base 5 -> 50 HP
	final_stats["max_hp"] = int((base.hp * 10.0) * stability_multiplier * hp_mult)
	# Example: Base 5 -> 100 HP
	final_stats["max_hp"] = int((base.hp * 20.0) * stability_multiplier * hp_mult)
	
	# Stats: Base (1-10)
	# Example: Base 5 -> 10 Stat
	final_stats["attack"] = int((base.atk * 2.0) * stability_multiplier * atk_mult)
	final_stats["defense"] = int((base.def * 2.0) * stability_multiplier * def_mult)
	final_stats["speed"] = int((base.spd * 2.0) * stability_multiplier * spd_mult)
	final_stats["crit_chance"] = int(breakdown.crit.base * (1.0 + breakdown.crit.stability)) + int(breakdown.crit.ship_upgrade)
	
	return {"final_stats": final_stats, "breakdown": breakdown}

# Calculates the Binding Energy cost to fuse a new element
static func calculate_fusion_cost(target_z: int) -> int:
	# Cost scales exponentially/polynomially with Atomic Number.
	# Using quadratic scaling: 50 * Z^2. This ensures 1 Run ~= 1 Fusion.
	return int(50 * pow(target_z, 2))