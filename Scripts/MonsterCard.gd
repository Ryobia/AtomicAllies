# c:\Users\ryobi\Projects\nexus\Scripts\MonsterCard.gd
extends PanelContainer

# Call this function to update the UI with specific monster data
func set_monster(data: MonsterData):
	# We look for nodes named "TextureRect" and "Label" inside this card
	var icon_node = find_child("TextureRect", true, false)
	var name_node = find_child("Label", true, false)
	
	if icon_node:
		if data.texture:
			icon_node.texture = data.texture
			# Automatically adjust height to match the image's aspect ratio
			icon_node.custom_minimum_size = Vector2.ZERO # Reset any manual sizing
			icon_node.expand_mode = TextureRect.EXPAND_FIT_WIDTH
			icon_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	else:
		print("Warning: Could not find a node named 'TextureRect' in MonsterCard!")
	
	if name_node:
		name_node.text = data.monster_name
	else:
		print("Warning: Could not find a node named 'Label' in MonsterCard!")
