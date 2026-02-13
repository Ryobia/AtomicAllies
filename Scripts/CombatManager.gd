extends Node

# NOTE: For this to work globally, add this script to your Project Settings -> Autoload tab.

# The "Strong Against" Map
var strengths = {
	# Placeholder for Chemical Group interactions
	# Example: MonsterData.ChemicalGroup.ALKALI_METAL: MonsterData.ChemicalGroup.HALOGEN
}

# The main damage calculation function.
# It takes the full MonsterData objects to access their types and stats.
func calculate_damage(attacker: MonsterData, defender: MonsterData, is_surged: bool):
	var multiplier = 1.0
	var gives_surge = false
	
	# Use the new Chemical Group
	var attacker_group = attacker.group
	var defender_group = defender.group
	
	# Check for Advantage (2.0x Damage)
	if strengths.has(attacker_group) and strengths[attacker_group] == defender_group:
		multiplier = 2.0
	# Check for Disadvantage (0.75x Damage + gives Surge)
	elif strengths.has(defender_group) and strengths[defender_group] == attacker_group:
		multiplier = 0.75
		gives_surge = true
	
	var final_damage = attacker.base_attack * multiplier
		
	return {"damage": final_damage, "gives_surge": gives_surge}