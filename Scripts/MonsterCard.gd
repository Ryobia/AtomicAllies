extends PanelContainer

@onready var icon_texture = $VBoxContainer/TextureRect
@onready var name_label = $VBoxContainer/Label

func setup(data: MonsterData):
	# This function receives the monster data and updates the UI
	if data.texture:
		icon_texture.texture = data.texture
	name_label.text = data.monster_name