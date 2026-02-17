# c:\Users\ryobi\Projects\nexus\Scripts\MonsterCard.gd
extends PanelContainer

# Call this function to update the UI with specific monster data
func set_monster(data: MonsterData):
	if not data:
		return

	# We look for nodes named "TextureRect" and "Label" inside this card
	var icon_node = find_child("IconTexture", true, false)
	var name_node = find_child("NameLabel", true, false)
	var number_node = find_child("NumberLabel", true, false)
	
	if icon_node:
		# Clear any existing texture or children (atoms)
		icon_node.texture = null
		for child in icon_node.get_children():
			child.queue_free()
			
		# Instantiate Dynamic Atom
		var atom_script = load("res://Scripts/DynamicAtom.gd")
		var electron_tex = load("res://data/ElectronGlow.tres")
		
		if atom_script and electron_tex:
			var atom = Node2D.new()
			atom.set_script(atom_script)
			atom.atomic_number = data.atomic_number
			atom.electron_texture = electron_tex
			atom.rotation_speed = 15.0 # Slower spin for cards
			
			icon_node.add_child(atom)
			
			# Ensure the container gives space for the atom
			icon_node.custom_minimum_size = Vector2(0, 80)
			icon_node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		print("Warning: Could not find 'IconTexture' in MonsterCard!")
	
	if name_node:
		if PlayerData.is_monster_owned(data.monster_name):
			name_node.text = data.monster_name
		else:
			name_node.text = "???"
	else:
		print("Warning: Could not find 'NameLabel' in MonsterCard!")

	if number_node:
		number_node.text = "#%d" % data.atomic_number

func set_placeholder(z: int):
	var icon_node = find_child("IconTexture", true, false)
	var name_node = find_child("NameLabel", true, false)
	var number_node = find_child("NumberLabel", true, false)
	
	if icon_node:
		icon_node.texture = null
		for child in icon_node.get_children():
			child.queue_free()
	
	if name_node:
		name_node.text = "???"
		
	if number_node:
		number_node.text = "#%d" % z
