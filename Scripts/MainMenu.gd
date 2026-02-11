extends Control

@onready var collection_button = $MarginContainer/VBoxContainer/VFlowContainer/Collection

func _ready():
	collection_button.pressed.connect(_on_collection_button_pressed)

func _on_collection_button_pressed():
	GlobalManager.switch_scene("collection")