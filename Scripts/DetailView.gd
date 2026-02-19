extends Control

# This variable will be set by your SceneManager before this scene is displayed.
var current_monster: MonsterData

# --- UI Node References ---
# You'll need to create these Labels and a Button in your DetailView scene.
@onready var name_label = $NameLabel
@onready var level_label = $LevelLabel
@onready var player_xp_label = $PlayerXpLabel
@onready var cost_label = $CostLabel
@onready var level_up_button = $LevelUpButton


func _ready():
	# This function is called when the scene loads.
	# We assume current_monster has been set by the previous screen.
	if is_instance_valid(current_monster):
		update_ui()
	
	# Connect the button's "pressed" signal to our level-up function.
	level_up_button.pressed.connect(_on_level_up_pressed)
	
	# Listen for global resource changes to keep the UI fresh.
	PlayerData.resource_updated.connect(_on_player_resource_updated)


func update_ui():
	# This function refreshes all the text on the screen.
	if not is_instance_valid(current_monster):
		return
		
	name_label.text = current_monster.monster_name
	level_label.text = "Level: " + str(current_monster.level)
	player_xp_label.text = "Player XP: " + str(PlayerData.resources.get("experience", 0))
	
	var cost = AtomicConfig.calculate_xp_requirement(current_monster.level)
	cost_label.text = "Cost: " + str(cost) + " XP"
	
	# Automatically disable the button if the player can't afford the upgrade.
	level_up_button.disabled = PlayerData.resources.get("experience", 0) < cost


func _on_level_up_pressed():
	var cost = AtomicConfig.calculate_xp_requirement(current_monster.level)
	
	# Use our new centralized spend_resource function.
	if PlayerData.spend_resource("experience", cost):
		current_monster.level += 1
		update_ui() # Refresh the screen to show the new level and cost.

func _on_player_resource_updated(resource_type: String, _new_amount: int):
	if resource_type == "experience":
		update_ui()