extends Node

# NOTE: For this to work globally, add this script to your Project Settings -> Autoload tab.

# The "Strong Against" Map
var strengths = {
	# Placeholder for Chemical Group interactions
	# Example: MonsterData.ChemicalGroup.ALKALI_METAL: MonsterData.ChemicalGroup.HALOGEN
}

# The main damage calculation function.
# It takes the full MonsterData objects to access their types and stats.
func process_move(attacker: MonsterData, defender: MonsterData, move: MoveData, attacker_effects: Array, defender_effects: Array):
	var result = {
		"damage": 0.0,
		"effects": []
	}

	# 1. Handle Status Moves (like Shield)
	if move.power == 0:
		if move.name == "Shield":
			result.effects.append({
				"target": "self", # 'self' means the attacker
				"type": "DEFENSE_UP",
				"potency": 1.5, # 50% boost
				"duration": 2 # Lasts for 2 turns
			})
		return result

	# 2. Handle Damaging Moves
	var effective_attack = attacker.base_attack
	var effective_defense = defender.base_defense

	# Apply status effects from previous turns to stats
	for effect in defender_effects:
		if effect.type == "DEFENSE_UP":
			effective_defense *= effect.potency

	# 3. Calculate elemental multiplier
	var multiplier = 1.0
	var attacker_group = attacker.group
	var defender_group = defender.group
	if strengths.has(attacker_group) and strengths[attacker_group] == defender_group:
		multiplier = 2.0
	elif strengths.has(defender_group) and strengths[defender_group] == attacker_group:
		multiplier = 0.75

	# 4. Calculate final damage using move power and defense mitigation
	# Formula: (Base Attack + Move Power) * Mitigation * Element Multiplier
	var raw_power = effective_attack + move.power
	var mitigated_power = raw_power * (100.0 / (100.0 + effective_defense))
	var final_damage = mitigated_power * multiplier

	result.damage = final_damage
	return result