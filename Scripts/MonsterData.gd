extends Resource
class_name MonsterData

@export var monster_name: String = "Hydrogen"
@export var symbol: String = "H"
@export var atomic_number: int = 1
@export var atomic_mass: float = 1.008
@export var group: int = 0
@export var texture: Texture2D # The Nucleus sprite
@export var is_stable_isotope: bool = false # Shiny status

# --- Dynamic Stats (Unique Collection) ---
@export var level: int = 1
@export var current_xp: int = 0

# --- Attunement Stats (Essence Infusion) ---
@export var infused_health: int = 0
@export var infused_attack: int = 0
@export var infused_defense: int = 0
@export var infused_speed: int = 0

# --- Moveset ---
@export var moves: Array[Resource] = []

# --- Derived Stats (The Physics Formula) ---

# Heavier atoms have more HP
var base_health: float:
	get: return (atomic_mass * 10.0) + (level * 5.0) + infused_health

# Higher atomic number = more protons = more raw power
var base_attack: float:
	get: return ((atomic_number * 5.0) + 10.0) + (level * 2.0) + infused_attack

# Electron shielding provides defense
var base_defense: float:
	get: return (atomic_number * 2.0) + (level * 1.0) + infused_defense

# Heavier atoms are slower (Inertia)
var base_speed: float:
	get: return (100.0 / sqrt(atomic_mass)) + infused_speed

# XP required to reach the next level (Linear scaling for MVP)
var xp_to_next_level: int:
	get: return level * 100