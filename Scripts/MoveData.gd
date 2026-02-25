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