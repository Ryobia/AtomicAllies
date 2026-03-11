extends Resource
class_name MoveData

enum TargetType { ENEMY, SELF, ALLY }

@export var name: String = "Attack"
@export var power: int = 40
@export var accuracy: int = 100
@export var type: String = "Physical"
@export var is_snipe: bool = false
@export_multiline var description: String = ""
@export var target_type: TargetType = TargetType.ENEMY
@export var cooldown: int = 1
@export var hit_count: int = 1
@export var damage_scale: float = 1.0
# Data-driven effects (e.g. [{"type": "status", "status": "poison", "chance": 0.5}])
@export var effects: Array = []