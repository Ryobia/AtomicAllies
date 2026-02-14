extends Resource
class_name MonsterData

@export var monster_name: String = "Hydrogen"
@export var symbol: String = "H"
@export var atomic_number: int = 1
@export var atomic_mass: float = 1.008
@export var texture: Texture2D # The Nucleus sprite
@export var is_stable_isotope: bool = false # Shiny status

# --- Dynamic Stats (Unique Collection) ---
@export var level: int = 1
@export var current_xp: int = 0

# --- Derived Stats (The Physics Formula) ---

# Heavier atoms have more HP
var base_health: float:
	get: return (atomic_mass * 10.0) + (level * 5.0)

# Higher atomic number = more protons = more raw power
var base_attack: float:
	get: return ((atomic_number * 5.0) + 10.0) + (level * 2.0)

# Electron shielding provides defense
var base_defense: float:
	get: return (atomic_number * 2.0) + (level * 1.0)

# Heavier atoms are slower (Inertia)
var base_speed: float:
	get: return 100.0 / sqrt(atomic_mass)