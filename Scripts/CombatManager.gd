extends Node

# NOTE: For this to work globally, add this script to your Project Settings -> Autoload tab.

# PvE Combat Logic (No Type Chart, No Surge)

# The main damage calculation function.
func calculate_damage(attacker: BattleMonster, defender: BattleMonster, move: MoveData):
	var result = {
		"damage": 0.0,
		"is_crit": false
	}

	# 1. Handle Status Moves (like Shield)
	if move.power == 0:
		# Logic for status moves would go here
		return result

	# 2. Handle Damaging Moves
	# Use current battle stats from BattleMonster nodes
	var effective_attack = attacker.stats.attack
	var effective_defense = defender.stats.defense

	# 3. Calculate final damage using move power and defense mitigation
	# Formula: (Base Attack + Move Power) * Mitigation
	# Mitigation: 100 / (100 + Defense) -> Standard diminishing returns
	var raw_power = effective_attack + move.power
	var mitigation = (100.0 / (100.0 + effective_defense))
	var final_damage = raw_power * mitigation

	result.damage = int(final_damage)
	return result