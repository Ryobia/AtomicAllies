extends Resource
class_name MonsterData

@export var monster_name: String = "Unknown"
@export var tier: int = 1 # 1, 2, or 3
@export var is_pure: bool = true

enum Types { FIRE, NATURE, WATER, LIGHT, DARK, MIND, NONE }

@export var type_1: Types = Types.FIRE
@export var type_2: Types = Types.NONE # NONE if is_pure is true

@export var texture: Texture2D # This is where the sprite goes
@export var base_health: int = 100
@export var base_attack: int = 10
@export var base_defense: int = 5
@export var base_speed: int = 5
