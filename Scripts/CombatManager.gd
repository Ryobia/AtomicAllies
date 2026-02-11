extends Node

# NOTE: For this to work globally, add this script to your Project Settings -> Autoload tab.

# Define our 2 loops from the design document
enum Types { FIRE, NATURE, WATER, LIGHT, DARK, MIND, NONE }

# The "Strong Against" Map
var strengths = {
	Types.FIRE: Types.NATURE,
	Types.NATURE: Types.WATER,
	Types.WATER: Types.FIRE,
	Types.LIGHT: Types.DARK,
	Types.DARK: Types.MIND,
	Types.MIND: Types.LIGHT
}

# The main damage calculation function.
# It takes the full MonsterData objects to access their types and stats.
func calculate_damage(attacker: MonsterData, defender: MonsterData, is_surged: bool):
	var multiplier = 1.0
	var gives_surge = false
	
	# For now, we only handle the first type. Dual-type logic will come later.
	var attacker_type = attacker.type_1
	var defender_type = defender.type_1
	
	# Check for Advantage (2.0x Damage)
	if strengths.has(attacker_type) and strengths[attacker_type] == defender_type:
		multiplier = 2.0
	# Check for Disadvantage (0.75x Damage + gives Surge)
	elif strengths.has(defender_type) and strengths[defender_type] == attacker_type:
		multiplier = 0.75
		gives_surge = true
	
	var final_damage = attacker.base_attack * multiplier
		
	return {"damage": final_damage, "gives_surge": gives_surge}