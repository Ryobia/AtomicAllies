# c:\Users\ryobi\Projects\nexus\Scripts\Nexus.gd
extends Control

@export var monster_card_scene: PackedScene

# UI References (Make sure these match your Scene Tree!)
var parent_1_btn
var parent_2_btn
var breed_btn
var status_label

# Selection Panel References (A popup to pick monsters)
var selection_panel
var selection_container

var parent_1: MonsterData
var parent_2: MonsterData
var selecting_slot: int = 0 # Tracks if we are picking Parent 1 or Parent 2

func _ready():
	# Locate nodes dynamically to avoid path errors
	parent_1_btn = find_child("Parent1Button", true, false)
	parent_2_btn = find_child("Parent2Button", true, false)
	breed_btn = find_child("BreedButton", true, false)
	status_label = find_child("StatusLabel", true, false)
	
	selection_panel = find_child("SelectionPanel", true, false)
	if selection_panel:
		selection_container = selection_panel.find_child("GridContainer", true, false)
		if not selection_container:
			print("Nexus Error: Could not find 'GridContainer' inside SelectionPanel.")
		elif selection_container is GridContainer:
			# Force the grid to have multiple columns so cards sit side-by-side
			selection_container.columns = 4
			selection_container.add_theme_constant_override("h_separation", 10)
			selection_container.add_theme_constant_override("v_separation", 10)
			# Ensure the grid itself expands to fill the ScrollContainer width
			selection_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Connect UI signals
	if parent_1_btn: parent_1_btn.pressed.connect(func(): _open_selection(1))
	if parent_2_btn: parent_2_btn.pressed.connect(func(): _open_selection(2))
	if breed_btn: breed_btn.pressed.connect(_on_breed_pressed)
	
	# Connect Back Button
	var back_btn = find_child("BackButton", true, false)
	if back_btn:
		print("Nexus: Found BackButton. Moving to front.")
		back_btn.z_index = 10 # Force button to render on top of everything else
		back_btn.move_to_front() # Reorder node to be drawn last (on top)
		if not back_btn.pressed.is_connected(_on_back_button_pressed):
			back_btn.pressed.connect(_on_back_button_pressed)
	else:
		print("Nexus Error: Could not find node named 'BackButton'")
	
	# Hide selection panel initially
	if selection_panel:
		selection_panel.visible = false
	else:
		print("Nexus Warning: Could not find 'SelectionPanel'. If it is visible in the editor, it might be blocking clicks.")
	
	check_breeding_status()

func _process(_delta):
	# Update the timer label in real-time
	if TimeManager.get_time_left("breeding") > 0:
		var time_left = TimeManager.get_time_left("breeding")
		status_label.text = "Breeding... %ds remaining" % time_left
		breed_btn.disabled = true
	elif status_label.text.begins_with("Breeding..."):
		status_label.text = "Breeding Complete! Check Nursery."
		breed_btn.disabled = false

func check_breeding_status():
	if TimeManager.get_time_left("breeding") > 0:
		status_label.text = "Breeding in progress..."
		breed_btn.disabled = true
	else:
		status_label.text = "Select two monsters to breed."
		breed_btn.disabled = false

# --- Selection Logic ---
func _open_selection(slot: int):
	selecting_slot = slot
	if selection_panel:
		selection_panel.visible = true
		# Force the panel to the front so it catches mouse clicks
		selection_panel.z_index = 20
		selection_panel.move_to_front()
		_populate_selection_list()

func _populate_selection_list():
	if not selection_container:
		print("Error: Cannot populate list, selection_container is missing.")
		return

	# Clear previous list
	for child in selection_container.get_children():
		child.queue_free()
	
	var count = 0
	# Create a button for each monster in inventory
	for monster in PlayerData.owned_monsters:
		# Skip if this monster is already selected in the other slot
		if (selecting_slot == 1 and monster == parent_2) or (selecting_slot == 2 and monster == parent_1):
			continue
		
		if monster_card_scene:
			# Create a wrapper to hold the card and an invisible button
			var wrapper = PanelContainer.new()
			wrapper.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			selection_container.add_child(wrapper)
			
			var card = monster_card_scene.instantiate()
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.size_flags_vertical = Control.SIZE_EXPAND_FILL
			if card.has_method("set_monster"):
				card.set_monster(monster)
			wrapper.add_child(card)
			
			# Add an invisible button on top to handle the click
			var btn = Button.new()
			btn.flat = true
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
			btn.pressed.connect(func(): _on_monster_selected(monster))
			
			# Hover effects: Grow and Light Up
			btn.mouse_entered.connect(func():
				card.pivot_offset = card.size / 2 # Scale from the center
				wrapper.z_index = 1 # Bring to front so it overlaps neighbors nicely
				var tween = create_tween()
				tween.set_parallel(true)
				tween.tween_property(card, "scale", Vector2(1.05, 1.05), 0.1)
				tween.tween_property(card, "modulate", Color(1.1, 1.1, 1.1), 0.1)
			)
			btn.mouse_exited.connect(func():
				wrapper.z_index = 0
				var tween = create_tween()
				tween.set_parallel(true)
				tween.tween_property(card, "scale", Vector2.ONE, 0.1)
				tween.tween_property(card, "modulate", Color.WHITE, 0.1)
			)
			
			wrapper.add_child(btn)
		else:
			var btn = Button.new()
			btn.text = monster.monster_name + " (#" + str(monster.atomic_number) + ")"
			btn.custom_minimum_size = Vector2(200, 50)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.pressed.connect(func(): _on_monster_selected(monster))
			selection_container.add_child(btn)
			
		count += 1
	
	if count == 0:
		var lbl = Label.new()
		lbl.text = "No available monsters found."
		selection_container.add_child(lbl)
	
	# Add a Cancel button
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(func(): selection_panel.visible = false)
	selection_container.add_child(cancel_btn)

func _on_monster_selected(monster: MonsterData):
	if selecting_slot == 1:
		parent_1 = monster
		parent_1_btn.text = monster.monster_name
	elif selecting_slot == 2:
		parent_2 = monster
		parent_2_btn.text = monster.monster_name
	
	selection_panel.visible = false

# --- Breeding Logic ---
func _on_breed_pressed():
	if not parent_1 or not parent_2:
		status_label.text = "Please select two parents!"
		return
	
	if parent_1 == parent_2:
		status_label.text = "Cannot breed a monster with itself!"
		return
	
	# Nuclear Fusion Logic: Z1 + Z2 = Z_new
	var z1 = parent_1.atomic_number
	var z2 = parent_2.atomic_number
	var target_z = z1 + z2
	
	# Stability Check
	var stability = _calculate_stability(parent_1.level, parent_2.level, target_z)
	var roll = randf() * 100.0
	
	if roll > stability:
		status_label.text = "Fusion Failed! Instability detected. (Chance: %d%%)" % int(stability)
		PlayerData.add_resource("neutron_dust", 1)
		print("Fusion Failed. Gained Neutron Dust.")
		return
	
	var result_monster = _get_monster_by_atomic_number(target_z)
	
	if result_monster:
		# Success! Start the process
		PlayerData.pending_egg = result_monster
		
		# Start the timer (10 seconds for testing)
		TimeManager.start_timer("breeding", 10)
		
		status_label.text = "Fusion started! Creating Element #%d..." % target_z
		breed_btn.disabled = true
		
		print("Fusion Result: ", result_monster.monster_name, " (Z=", target_z, ")")
	else:
		status_label.text = "Fusion Failed: Element #%d is unstable or undiscovered." % target_z
		print("Fusion Failed: No monster found for Z=", target_z)

func _get_monster_by_atomic_number(z: int) -> MonsterData:
	# Simple lookup for the first 10 elements
	var element_names = [
		"Hydrogen", "Helium", "Lithium", "Beryllium", "Boron", 
		"Carbon", "Nitrogen", "Oxygen", "Fluorine", "Neon"
	]
	
	if z > 0 and z <= element_names.size():
		var file_name = element_names[z - 1]
		var path = "res://Data/Monsters/" + file_name + ".tres"
		if ResourceLoader.exists(path):
			return load(path)
	
	return null

func _calculate_stability(l1: int, l2: int, z: int) -> float:
	var base_chance = 40.0
	if z == 0: return 100.0
	# Formula: Base + (Combined Levels * Scaling / Target Z)
	# Higher levels increase stability. Higher Target Z makes it harder.
	var bonus = float(l1 + l2) * 5.0 / float(z)
	return clamp(base_chance + bonus, 0.0, 100.0)

func _on_back_button_pressed():
	GlobalManager.switch_scene("main_menu")