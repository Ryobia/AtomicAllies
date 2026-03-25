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
		{"name": "Valence Flip", "power": 20, "accuracy": 100, "type": "Special", "description": "Toggles the unit's atomic polarity. Applies 1 Reduced [R] stack AND checks the target for an Oxidation Burst. If a burst is triggered, it deals +20% damage.", "cooldown": 2},
		{"name": "Logic Gate", "power": 25, "accuracy": 100, "type": "Special", "is_snipe": true, "description": "Calculates the enemy's defensive pathing. Slows the target by 20% and converts all active [R] stacks into Processing Loops, increasing the multiplier of the next Oxidation Burst by 0.1 per stack.", "cooldown": 2, "effects": [{"type": "stat_mod", "stat": "speed", "amount": -20, "percent": true, "duration": 2}]}
	],
	Group.NONMETAL: [
		{"name": "Oxidation Chain", "power": 25, "accuracy": 100, "type": "Special", "description": "Triggers an Oxidation Burst on the target. If a burst is triggered, the reaction jumps to all adjacent enemies with Reduced [R] stacks.", "cooldown": 2},
		{"name": "Valence Siphon", "power": 35, "accuracy": 100, "type": "Special", "is_snipe": true, "description": "A precise strike that rips away valence electrons. Triggers an Oxidation Burst. For every [R] stack consumed, the target's Speed is reduced by 10% for 2 turns.", "cooldown": 2}
	],
	Group.HALOGEN: [
		{"name": "Hydrofluoric Stream", "power": 30, "accuracy": 100, "type": "Special", "is_snipe": true, "description": "A high-pressure stream of corrosive acid. Triggers an Oxidation Burst. This move gains a +0.5 bonus to the Electronegativity Delta multiplier.", "cooldown": 2},
		{"name": "Halogen Hunger", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Self", "description": "The unit enters a highly reactive state. Increases Speed by 25%. For the next 3 turns, triggering an Oxidation Burst grants the user 20% Action Gauge.", "cooldown": 3, "effects": [{"type": "stat_mod", "stat": "speed", "amount": 25, "percent": true, "duration": 3}, {"type": "status", "status": "halogen_hunger", "duration": 3}]}
	],
	Group.NOBLE_GAS: [
		{"name": "Perfect Configuration", "power": 0, "accuracy": 100, "type": "Status_Friendly", "target_type": "Self", "description": "Achieves a state of perfect atomic balance. Grants Guarded (blocks the next instance of damage) and reduces Global Entropy by 20.", "cooldown": 3, "effects": [{"type": "status", "status": "guarded", "duration": 3}, {"effect": "add_global_entropy", "amount": -20}]},
		{"name": "Stabilizing Pulse", "power": 25, "accuracy": 100, "type": "Physical", "description": "A non-reactive strike that absorbs excess kinetic energy. Increases the user's Defense by 15% and reduces the global Entropy by 10%. (Bonus: 20% reduction if in the Vanguard slot).", "effects": [{"type": "stat_mod", "stat": "defense", "amount": 15, "percent": true, "duration": 2, "target": "Attacker"}]}
	],
	Group.ACTINIDE: [
		{"name": "Fission Burst", "power": 100, "accuracy": 85, "type": "Special", "description": "Triggers a violent Oxidation Burst. For every [R] stack consumed, deal an additional 20% damage but increase the global Entropy by 10. Damage is doubled if Entropy is already above 50%.", "cooldown": 3},
		{"name": "Half-Life Cascade", "power": 0, "accuracy": 100, "type": "Status_Hostile", "is_snipe": true, "description": "Irradiates the target’s atomic structure. For 3 turns, the target takes 5% Max HP damage and their current Reduced [R] stacks double at the start of their turn (up to a cap of 10).", "effects": [{"type": "status", "status": "radiation", "damage_percent": 0.05, "duration": 3}, {"type": "status", "status": "half_life_cascade", "duration": 3}], "cooldown": 2}
	],
	Group.LANTHANIDE: [
		{"name": "Ferromagnetic Surge", "power": 30, "accuracy": 100, "type": "Physical", "description": "A heavy strike that generates an intense magnetic field. Applies 1 Reduced [R] stack. Pulls all active [R] stacks from all other enemies onto the primary target.", "cooldown": 2},
		{"name": "Phosphor Flare", "power": 20, "accuracy": 100, "type": "Special", "description": "A blinding emission of rare-earth light. Applies 1 Reduced [R] stack and the Luminescent status. The next Oxidation Burst against this target deals +50% damage.", "cooldown": 3, "effects": [{"type": "status", "status": "luminescent", "duration": 2}]}
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
		{"name": "Entropy", "power": 100, "accuracy": 100, "type": "Special", "description": "Deals massive damage to a single target and increases Global Entropy by 15.", "cooldown": 4}
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
		"name": "Protanation Drive",
		"power": 30,
		"accuracy": 100,
		"type": "Special",
		"description": "Triggers an Oxidation Burst. Converts consumed [R] stacks into Proton Charges. The next attack against this target deals +10% damage per charge.",
		"effects": [],
		"cooldown": 2
	},
	2: { # Helium
		"name": "Solar Vent",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"target_type": "Self",
		"description": "Small Team Heal. Reduces Global Entropy by 15.",
		"effects": [
			{"effect": "team_heal", "scale_stat": "max_hp", "scale_factor": 0.15},
			{"effect": "add_global_entropy", "amount": -15}
		],
		"cooldown": 3
	},
	3: { # Lithium
		"name": "Ion Battery",
		"power": 25,
		"accuracy": 100,
		"type": "Special",
		"description": "Applies 2 [R] stacks. If the user is at 100% Stability, grants the team 15% Action Gauge.",
		"target_type": "Enemy",
		"effects": [ {"effect": "add_status_stacks", "status": "reduced", "amount": 2, "duration": 3, "target": "Defender"} ],
		"cooldown": 2
	},
	4: { # Beryllium
		"name": "Toxic Lattice",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Reflective Priming. Lowers damage taken by 30%. Every hit taken reflects 2 [R] stacks back onto the attacker.",
		"target_type": "Self",
		"effects": [
			{"type": "status", "status": "toxic_lattice", "duration": 3}
		],
		"cooldown": 3
	},
	5: { # Boron
		"name": "Control Array",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Blocks 1 hit and halves the next 2 instances of Global Entropy generation.",
		"target_type": "Self",
		"effects": [
			{"type": "status", "status": "guarded", "duration": 3},
			{"type": "status", "status": "entropy_halver", "stacks": 2, "duration": 99}
		],
		"cooldown": 3
	},
	6: { # Carbon
		"name": "Catenation Chain",
		"power": 35,
		"accuracy": 100,
		"type": "Special",
		"description": "Triggers an Oxidation Burst. If the target has 3 or more [R] stacks, the burst multiplier is doubled.",
		"target_type": "Enemy",
		"effects": [],
		"cooldown": 2
	},
	7: { # Nitrogen
		"name": "Cryogenic Lock",
		"power": 30,
		"accuracy": 100,
		"type": "Special",
		"description": "Triggers an Oxidation Burst. Has a 20% base chance to Stun the target, increased by 10% for each [R] stack consumed.",
		"target_type": "Enemy",
		"effects": [],
		"cooldown": 2
	},
	8: { # Oxygen
		"name": "Rapid Combustion",
		"power": 30,
		"accuracy": 100,
		"type": "Special",
		"description": "Triggers an Oxidation Burst. For every [R] stack consumed, applies a stack of Burn that deals damage based on the Electronegativity Delta.",
		"target_type": "Enemy",
		"effects": [],
		"cooldown": 2
	},
	9: { # Fluorine
		"name": "Hydrofluoric Etch",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"is_snipe": true,
		"description": "Corrosion: Triggers an Oxidation Burst. Reduces target Defense by 10% per [R] stack consumed (Permanent).",
		"target_type": "Enemy",
		"effects": [],
		"cooldown": 3
	},
	10: { # Neon
		"name": "Neon Beacon",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Forced Taunt. Allies gain 20% Action Gauge (Guiding Light).",
		"target_type": "Self",
		"effects": [
			{"type": "status", "status": "taunt", "duration": 2},
			{"effect": "team_add_atb", "amount": 20.0}
		],
		"cooldown": 3
	},
	11: { # Sodium
		"name": "Solvation Burst",
		"power": 30,
		"accuracy": 100,
		"type": "Special",
		"description": "Applies 2 [R] stacks. Deals double damage and adds +2 stacks if the target is covered in Reactive Vapor.",
		"target_type": "Enemy",
		"effects": [
			{"effect": "add_status_stacks", "status": "reduced", "amount": 2, "duration": 3, "target": "Defender"}
		],
		"cooldown": 2
	},
	12: { # Magnesium
		"name": "Incendiary Flash",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Light Emission. Deals moderate damage. If used from the Vanguard slot, the next Oxidation Burst against the target triggers twice.",
		"target_type": "Enemy",
		"effects": [],
		"cooldown": 2
	},
	13: { # Aluminum
		"name": "Anodized Plate",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and increases Defense by 15%. Reduces the global Entropy generated by the next 2 moves by 5.",
		"target_type": "Enemy",
		"effects": [
			{"type": "stat_mod", "stat": "defense", "amount": 15, "percent": true, "duration": 3, "target": "Attacker"},
			{"type": "status", "status": "entropy_dampener", "amount": 5, "stacks": 2, "duration": 99, "target": "Attacker"}
		],
		"cooldown": 3
	},
	14: { # Silicon
		"name": "Integrated Circuit",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals damage and slows the target. Copies the Vanguard's passive and applies 'Vanguard Circuit' to the team for 2 turns.",
		"target_type": "Enemy",
		"effects": [
			{"type": "stat_mod", "stat": "speed", "amount": -20, "percent": true, "duration": 2},
			{"effect": "apply_vanguard_circuit", "duration": 2}
		],
		"cooldown": 3
	},
	15: { # Phosphorus
		"name": "Spontaneous Fumes",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Hostile",
		"description": "Marks the enemy. At the start of their next turn, triggers an Oxidation Burst using all current [R] stacks for +30% bonus damage.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "spontaneous_fumes", "duration": 2, "message": "%s is covered in volatile fumes!"}],
		"cooldown": 2
	},
	16: { # Sulfur
		"name": "Vulcanization",
		"power": 35,
		"accuracy": 100,
		"type": "Special",
		"description": "Triggers an Oxidation Burst. Permanently reduces the target's Defense by 5% per [R] stack consumed (Max 50%).",
		"target_type": "Enemy",
		"effects": [],
		"cooldown": 2
	},
	17: { # Chlorine
		"name": "Oxidizing Bleach",
		"power": 30,
		"accuracy": 100,
		"type": "Special",
		"description": "Disinfect: Triggers an Oxidation Burst to all enemies. Applies Poison per [R] stack consumed. Poison damage doubled if already poisoned.",
		"target_type": "Enemy",
		"effects": [ {"effect": "aoe_power_attack", "power": 30, "move_name": "Oxidizing Bleach"} ],
		"cooldown": 3
	},
	18: { # Argon
		"name": "Atmospheric Shield",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Grants a 50% Damage Reduction shield to all allies. Prevents all Entropy generation for the team for 2 turns.",
		"target_type": "Self",
		"effects": [
			{"effect": "team_status", "status": "physical_resist", "reduction_amount": 0.5, "duration": 2, "target_team": "ally"},
			{"effect": "team_status", "status": "special_resist", "reduction_amount": 0.5, "duration": 2, "target_team": "ally"},
			{"effect": "team_status", "status": "entropy_shield", "stacks": 99, "duration": 2, "target_team": "ally"}
		],
		"cooldown": 3
	},
	19: { # Potassium
		"name": "Enthalpy Leap",
		"power": 35,
		"accuracy": 100,
		"type": "Special",
		"description": "Applies 3 [R] stacks. Increases global Entropy by 5, but reduces all ally cooldowns by 1.",
		"target_type": "Enemy",
		"effects": [
			{"effect": "add_status_stacks", "status": "reduced", "amount": 3, "duration": 3, "target": "Defender"},
			{"effect": "add_global_entropy", "amount": 5},
			{"effect": "team_reduce_cooldowns", "amount": 1}
		],
		"cooldown": 3
	},
	20: { # Calcium
		"name": "Bone Structure",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Stability Buff. Increases Attack, Defense, and Speed of all allies by 20% and prevents the next 2 instances of global Entropy.",
		"target_type": "Self",
		"effects": [
			{"effect": "aoe_stat_mod", "stat": "attack", "amount": 20, "percent": true, "duration": 3, "target_team": "ally"},
			{"effect": "aoe_stat_mod", "stat": "defense", "amount": 20, "percent": true, "duration": 3, "target_team": "ally"},
			{"effect": "aoe_stat_mod", "stat": "speed", "amount": 20, "percent": true, "duration": 3, "target_team": "ally"},
			{"effect": "add_status_stacks", "status": "entropy_shield", "amount": 2, "duration": 99, "target": "Attacker"}
		],
		"cooldown": 3
	},
	21: { # Scandium
		"name": "Light-Alloy Strike",
		"power": 30,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and raises Defense by 10%. Catalysis: Gain +15% Defense for 2 turns.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "defense", "amount": 10, "percent": true, "duration": 1, "target": "Attacker"}],
		"cooldown": 2
	},
	22: { # Titanium
		"name": "Hardened Bash",
		"power": 30,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and raises Defense by 10%. Catalysis: Gain +15% Defense for 2 turns.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "defense", "amount": 10, "percent": true, "duration": 1, "target": "Attacker"}],
		"cooldown": 2
	},
	23: { # Vanadium
		"name": "Refined Edge",
		"power": 30,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and raises Attack by 10%. Catalysis: Gain +20% Accuracy for 2 turns.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "attack", "amount": 10, "percent": true, "duration": 1, "target": "Attacker"}],
		"cooldown": 2
	},
	24: { # Chromium
		"name": "Mirror Luster",
		"power": 30,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and applies 1 [R] stack. Catalysis: Reflect 10% damage as a Vanguard Shield.",
		"target_type": "Enemy",
		"effects": [ {"effect": "add_status_stacks", "status": "reduced", "amount": 1, "duration": 3, "target": "Defender"}],
		"cooldown": 3
	},
	25: { # Manganese
		"name": "Magnetic Slam",
		"power": 30,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and applies 1 [R] stack. Catalysis: Apply an additional [R] stack.",
		"target_type": "Enemy",
		"effects": [ {"effect": "add_status_stacks", "status": "reduced", "amount": 1, "duration": 3, "target": "Defender"}],
		"cooldown": 3
	},
	26: { # Iron
		"name": "Magnetic Slam",
		"power": 30,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and applies 1 [R] stack. Catalysis: Apply an additional [R] stack.",
		"target_type": "Enemy",
		"effects": [ {"effect": "add_status_stacks", "status": "reduced", "amount": 1, "duration": 3, "target": "Defender"}],
		"cooldown": 2
	},
	27: { # Cobalt
		"name": "Blue-Steel Guard",
		"power": 30,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and applies 1 [R] stack. Catalysis: Grant Shield (25% damage dealt).",
		"target_type": "Enemy",
		"effects": [ {"effect": "add_status_stacks", "status": "reduced", "amount": 1, "duration": 3, "target": "Defender"}],
		"cooldown": 2
	},
	28: { # Nickel
		"name": "Plated Impact",
		"power": 30,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and applies 1 [R] stack. Catalysis: -10% Enemy Speed.",
		"target_type": "Enemy",
		"effects": [ {"effect": "add_status_stacks", "status": "reduced", "amount": 1, "duration": 3, "target": "Defender"}],
		"cooldown": 2
	},
	29: { # Copper
		"name": "Conductive Whip",
		"power": 30,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and applies 1 [R] stack. Catalysis: +15% Action Gauge to self.",
		"target_type": "Enemy",
		"effects": [ {"effect": "add_status_stacks", "status": "reduced", "amount": 1, "duration": 3, "target": "Defender"}],
		"cooldown": 2
	},
	30: { # Zinc
		"name": "Galvanized Bash",
		"power": 30,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and applies 1 [R] stack. Catalysis: +10% Action Gauge to all allies.",
		"target_type": "Enemy",
		"effects": [ {"effect": "add_status_stacks", "status": "reduced", "amount": 1, "duration": 3, "target": "Defender"}],
		"cooldown": 2
	},
	31: { # Gallium
		"name": "Liquid Melting",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals damage and reduces enemy Speed by 20%. If Global Entropy is above 30, heals the user for 10% Max HP.",
		"target_type": "Enemy",
		"effects": [
			{"type": "stat_mod", "stat": "speed", "amount": -20, "percent": true, "duration": 2}
		],
		"cooldown": 2
	},
	32: { # Germanium
		"name": "Transistor Gate",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"is_snipe": true,
		"description": "Deals damage (Snipe). Swaps the Action Gauge of the user with the Vanguard.",
		"target_type": "Enemy",
		"effects": [ {"effect": "swap_atb_vanguard"} ],
		"cooldown": 2
	},
	33: { # Arsenic
		"name": "Doped Lattice",
		"power": 30,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals damage and applies Poison. Increases the damage of all active DoTs by 5% per [R] stack currently on the enemy.",
		"target_type": "Enemy",
		"effects": [
			{"type": "status", "status": "poison", "damage_percent": 0.05, "duration": 3},
			{"effect": "amplify_dots_by_r"}
		],
		"cooldown": 3
	},
	34: { # Selenium
		"name": "Selenium Semiconductor",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Triggers an Oxidation Burst. If this move defeats the target, the user enters an Excited State for 1 turn (Ignores Defense).",
		"target_type": "Enemy",
		"effects": [],
		"cooldown": 2
	},
	35: { # Bromine
		"name": "Halon Extinguisher",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Fire Suppressant: Triggers an Oxidation Burst. Slows target by 20%. Consumes [R] stacks to reset target's Action Gauge to 0.",
		"target_type": "Enemy",
		"effects": [
			{"type": "stat_mod", "stat": "speed", "amount": -20, "percent": true, "duration": 2}
		],
		"cooldown": 3
	},
	36: { # Krypton
		"name": "Fluorescent Pulse",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Cleanses 2 debuffs from the user and restores 25% Stability (Reduces Global Entropy by 25).",
		"target_type": "Self",
		"effects": [
			{"effect": "cleanse", "amount": 2, "target": "Attacker"},
			{"effect": "add_global_entropy", "amount": -25}
		],
		"cooldown": 3
	},
	37: { # Rubidium
		"name": "Infrared Glow",
		"power": 25,
		"accuracy": 100,
		"type": "Special",
		"description": "Applies 2 [R] stacks. The target is Illuminated (cannot evade) for 3 turns, and their [R] stacks cannot be cleansed.",
		"target_type": "Enemy",
		"effects": [
			{"effect": "add_status_stacks", "status": "reduced", "amount": 2, "duration": 3, "target": "Defender"},
			{"type": "status", "status": "illuminated", "duration": 3, "target": "Defender"}
		],
		"cooldown": 2
	},
	38: { # Strontium
		"name": "Crimson Resonance",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Counter-Frequency. When hit, has a 50% chance to immediately use a Base Move as a free counter-attack.",
		"target_type": "Self",
		"effects": [ {"type": "status", "status": "crimson_resonance", "duration": 3} ],
		"cooldown": 3
	},
	39: { # Yttrium
		"name": "Luminescent Arc",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and increases Crit Chance by 15%. Catalysis: Spread 1 [R] stack to adjacent enemies.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "crit_chance", "amount": 15, "duration": 2, "target": "Attacker"}],
		"cooldown": 2
	},
	40: { # Zirconium
		"name": "Gemstone Guard",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and raises Defense by 15% for 1 turn. Catalysis: Restores 10% Stability (Reduces Global Entropy by 10).",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "defense", "amount": 15, "percent": true, "duration": 1, "target": "Attacker"}],
		"cooldown": 2
	},
	41: { # Niobium
		"name": "Super-Conduct",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and raises Speed by 15% for 1 turn. Catalysis: Reduces the user's move cooldowns by 1.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "speed", "amount": 15, "percent": true, "duration": 1, "target": "Attacker"}],
		"cooldown": 2
	},
	42: { # Molybdenum
		"name": "Heat-Sink Bash",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and lowers enemy Defense by 15%. Catalysis: Reduces Global Entropy by 5.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "defense", "amount": -15, "percent": true, "duration": 2}],
		"cooldown": 2
	},
	43: { # Technetium
		"name": "Isotope Pulse",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and increases Crit Chance by 15%. Catalysis: Doubles the damage of the consumed DoT.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "crit_chance", "amount": 15, "duration": 2, "target": "Attacker"}],
		"cooldown": 2
	},
	44: { # Ruthenium
		"name": "Catalytic Blast",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and lowers enemy Defense by 15%. Catalysis: Apply 1 [R] stack after consumption.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "defense", "amount": -15, "percent": true, "duration": 2}],
		"cooldown": 2
	},
	45: { # Rhodium
		"name": "Reflective Shell",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and grants a Reflective Shell (reflects 30% of next hit). Catalysis: Double the reflection damage.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "reflective_shell", "duration": 3, "target": "Attacker"}],
		"cooldown": 3
	},
	46: { # Palladium
		"name": "H-Absorb Shield",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and grants an Absorb Shield (heals 30% of next hit). Catalysis: The shield is applied to the entire party.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "absorb_shield", "duration": 3, "target": "Attacker"}],
		"cooldown": 3
	},
	47: { # Silver
		"name": "Sterling Flash",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and raises Speed by 15% for 1 turn. Catalysis: +20% Action Gauge immediately.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "speed", "amount": 15, "percent": true, "duration": 1, "target": "Attacker"}],
		"cooldown": 2
	},
	48: { # Cadmium Transition Metal
		"name": "Neutron Dampener",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and reduces enemy Attack by 15%. Catalysis: Target is Suppressed (cannot generate Entropy) for 2 turns.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "attack", "amount": -15, "percent": true, "duration": 2}],
		"cooldown": 2
	},
	49: { # Indium Post-Transition Metal
		"name": "Soft-Solder",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Repair: Increases an ally's Defense by 20%, cleanses 1 debuff, and reduces Global Entropy by 5.",
		"target_type": "Ally",
		"effects": [
			{"type": "stat_mod", "stat": "defense", "amount": 20, "percent": true, "duration": 3},
			{"effect": "cleanse", "amount": 1},
			{"effect": "add_global_entropy", "amount": -5}
		],
		"cooldown": 3
	},
	50: { # Tin Post-Transition Metal
		"name": "Crystalline Cry",
		"power": 0,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals AOE damage to all enemies. Damage is increased by 20% against targets with [R] stacks.",
		"target_type": "Enemy",
		"effects": [ {"effect": "aoe_power_attack", "power": 30, "move_name": "Crystalline Cry"}],
		"cooldown": 3
	},
	51: { # Antimony Metalloid
		"name": "Thermal Barrier",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Increases an ally's Defense by 30%. While active, reflects 100% of gained Global Entropy back at enemies as damage.",
		"target_type": "Ally",
		"effects": [
			{"type": "stat_mod", "stat": "defense", "amount": 30, "percent": true, "duration": 3},
			{"type": "status", "status": "entropy_reflect_100", "duration": 3}
		],
		"cooldown": 3
	},
	52: { # Tellurium Metalloid
		"name": "P-N Junction",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals damage. Converts 50% of the current Global Entropy into a Shield for the party.",
		"target_type": "Enemy",
		"effects": [ {"effect": "entropy_to_shield"} ],
		"cooldown": 3
	},
	53: { # Iodine Halogen
		"name": "Sublimation Burst",
		"power": 60,
		"accuracy": 100,
		"type": "Special",
		"description": "Purple Vapor: Triggers an Oxidation Burst. Ignores 10% of Enemy Defense for every [R] stack consumed.",
		"target_type": "Enemy",
		"effects": [],
		"cooldown": 3
	},
	54: { # Xenon Noble Gas
		"name": "Anaesthetic Cloud",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Hostile",
		"description": "AOE Stun (1 turn). Team heals for 1% HP per Entropy stack currently active.",
		"target_type": "Enemy",
		"effects": [ {"effect": "anaesthetic_cloud"} ],
		"cooldown": 3
	},
	55: { # Cesium Alkali Metal
		"name": "Atomic Clockwork",
		"power": 25,
		"accuracy": 100,
		"type": "Special",
		"description": "Applies 1 [R] stack. The lowest electronegativity makes it a perfect primer. Resets the user's move cooldowns.",
		"target_type": "Enemy",
		"effects": [
			{"effect": "add_status_stacks", "status": "reduced", "amount": 1, "duration": 3, "target": "Defender"},
			{"effect": "reset_cooldowns", "target": "Attacker"}
		],
		"cooldown": 3
	},
	56: { # Barium Alkaline Earth Metal
		"name": "Contrast Shadow",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Hostile",
		"description": "Detection. Marks the target. All [R] stacks on this target are worth 0.05 more in the V.I.E. multiplier calculation.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "contrast_shadow", "duration": 3} ],
		"cooldown": 2
	},
	57: { # Lanthanum Lanthanide
		"name": "Lurking Strike",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Hidden Potential: Deals damage and applies 1 [R] stack. Increases the next Oxidation Burst's Δχ multiplier by 0.3.",
		"target_type": "Enemy",
		"effects": [
			{"effect": "add_status_stacks", "status": "reduced", "amount": 1, "duration": 3, "target": "Defender"},
			{"type": "status", "status": "hidden_potential", "duration": 99, "target": "Attacker"}
		],
		"cooldown": 3
	},
	58: { # Cerium
		"name": "Self-Clean Bash",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Catalytic Purge: Deals damage. Heals the user for 5% Max HP for every debuff pulled this turn.",
		"target_type": "Enemy",
		"effects": [],
		"cooldown": 3
	},
	59: { # Praseodymium
		"name": "Twin-Green Pulse",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Praseo-Mirror: Deals damage and applies 1 [R] stack. Copies 1 random buff from an ally to the user.",
		"target_type": "Enemy",
		"effects": [
			{"effect": "add_status_stacks", "status": "reduced", "amount": 1, "duration": 3, "target": "Defender"},
			{"effect": "praseo_mirror", "target": "Attacker"}
		],
		"cooldown": 3
	},
	60: { # Neodymium
		"name": "Hyper-Mag Crush",
		"power": 60,
		"accuracy": 100,
		"type": "Physical",
		"description": "Permanent Magnet: Massive damage. Damage increases by 25% for every [R] stack on the target.",
		"target_type": "Enemy",
		"effects": [],
		"cooldown": 3
	},
	61: { # Promethium
		"name": "Beta Radiance",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Unstable Glow: Deals damage and applies Radiation. Radiation damage is doubled if the target has 5+ [R] stacks.",
		"target_type": "Enemy",
		"effects": [],
		"cooldown": 3
	},
	62: { # Samarium
		"name": "Cobalt-Sam Siphon",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Energy Draw: Deals damage and applies 1 [R] stack. Steals 5% Action Gauge for every [R] stack on the target.",
		"target_type": "Enemy",
		"effects": [
			{"effect": "add_status_stacks", "status": "reduced", "amount": 1, "duration": 3, "target": "Defender"}
		],
		"cooldown": 3
	},
	63: { # Europium
		"name": "Phosphor Flare",
		"power": 30,
		"accuracy": 100,
		"type": "Special",
		"description": "Luminescent Mark: Blinds the target for 1 turn. The next Oxidation Burst against this target deals +50% damage.",
		"target_type": "Enemy",
		"effects": [
			{"type": "status", "status": "refracted", "duration": 1},
			{"type": "status", "status": "luminescent", "duration": 3}
		],
		"cooldown": 3
	},
	64: { # Gadolinium
		"name": "Contrast Spike",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"is_snipe": true,
		"description": "MRI Trace: Deals damage (Snipe). Every [R] stack on the target counts as 1.5 stacks for 2 turns.",
		"target_type": "Enemy",
		"effects": [
			{"type": "status", "status": "mri_trace", "duration": 2}
		],
		"cooldown": 3
	},
	65: { # Terbium
		"name": "Green Beam",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Solid-State Lock: Deals damage and applies 1 [R] stack. The target cannot gain buffs for 2 turns.",
		"target_type": "Enemy",
		"effects": [
			{"effect": "add_status_stacks", "status": "reduced", "amount": 1, "duration": 3, "target": "Defender"},
			{"type": "status", "status": "buff_lock", "duration": 2}
		],
		"cooldown": 3
	},
	66: { # Dysprosium
		"name": "Hard-to-Get Bash",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Magnetic Flux: Deals damage and increases user Defense by 30%. User gains Guarded if the target has 3+ [R] stacks.",
		"target_type": "Enemy",
		"effects": [
			{"type": "stat_mod", "stat": "defense", "amount": 30, "percent": true, "duration": 3, "target": "Attacker"}
		],
		"cooldown": 3
	},
	67: { # Holmium
		"name": "Vortex Slam",
		"power": 0,
		"accuracy": 100,
		"type": "Physical",
		"description": "High-Flux: Deals AOE damage. Immediately triggers the 'Pull' passive again on all enemies hit.",
		"target_type": "Enemy",
		"effects": [
			{"effect": "aoe_power_attack", "power": 30, "move_name": "Vortex Slam"}
		],
		"cooldown": 3
	},
	68: { # Erbium
		"name": "Optical Pulse",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Fiber-Optic Reset: Increases an ally's Speed by 30%. Resets the cooldowns of the ally with the lowest Action Gauge.",
		"target_type": "Ally",
		"effects": [
			{"type": "stat_mod", "stat": "speed", "amount": 30, "percent": true, "duration": 3},
			{"effect": "fiber_optic_reset"}
		],
		"cooldown": 3
	},
	69: { # Thulium
		"name": "Portable X-Ray",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Scintillation: Deals damage and applies 1 [R] stack. Deals 20% True Damage to enemy shields.",
		"target_type": "Enemy",
		"effects": [
			{"effect": "add_status_stacks", "status": "reduced", "amount": 1, "duration": 3, "target": "Defender"},
			{"effect": "scintillation_shield_damage", "target": "Defender"}
		],
		"cooldown": 3
	},
	70: { # Ytterbium
		"name": "Isotope Anchor",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Singularity Lock: Deals damage and applies 1 [R] stack. [R] stacks on this target cannot be cleansed or expire.",
		"target_type": "Enemy",
		"effects": [
			{"effect": "add_status_stacks", "status": "reduced", "amount": 1, "duration": 3, "target": "Defender"},
			{"type": "status", "status": "irradiated_lock", "duration": 2}
		],
		"cooldown": 3
	},
	71: { # Lutetium
		"name": "Dense Decay",
		"power": 60,
		"accuracy": 100,
		"type": "Physical",
		"description": "Final Shell: Deals heavy damage. Damage is tripled if the target is the only enemy remaining.",
		"target_type": "Enemy",
		"effects": [],
		"cooldown": 3
	},
	72: { # Hafnium
		"name": "Control-Rod Bash",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and reduces target ATK by 20%. Catalysis: Target is Inhibited (cannot use Unique moves) for 2 turns.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "attack", "amount": -20, "percent": true, "duration": 2}],
		"cooldown": 3
	},
	73: { # Tantalum
		"name": "Capacitor Discharge",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and increases user SPD by 20% for 2 turns. Catalysis: +15% Action Gauge immediately.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "speed", "amount": 20, "percent": true, "duration": 2, "target": "Attacker"}],
		"cooldown": 3
	},
	74: { # Tungsten
		"name": "Heavy-Density Slam",
		"power": 30,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and stuns the target for 1 turn. Catalysis: Deals 10% Max HP True Damage.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "stun", "duration": 1}],
		"cooldown": 3
	},
	75: { # Rhenium
		"name": "Super-Alloy Reinforce",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and increases user DEF by 20% for 2 turns. Catalysis: Apply Defense buff to the Vanguard.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "defense", "amount": 20, "percent": true, "duration": 2, "target": "Attacker"}],
		"cooldown": 3
	},
	76: { # Osmium
		"name": "Osmium Pressure",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and reduces target SPD by 20%. Catalysis: Apply 2 additional [R] stacks.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "speed", "amount": -20, "percent": true, "duration": 2}],
		"cooldown": 3
	},
	77: { # Iridium
		"name": "Iridescent Guard",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and reflects 60% of incoming damage for 2 turns. Catalysis: Reflection damage increased to 100%.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "static_reflection", "damage_percent": 0.6, "duration": 2, "target": "Attacker"}],
		"cooldown": 3
	},
	78: { # Platinum
		"name": "Noble Catalyst",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and increases user Crit Chance by 25%. Catalysis: Reduce all ally move cooldowns by 1.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "crit_chance", "amount": 25, "duration": 2, "target": "Attacker"}],
		"cooldown": 3
	},
	79: { # Gold
		"name": "Aurum Radiance",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals damage and heals team for 10% of damage dealt. Catalysis: Healing is doubled and reduces Global Entropy by 5.",
		"target_type": "Enemy",
		"effects": [ {"effect": "team_heal", "scale_stat": "damage_dealt", "scale_factor": 0.1}],
		"cooldown": 3
	},
	80: { # Mercury
		"name": "Liquid Metal Coil",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and applies a potent poison to the target. Catalysis: Spread a copy of the consumed DoT to a random enemy.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "poison", "damage_percent": 0.1, "duration": 3}],
		"cooldown": 3
	},
	81: { # Thallium
		"name": "Toxic Heavy",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Bio-Accumulation: Deals damage and applies a deadly poison that increases in damage the longer it stays active.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "bio_poison", "damage_percent": 0.05, "duration": 4}],
		"cooldown": 3
	},
	82: { # Lead
		"name": "Density Barrier",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Radiation Shielding: Grants the user a massive shield (40% Max HP). The entire team becomes immune to Radiation damage for 2 turns.",
		"target_type": "Self",
		"effects": [ 
			{"effect": "add_shield", "scale_stat": "max_hp", "scale_factor": 0.4},
			{"effect": "team_status", "status": "radiation_immunity", "duration": 2, "target_team": "ally", "message": "The team is shielded from radiation!"}
		],
		"cooldown": 3
	},
	83: { # Bismuth
		"name": "Spiral Crystal",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage. Reflects 50% of any incoming Entropy back at the enemy as physical damage.",
		"target_type": "Enemy",
		"effects": [
			{"type": "status", "status": "entropy_reflect", "duration": 3, "target": "Attacker"}
		],
		"cooldown": 3
	},
	84: { # Polonium
		"name": "Alpha Fission",
		"power": 60,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals heavy damage. Applies 2 [R] stacks and Radiation to the target.",
		"target_type": "Enemy",
		"effects": [
			{"effect": "add_status_stacks", "status": "reduced", "amount": 2, "duration": 3, "target": "Defender"},
			{"type": "status", "status": "radiation", "damage_percent": 0.05, "duration": 3}
		],
		"cooldown": 3
	},
	85: { # Astatine
		"name": "Short-Lived Decay",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Unstable Halide: Triggers an Oxidation Burst. If any [R] stacks are consumed, applies Radiation and Poison.",
		"target_type": "Enemy",
		"effects": [],
		"cooldown": 3
	},
	86: { # Radon
		"name": "Alpha Dispersion",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Grants a shield that reflects 40% of damage. Applies Radiation to the attacker.",
		"target_type": "Self",
		"effects": [
			{"type": "status", "status": "static_reflection", "damage_percent": 0.4, "duration": 3},
			{"type": "status", "status": "radiation_feedback", "duration": 3}
		],
		"cooldown": 3
	},
	87: { # Francium
		"name": "Isotope Overload",
		"power": 50,
		"accuracy": 100,
		"type": "Special",
		"description": "The Heavy Primer. Applies 5 [R] stacks and Radiation to the target. Increases Global Entropy by 20.",
		"target_type": "Enemy",
		"effects": [
			{"effect": "add_status_stacks", "status": "reduced", "amount": 5, "duration": 3, "target": "Defender"},
			{"type": "status", "status": "radiation", "damage_percent": 0.05, "duration": 3, "target": "Defender"},
			{"effect": "add_global_entropy", "amount": 20}
		],
		"cooldown": 3
	},
	88: { # Radium
		"name": "Radiant Nucleus",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "The Heavy Tank. Heals 10% HP per turn, but increases global Entropy by 5 every time the user takes a turn.",
		"target_type": "Self",
		"effects": [ {"type": "status", "status": "radiant_nucleus", "duration": 99} ],
		"cooldown": 3
	},
		89: { # Actinium
		"name": "Cherenkov Pulse",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals damage and applies 1 [R] stack. Target is Irradiated. Their [R] stacks cannot be removed for 2 turns.",
		"target_type": "Enemy",
		"effects": [
			{"effect": "add_status_stacks", "status": "reduced", "amount": 1, "duration": 3, "target": "Defender"},
			{"type": "status", "status": "irradiated_lock", "duration": 2}
		],
		"cooldown": 3
	},
	90: { # Thorium
		"name": "Breeder Reactor",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Increases an ally's Attack and Defense by 20%. Reduces the Entropy generated by the next 3 ally moves by 10.",
		"target_type": "Ally",
		"effects": [
			{"type": "stat_mod", "stat": "attack", "amount": 20, "percent": true, "duration": 3},
			{"type": "stat_mod", "stat": "defense", "amount": 20, "percent": true, "duration": 3},
			{"type": "status", "status": "entropy_dampener", "amount": 10, "stacks": 3, "duration": 99}
		],
		"cooldown": 3
	},
	91: { # Protactinium
		"name": "Precursor Strike",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals damage and applies 1 [R] stack. If the target has Radiation, apply 2 additional [R] stacks.",
		"target_type": "Enemy",
		"effects": [
			{"effect": "add_status_stacks", "status": "reduced", "amount": 1, "duration": 3, "target": "Defender"}
		],
		"cooldown": 2
	},
	92: { # Uranium
		"name": "Critical Detonation",
		"power": 60,
		"accuracy": 90,
		"type": "Special",
		"description": "Fission: Triggers an Oxidation Burst. Leaves a Radiation DoT equal to 50% of the damage dealt.",
		"target_type": "Enemy",
		"effects": [],
		"cooldown": 3
	},
	93: { # Neptunium
		"name": "Tidal Decay",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Transuranic Bridge: Deals damage and applies Radiation and 1 [R] stack. If the target already has Radiation, user gains 15% Action Gauge.",
		"target_type": "Enemy",
		"effects": [
			{"type": "status", "status": "radiation", "damage_percent": 0.05, "duration": 3},
			{"effect": "add_status_stacks", "status": "reduced", "amount": 1, "duration": 3, "target": "Defender"}
		],
		"cooldown": 3
	},
	94: { # Plutonium
		"name": "Transuranic Decay",
		"power": 50,
		"accuracy": 100,
		"type": "Special",
		"description": "Consumes all [R] stacks on the field to deal 100% Splash Damage to all enemies.",
		"target_type": "Enemy",
		"effects": [],
		"cooldown": 4
	},
	95: { # Americium
		"name": "Ionization Beam",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"is_snipe": true,
		"description": "Smoke Detector: Deals damage (Snipe). Reveals enemy weaknesses, increasing the Δχ multiplier of the next hit against them by 0.5.",
		"target_type": "Enemy",
		"effects": [
			{"type": "status", "status": "smoke_detector", "duration": 2}
		],
		"cooldown": 3
	},
	96: { # Curium
		"name": "Alpha Glow",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Thermal Decay: Deals damage and applies Burn. Burn damage scales with the number of [R] stacks on the target.",
		"target_type": "Enemy",
		"effects": [],
		"cooldown": 3
	},
	97: { # Berkelium
		"name": "Berkeley Resonance",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Synthetic Boost: Deals damage and applies 1 [R] stack. Reduces the HP cost or self-damage of the next ally move by 50%.",
		"target_type": "Enemy",
		"effects": [
			{"effect": "add_status_stacks", "status": "reduced", "amount": 1, "duration": 3, "target": "Defender"},
			{"effect": "team_status", "status": "synthetic_boost", "duration": 99, "target_team": "ally"}
		],
		"cooldown": 3
	},
	98: { # Californium
		"name": "Neutron Flux",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Chain Reaction: Deals damage and applies 1 [R] stack. Immediately doubles the number of [R] stacks on the target.",
		"target_type": "Enemy",
		"effects": [
			{"effect": "add_status_stacks", "status": "reduced", "amount": 1, "duration": 3, "target": "Defender"}
		],
		"cooldown": 3
	},
	99: { # Einsteinium
		"name": "Relativistic Impact",
		"power": 50,
		"accuracy": 100,
		"type": "Physical",
		"description": "E=mc2: Damage increases by 1% for every point of current Global Entropy.",
		"target_type": "Enemy",
		"effects": [],
		"cooldown": 3
	},
	100: { # Fermium
		"name": "Pile Zero",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Neutron Trap: Grants the Vanguard a shield (30% Max HP). When the shield is hit, apply 1 [R] stack to the attacker.",
		"target_type": "Self",
		"effects": [
			{"effect": "add_shield_vanguard", "amount": 0.3},
			{"effect": "status_vanguard", "status": "neutron_trap", "duration": 3}
		],
		"cooldown": 3
	},
	101: { # Mendelevium
		"name": "Periodic Pulse",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Law of Octets: Deals damage and applies 1 [R] stack. If the target has exactly 8 [R] stacks, the next detonation deals Double Damage.",
		"target_type": "Enemy",
		"effects": [
			{"effect": "add_status_stacks", "status": "reduced", "amount": 1, "duration": 3, "target": "Defender"}
		],
		"cooldown": 3
	},
	102: { # Nobelium
		"name": "Peacekeeper Burst",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Inert Explosion: Triggers an Oxidation Burst, but does not consume the Radiation DoT on the target.",
		"target_type": "Enemy",
		"effects": [],
		"cooldown": 3
	},
	103: { # Lawrencium
		"name": "Final Chain",
		"power": 80,
		"accuracy": 90,
		"type": "Special",
		"description": "Consumes all [R] stacks and Entropy. Damage increases by 2% for every point of Entropy consumed.",
		"target_type": "Enemy",
		"effects": [],
		"cooldown": 4
	},
	104: { # Rutherfordium
		"name": "Alpha Strike",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage with +50% Crit Chance. Catalysis: Guaranteed Critical Hit with +50% Crit Damage.",
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
		"description": "Deals damage and stuns the target for 1 turn. Catalysis: Resets Global Entropy to 0.",
		"target_type": "Enemy",
		"effects": [ {"type": "status", "status": "stun", "duration": 1}],
		"cooldown": 3
	},
	106: { # Seaborgium
		"name": "Seaborg Shell",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and increases Defense by 30% for 2 turns. Catalysis: Grants Team Radiation Shield (blocks next DoT).",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "defense", "amount": 30, "percent": true, "duration": 2, "target": "Attacker"}],
		"cooldown": 3
	},
	107: { # Bohrium
		"name": "Resonance Blade",
		"power": 35,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and increases Speed by 30% for 2 turns. Catalysis: +15% Action Gauge for all allies.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "speed", "amount": 30, "percent": true, "duration": 2, "target": "Attacker"}],
		"cooldown": 3
	},
	108: { # Hassium
		"name": "High-Density Pulse",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals damage and reduces target's Attack by 30%. Catalysis: Target is Inhibited (Cannot use Unique moves).",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "attack", "amount": -30, "percent": true, "duration": 2}],
		"cooldown": 3
	},
	109: { # Meitnerium
		"name": "Fission Strike",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals damage and 50% splash damage to all other enemies. Catalysis: 100% Splash Damage and applies 1 [R] stack to all enemies hit.",
		"target_type": "Enemy",
		"effects": [ {"effect": "splash_damage", "percent": 0.5}],
		"cooldown": 3
	},
	110: { # Darmstadtium
		"name": "Synthetic Overdrive",
		"power": 35,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and increases Defense by 40% for 2 turns. Catalysis: Heals user for 15% Max HP.",
		"target_type": "Enemy",
		"effects": [ {"type": "stat_mod", "stat": "defense", "amount": 40, "percent": true, "duration": 2, "target": "Attacker"}],
		"cooldown": 3
	},
	111: { # Roentgenium
		"name": "X-Ray Impact",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals damage, ignoring 50% of the enemy's defense. Catalysis: Ignores 100% Defense and bypasses Guards/Shields.",
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
		"description": "Deals damage. 50% chance to reset move cooldowns. Catalysis: 100% chance to reset cooldowns.",
		"target_type": "Enemy",
		"effects": [ {"effect": "reset_cooldowns", "chance": 0.5, "target": "Attacker"}],
		"cooldown": 3
	},
	113: { # Nihonium
		"name": "Synthetic Shell",
		"power": 40,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals damage and increases Defense by 20%. Reset: 25% chance to reset the Vanguard's cooldowns.",
		"target_type": "Enemy",
		"effects": [
			{"type": "stat_mod", "stat": "defense", "amount": 20, "percent": true, "duration": 3, "target": "Attacker"},
			{"effect": "reset_vanguard_cooldowns", "chance": 0.25}
		],
		"cooldown": 3
	},
	114: { # Flerovium
		"name": "Inert-Heavy",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "The Ultimate Heat Sink. Negates the next instance of damage and reduces Global Entropy by 20.",
		"target_type": "Self",
		"effects": [
			{"type": "status", "status": "guarded", "duration": 3},
			{"effect": "add_global_entropy", "amount": -20}
		],
		"cooldown": 3
	},
	115: { # Moscovium
		"name": "Unstable Mass",
		"power": 60,
		"accuracy": 100,
		"type": "Physical",
		"description": "Deals heavy damage. Deals +5% extra damage for every point of Global Entropy active.",
		"target_type": "Enemy",
		"effects": [],
		"cooldown": 3
	},
	116: { # Livermorium
		"name": "Decay Strike",
		"power": 40,
		"accuracy": 100,
		"type": "Special",
		"description": "Deals damage and applies Radiation. The target's [R] stacks multiply by 1.5x at the end of their turn.",
		"target_type": "Enemy",
		"effects": [
			{"type": "status", "status": "radiation", "damage_percent": 0.05, "duration": 3},
			{"type": "status", "status": "decay_catalyst", "duration": 3}
		],
		"cooldown": 3
	},
	117: { # Tennessine
		"name": "Relativistic Siphon",
		"power": 60,
		"accuracy": 100,
		"type": "Special",
		"description": "Atomic Hunger: Triggers an Oxidation Burst. User gains 10% Action Gauge for every [R] stack consumed.",
		"target_type": "Enemy",
		"effects": [],
		"cooldown": 3
	},
	118: { # Oganesson
		"name": "Relativistic Shell",
		"power": 0,
		"accuracy": 100,
		"type": "Status_Friendly",
		"description": "Blocks the next 2 hits. Resets all ally move cooldowns.",
		"target_type": "Self",
		"effects": [
			{"type": "status", "status": "guarded", "stacks": 2, "duration": 3},
			{"effect": "team_reset_cooldowns"}
		],
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