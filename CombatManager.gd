extends Node

# We use the Types enum from MonsterData
const Types = MonsterData.Types

# The "Strong Against" Map
# Primal Loop: Fire > Nature > Water > Fire
# Astral Loop: Light > Dark > Mind > Light
var strengths = {
	Types.FIRE: Types.NATURE,
	Types.NATURE: Types.WATER,
	Types.WATER: Types.FIRE,
	Types.LIGHT: Types.DARK,
	Types.DARK: Types.MIND,
	Types.MIND: Types.LIGHT
}

# Calculates damage and checks if the defender gets a "Surge"
func calculate_damage(attacker: MonsterData, defender: MonsterData, move_power: int, attacker_has_surge: bool) -> Dictionary:
	var multiplier = 1.0
	var gives_surge = false
	
	# Check Type 1 Interaction
	var result_1 = _get_interaction(attacker.type_1, defender.type_1)
	multiplier *= result_1.multiplier
	if result_1.gives_surge: gives_surge = true
	
	# Check Type 2 Interaction (if defender has one)
	if defender.type_2 != Types.NONE:
		var result_2 = _get_interaction(attacker.type_1, defender.type_2)
		multiplier *= result_2.multiplier
		if result_2.gives_surge: gives_surge = true

	# Apply Surge Buff if attacker was already charged
	if attacker_has_surge:
		if attacker.is_pure:
			multiplier *= 2.0 # Pure Surge (The "Nuke" buff for single-types)
		else:
			multiplier *= 1.5 # Standard Surge

	var final_damage = attacker.base_attack + move_power * multiplier
	return {"damage": final_damage, "gives_surge": gives_surge}

func _get_interaction(atk_type: int, def_type: int) -> Dictionary:
	if strengths.get(atk_type) == def_type:
		# Super Effective
		return {"multiplier": 2.0, "gives_surge": false}
	elif strengths.get(def_type) == atk_type:
		# Resisted (The "Surge" Mechanic)
		return {"multiplier": 0.75, "gives_surge": true}
	else:
		# Neutral
		return {"multiplier": 1.0, "gives_surge": false}
