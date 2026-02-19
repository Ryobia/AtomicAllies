extends Resource
class_name MonsterData

@export var monster_name: String = "Unknown"
@export var atomic_number: int = 1
@export var group: AtomicConfig.Group = AtomicConfig.Group.NONMETAL
@export var level: int = 1
@export var icon: Texture2D
@export var moves: Array[MoveData] = []

# Dynamic Stat Calculation
# Call this whenever you need to display stats or start a battle
func get_current_stats() -> Dictionary:
	return AtomicConfig.calculate_stats(group, atomic_number, level)