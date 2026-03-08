extends Control

@onready var close_btn = find_child("CloseButton", true, false)

func _ready():
    if close_btn:
        close_btn.pressed.connect(func(): visible = false)
