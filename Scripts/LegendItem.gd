# c:\Users\ryobi\Projects\nexus\Scripts\LegendItem.gd
extends PanelContainer

@onready var color_rect = $MarginContainer/HBoxContainer/ColorRect
@onready var title_label = $MarginContainer/HBoxContainer/VBoxContainer/TitleLabel
@onready var desc_label = $MarginContainer/HBoxContainer/VBoxContainer/DescLabel

func setup(group: int, description: String):
	# Set the color based on the Atomic Group
	var color = AtomicConfig.GROUP_COLORS.get(group, Color.WHITE)
	if color_rect:
		color_rect.color = color
	
	# Set the Title
	var group_name = AtomicConfig.Group.find_key(group).replace("_", " ").capitalize()
	if title_label:
		title_label.text = group_name
		title_label.add_theme_color_override("font_color", color)
		title_label.add_theme_color_override("font_outline_color", color.darkened(0.5))
	
	# Set the Description
	if desc_label:
		desc_label.text = description
