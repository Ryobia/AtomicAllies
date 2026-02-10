extends Control

func _ready():
    # Connect signals (Like onClick)
    $MarginContainer/VBoxContainer/BattleButton.pressed.connect(_on_battle_pressed)
    $MarginContainer/VBoxContainer/BreedingButton.pressed.connect(_on_breeding_pressed)
    print("SceneManager is online!")

func _on_battle_pressed():
    SceneManager.goto_scene("battle")

func _on_breeding_pressed():
    SceneManager.goto_scene("breeding")