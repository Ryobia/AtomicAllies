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

# Visual References
var atom_p1: Node2D
var atom_p2: Node2D
var fusion_failure_popup

# Confirmation UI
var fusion_confirm_popup
var confirm_fuse_btn
var cancel_fuse_btn
var confirm_label
var popup_particles

# Stability UI
var stability_bar
var stability_label
var help_icon

func _ready():
	# Locate nodes dynamically to avoid path errors
	parent_1_btn = find_child("Parent1Button", true, false)
	parent_2_btn = find_child("Parent2Button", true, false)
	breed_btn = find_child("BreedButton", true, false)
	status_label = find_child("StatusLabel", true, false)
	
	fusion_confirm_popup = find_child("FusionConfirmPopup", true, false)
	if fusion_confirm_popup:
		fusion_confirm_popup.visible = false
		confirm_fuse_btn = fusion_confirm_popup.find_child("ConfirmButton", true, false)
		cancel_fuse_btn = fusion_confirm_popup.find_child("CancelButton", true, false)
		confirm_label = fusion_confirm_popup.find_child("Label", true, false)
		
		if confirm_fuse_btn:
			confirm_fuse_btn.pressed.connect(_on_confirm_fusion_pressed)
		if cancel_fuse_btn:
			cancel_fuse_btn.pressed.connect(func(): fusion_confirm_popup.visible = false)
			
		popup_particles = fusion_confirm_popup.find_child("PopupParticles", true, false)
	
	stability_bar = find_child("StabilityBar", true, false)
	if stability_bar:
		var bg_style = StyleBoxFlat.new()
		bg_style.bg_color = Color(0.1, 0.1, 0.1)
		bg_style.border_width_left = 4
		bg_style.border_width_top = 4
		bg_style.border_width_right = 4
		bg_style.border_width_bottom = 4
		bg_style.border_color = Color("#010813")
		stability_bar.add_theme_stylebox_override("background", bg_style)

	help_icon = find_child("HelpIcon", true, false)
	if help_icon:
		help_icon.tooltip_text = "Stability depends on Parent Levels.\nLevel up your monsters to increase success rate!"
		help_icon.theme = GlobalManager.tooltip_theme
		# Mobile support: Make icon clickable to show tooltip
		help_icon.mouse_filter = Control.MOUSE_FILTER_STOP
		if not help_icon.gui_input.is_connected(_on_help_icon_input):
			help_icon.gui_input.connect(_on_help_icon_input)

	stability_label = find_child("StabilityLabel", true, false)
	
	fusion_failure_popup = find_child("FusionFailurePopup", true, false)
	if fusion_failure_popup:
		fusion_failure_popup.visible = false
	
	selection_panel = find_child("SelectionPanel", true, false)
	if selection_panel:
		selection_container = selection_panel.find_child("GridContainer", true, false)
		if not selection_container:
			print("Nexus Error: Could not find 'GridContainer' inside SelectionPanel.")
		elif selection_container is GridContainer:
			# Force the grid to have multiple columns so cards sit side-by-side
			selection_container.columns = 3
			selection_container.add_theme_constant_override("h_separation", 10)
			selection_container.add_theme_constant_override("v_separation", 10)
			# Ensure the grid itself expands to fill the ScrollContainer width
			selection_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Connect UI signals
	if parent_1_btn: parent_1_btn.pressed.connect(func(): _open_selection(1))
	if parent_2_btn: parent_2_btn.pressed.connect(func(): _open_selection(2))
	if breed_btn: 
		# Disconnect any existing signals to ensure we use the right function
		if breed_btn.pressed.is_connected(_on_breed_pressed):
			breed_btn.pressed.disconnect(_on_breed_pressed)
		breed_btn.pressed.connect(_on_breed_pressed)
		
		breed_btn.z_index = 5 # Ensure it's above background but below popups (z=20+)
		breed_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		print("Nexus: BreedButton setup complete. Path: ", breed_btn.get_path())
	
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
	
	# Connect Cheat Sheet
	var cheat_sheet = find_child("FusionCheatSheet", true, false)
	var cheat_btn = find_child("CheatSheetButton", true, false)
	
	if cheat_sheet:
		cheat_sheet.visible = false # Hide by default
		
	if cheat_btn and cheat_sheet:
		cheat_btn.z_index = 10 # Ensure button is always clickable
		cheat_btn.pressed.connect(func(): 
			cheat_sheet.visible = true
			cheat_sheet.move_to_front()
		)
	
	# Hide selection panel initially
	if selection_panel:
		selection_panel.visible = false
	else:
		print("Nexus Warning: Could not find 'SelectionPanel'. If it is visible in the editor, it might be blocking clicks.")
	
	if not SynthesisManager.fusion_completed.is_connected(_on_fusion_completed):
		SynthesisManager.fusion_completed.connect(_on_fusion_completed)
	
	check_breeding_status()
	
	# DEBUG: If we have no monsters, give us the starters so we can test!
	if PlayerData.owned_monsters.is_empty():
		_debug_add_starters()

			# Connect the error signal
	if not SynthesisManager.fusion_error.is_connected(_on_fusion_error):
		SynthesisManager.fusion_error.connect(_on_fusion_error)

	if not SynthesisManager.capsule_created.is_connected(_on_capsule_created):
		SynthesisManager.capsule_created.connect(_on_capsule_created)

func _on_fusion_error(message: String):
	var popup = find_child("ErrorPopup", true, false)
	if popup:
		popup.dialog_text = message
		popup.popup_centered()
	else:
		print("Fusion Error: ", message)

func _on_capsule_created(capsule_data):
	# Reset Data
	parent_1 = null
	parent_2 = null
	
	# Reset UI
	if parent_1_btn: parent_1_btn.text = "Select Parent 1"
	if parent_2_btn: parent_2_btn.text = "Select Parent 2"
	
	if status_label:
		status_label.text = "Fusion Successful! Capsule created!"
	
	# Clear Visuals
	if is_instance_valid(atom_p1): atom_p1.queue_free()
	if is_instance_valid(atom_p2): atom_p2.queue_free()
	atom_p1 = null
	atom_p2 = null
	
	_update_stability_preview()

func _process(_delta):
	# Update the timer label in real-time
	if TimeManager.get_time_left("breeding") > 0:
		var time_left = TimeManager.get_time_left("breeding")
		status_label.text = "Fusion in progress...%ds remaining" % time_left
		if breed_btn and not breed_btn.disabled:
			breed_btn.disabled = true
			print("Nexus: BreedButton disabled by active timer.")
	elif status_label.text.begins_with("Fusion in progress..."):
		status_label.text = "Fusion Complete! Check Synthesis Chamber!"
		if breed_btn: breed_btn.disabled = false

func check_breeding_status():
	if TimeManager.get_time_left("breeding") > 0:
		status_label.text = "Fusion in progress..."
		breed_btn.disabled = true
	else:
		status_label.text = "Select two Elements to Fuse."
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

	print("Nexus: Populating selection list...")

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
			print("Nexus: Using Monster Card Scene")
			# Create a wrapper to hold the card and an invisible button
			var wrapper = PanelContainer.new()
			wrapper.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			wrapper.custom_minimum_size = Vector2(0, 250)
			selection_container.add_child(wrapper)
			
			var card = monster_card_scene.instantiate()
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_apply_font_override(card, 40) # Force larger font on all labels inside the card
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
			print("Nexus: Using Default Buttons")
			var btn = Button.new()
			btn.text = monster.monster_name + " (#" + str(monster.atomic_number) + ")"
			btn.custom_minimum_size = Vector2(200, 250)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.add_theme_font_size_override("font_size", 56)
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
	cancel_btn.custom_minimum_size = Vector2(200, 250)
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.add_theme_font_size_override("font_size", 56)
	cancel_btn.pressed.connect(func(): selection_panel.visible = false)
	selection_container.add_child(cancel_btn)

func _on_monster_selected(monster: MonsterData):
	if selecting_slot == 1:
		parent_1 = monster
		parent_1_btn.text = monster.monster_name
		_update_slot_visuals(1, monster)
	elif selecting_slot == 2:
		parent_2 = monster
		parent_2_btn.text = monster.monster_name
		_update_slot_visuals(2, monster)
	
	selection_panel.visible = false
	_update_stability_preview()

# --- Breeding Logic ---
func _on_breed_pressed():
	print("Nexus: Breed Button Clicked!")
	_animate_button_press(breed_btn)
	
	if not parent_1 or not parent_2:
		status_label.text = "Please select two parents!"
		return
	
	if parent_1 == parent_2:
		status_label.text = "Cannot breed a monster with itself!"
		return
		
	# Show confirmation popup instead of immediate fusion
	if fusion_confirm_popup:
		var target_z = parent_1.atomic_number + parent_2.atomic_number
		var chance = 0.0
		if SynthesisManager.has_method("calculate_stability"):
			chance = SynthesisManager.calculate_stability(parent_1.level, parent_2.level, target_z)
			
		if confirm_label:
			confirm_label.text = "Fuse %s and %s?\nTarget Z: %d\nStability: %d%%" % [parent_1.monster_name, parent_2.monster_name, target_z, int(chance)]
			
		fusion_confirm_popup.visible = true
		fusion_confirm_popup.move_to_front()
		
		if popup_particles:
			popup_particles.restart()
			popup_particles.emitting = true
	else:
		# Fallback if no popup exists
		SynthesisManager.attempt_fusion(parent_1, parent_2)

func _on_confirm_fusion_pressed():
	if fusion_confirm_popup:
		fusion_confirm_popup.visible = false
	SynthesisManager.attempt_fusion(parent_1, parent_2)

func _on_fusion_completed(target_z: int, success: bool, reward: int):
	if success:
		var result_monster = _get_monster_by_atomic_number(target_z)
		if result_monster:
			# Success! Start the process
			PlayerData.pending_egg = result_monster
			
			# Start the timer (10 seconds for testing)
			TimeManager.start_timer("breeding", 10)
			
			status_label.text = "Fusion started! Creating Element #%d..." % target_z
			breed_btn.disabled = true
	else:
		if fusion_failure_popup:
			fusion_failure_popup.setup(reward)
		else:
			status_label.text = "Fusion Failed! Instability detected.\nRecovered %d Neutron Dust." % reward

func _get_monster_by_atomic_number(z: int) -> MonsterData:
	# Use the global lookup in PlayerData to support all implemented elements (up to Iron)
	var path = PlayerData.get_monster_path_by_z(z)
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	
	return null

func _on_back_button_pressed():
	GlobalManager.switch_scene("main_menu")

func _update_slot_visuals(slot_idx: int, monster: MonsterData):
	# Try to find the slot container or icon directly
	# We look for "Parent1Slot" or "Parent1Icon" to be flexible
	var prefix = "Parent1" if slot_idx == 1 else "Parent2"
	
	# 1. Try to find a container named ParentXSlot
	var slot_node = find_child(prefix + "Slot", true, false)
	var icon_rect = null
	
	if slot_node:
		# Force the slot container itself to expand so it fills the screen area
		if slot_node is Control:
			slot_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot_node.size_flags_vertical = Control.SIZE_EXPAND_FILL
			
		icon_rect = slot_node.find_child("IconTexture" + str(slot_idx), true, false)
		if not icon_rect:
			icon_rect = slot_node.find_child("IconTexture", true, false)
	else:
		# 2. Fallback: Look for IconTextureX directly
		icon_rect = find_child("IconTexture" + str(slot_idx), true, false)
		if not icon_rect:
			icon_rect = find_child(prefix + "Icon", true, false)
	
	if not icon_rect:
		print("Nexus Warning: Could not find IconTexture for ", prefix)
		return
		
	# Force the container to expand to fill its parent
	icon_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Ensure TextureRect allows resizing even without a texture
	if icon_rect is TextureRect:
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# Cleanup previous atom
	if slot_idx == 1 and is_instance_valid(atom_p1): atom_p1.queue_free()
	if slot_idx == 2 and is_instance_valid(atom_p2): atom_p2.queue_free()

	if monster:
		var atom = _create_atom(monster)
		if atom:
			icon_rect.add_child(atom)
			atom.position = icon_rect.size / 2.0
			if slot_idx == 1: atom_p1 = atom
			else: atom_p2 = atom

func _update_stability_preview():
	if parent_1 and parent_2:
		var target_z = parent_1.atomic_number + parent_2.atomic_number
		var chance = 0.0
		
		if SynthesisManager.has_method("calculate_stability"):
			chance = SynthesisManager.calculate_stability(parent_1.level, parent_2.level, target_z)
		
		if stability_bar:
			stability_bar.value = chance
			_update_bar_color(chance)
			
		if stability_label:
			stability_label.text = "Stability: %d%%" % int(chance)
	else:
		if stability_bar: stability_bar.value = 0
		if stability_label: stability_label.text = "Stability: --"

func _update_bar_color(chance: float):
	if not stability_bar: return
	
	var style = stability_bar.get_theme_stylebox("fill")
	if not style is StyleBoxFlat or not stability_bar.has_meta("custom_style"):
		style = StyleBoxFlat.new()
		stability_bar.add_theme_stylebox_override("fill", style)
		stability_bar.set_meta("custom_style", true)
	
	# Reset any active pulse
	if stability_bar.has_meta("pulse_tween"):
		var t = stability_bar.get_meta("pulse_tween")
		if t and t.is_valid():
			t.kill()
	
	var base_color
	var flash_color
	
	if chance >= 80.0: 
		base_color = Color("#60fafc") # Cyan (Safe)
		flash_color = Color("#ccffff") # Pale Cyan
	elif chance >= 50.0: 
		base_color = Color("#ffd700") # Gold (Risky)
		flash_color = Color("#fff5cc") # Pale Gold
	else: 
		base_color = Color("#ff4d4d") # Red (Unstable)
		flash_color = Color("#ffcccc") # Pale Red
	
	style.bg_color = base_color
	_start_pulse(stability_bar, style, base_color, flash_color, chance)

func _start_pulse(bar: ProgressBar, style: StyleBoxFlat, base_color: Color, flash_color: Color, chance: float):
	var tween = create_tween()
	tween.set_loops()
	
	# Slower pulse: 0.8s (at 0%) to 4.0s (at 100%)
	var duration = 0.8 + (chance / 100.0) * 3.2
	
	# Subtle pulse at high stability: Blend flash color closer to base color
	# At 100%, intensity is ~0.17 (very subtle). At 0%, intensity is 1.0 (full flash).
	var intensity = 1.0 - (chance / 120.0)
	var target_flash = base_color.lerp(flash_color, intensity)
	
	tween.tween_property(style, "bg_color", target_flash, duration * 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(style, "bg_color", base_color, duration * 0.5).set_trans(Tween.TRANS_SINE)
	
	bar.set_meta("pulse_tween", tween)

func _animate_button_press(btn: Control):
	if not btn: return
	btn.pivot_offset = btn.size / 2
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(0.95, 0.95), 0.1)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.1)

func _create_atom(monster: MonsterData) -> Node2D:
	var atom_script = load("res://Scripts/DynamicAtom.gd")
	var electron_tex = load("res://data/ElectronGlow.tres")
	
	if not atom_script or not electron_tex:
		return null
		
	var atom = Node2D.new()
	atom.set_script(atom_script)
	atom.atomic_number = monster.atomic_number
	atom.electron_texture = electron_tex
	atom.rotation_speed = 20.0
	return atom

func _debug_add_starters():
	print("DEBUG: Inventory empty. Adding starter atoms (H, H, He)...")
	var h = _get_monster_by_atomic_number(1) # Hydrogen
	var he = _get_monster_by_atomic_number(2) # Helium
	
	if h: 
		PlayerData.owned_monsters.append(h)
		PlayerData.owned_monsters.append(h) # Need 2 to make Helium
	if he:
		PlayerData.owned_monsters.append(he)
	
	print("DEBUG: Starters added. You can now test breeding.")

func _on_help_icon_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_tooltip_popup(help_icon.tooltip_text)

func _show_tooltip_popup(text: String):
	var popup = find_child("InfoPopup", true, false)
	if not popup:
		popup = AcceptDialog.new()
		popup.name = "InfoPopup"
		add_child(popup)
		
		var theme = Theme.new()
		
		# Background
		var bg = StyleBoxFlat.new()
		bg.bg_color = Color("#010813")
		bg.border_width_left = 2
		bg.border_width_top = 2
		bg.border_width_right = 2
		bg.border_width_bottom = 2
		bg.border_color = Color("#60fafc")
		bg.content_margin_left = 20
		bg.content_margin_right = 20
		bg.content_margin_top = 20
		bg.content_margin_bottom = 20
		theme.set_stylebox("panel", "Window", bg)
		
		# Text
		theme.set_color("font_color", "Label", Color("#60fafc"))
		theme.set_font_size("font_size", "Label", 32)
		
		# Button
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color("#60fafc")
		btn_style.content_margin_left = 30
		btn_style.content_margin_right = 30
		btn_style.content_margin_top = 10
		btn_style.content_margin_bottom = 10
		
		theme.set_stylebox("normal", "Button", btn_style)
		theme.set_stylebox("hover", "Button", btn_style)
		theme.set_stylebox("pressed", "Button", btn_style)
		theme.set_color("font_color", "Button", Color("#010813"))
		theme.set_font_size("font_size", "Button", 28)
		
		popup.theme = theme
	
	popup.dialog_text = text
	popup.popup_centered()

func _apply_font_override(node: Node, size: int):
	if node is Label or node is Button or node is RichTextLabel:
		node.add_theme_font_size_override("font_size", size)
	
	for child in node.get_children():
		_apply_font_override(child, size)
