extends Node

var owned_monsters: Array[MonsterData] = []
var pity_essence: float = 0.0
var max_pity: float = 100.0

func add_essence(amount: float):
	pity_essence += amount
	if pity_essence >= max_pity:
		trigger_pity_reward()

func trigger_pity_reward():
	pity_essence = 0
	print("Pity activated! Guaranteed new monster incoming.")
	# Logic for giving a new monster goes here

func add_monster(monster: MonsterData):
	owned_monsters.append(monster)
	print("Added " + monster.monster_name + " to collection.")
