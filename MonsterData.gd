extends Resource
class_name MonsterData

# --- Core Info ---
@export var monster_name: String = "Unknown"
@export var tier: int = 1 # 1, 2, or 3

# --- Elemental Types (from our design) ---
enum Types { FIRE, NATURE, WATER, LIGHT, DARK, MIND, NONE }
@export var type_1: Types = Types.FIRE
@export var type_2: Types = Types.NONE

# --- Visuals ---
@export var texture: Texture2D

# --- Base Stats (from our balance discussion) ---
@export var base_health: float = 100.0
@export var base_attack: float = 10.0
@export var base_defense: float = 5.0
@export var base_speed: float = 10.0