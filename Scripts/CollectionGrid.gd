extends Control

@onready var grid_container = $ScrollContainer/GridContainer
@onready var back_button = $BackButton

# Preload the card scene we will create next
const MONSTER_CARD = preload("res://Scenes/MonsterCard.tscn")

func _ready():
	back_button.pressed.connect(func(): GlobalManager.switch_scene("main_menu"))
	
	# Populate the grid from our global PlayerData
	for monster_data in PlayerData.owned_monsters:
		var card = MONSTER_CARD.instantiate()
		grid_container.add_child(card)
		card.setup(monster_data)