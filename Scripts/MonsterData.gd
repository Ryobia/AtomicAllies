extends Resource
class_name MonsterData

# --- Core Info ---
@export var monster_name: String = "Unknown"
@export var atomic_number: int = 1 # The "Z" number (Replaces Tier)
@export var symbol: String = "H" # e.g. H, He, Li
@export var atomic_mass: float = 1.008
@export var level: int = 1 # Added for stability mechanic

# --- Chemical Classification ---
enum ChemicalGroup {
	NON_METAL,
	NOBLE_GAS,
	ALKALI_METAL,
	ALKALINE_EARTH,
	METALLOID,
	HALOGEN,
	TRANSITION_METAL,
	POST_TRANSITION,
	LANTHANIDE,
	ACTINIDE,
	UNKNOWN
}
@export var group: ChemicalGroup = ChemicalGroup.NON_METAL

# --- Visuals ---
@export var texture: Texture2D

# --- Base Stats (from our balance discussion) ---
# Calculated roughly as: Speed = 100/sqrt(mass), HP = mass * 10
@export var base_health: float = 100.0
@export var base_attack: float = 10.0
@export var base_defense: float = 5.0
@export var base_speed: float = 10.0