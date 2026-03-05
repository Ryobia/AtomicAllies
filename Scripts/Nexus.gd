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
var stabilizer_checkbox: CheckBox
var buy_stabilizer_btn: Button
var catalyst_checkbox: CheckBox
var buy_catalyst_btn: Button

# Stability UI
var stability_bar
var stability_label
var help_icon

enum SortMode { ATOMIC_NUMBER, NAME, STABILITY }
var current_sort_mode: SortMode = SortMode.ATOMIC_NUMBER
var sort_btn: Button
var search_bar: LineEdit
var search_text: String = ""

func _ready():
	# Locate nodes dynamically to avoid path errors
	parent_1_btn = find_child("Parent1Button", true, false)
	parent_2_btn = find_child("Parent2Button", true, false)
	breed_btn = find_child("BreedButton", true, false)
	status_label = find_child("StatusLabel", true, false)
	
	fusion_confirm_popup = find_child("FusionConfirmPopup", true, false)
	if fusion_confirm_popup:
		fusion_confirm_popup.visible = false
		# Force reset size to prevent it from getting stuck at a huge height due to previous bugs
		fusion_confirm_popup.custom_minimum_size = Vector2(600, 0)
		fusion_confirm_popup.size = Vector2(600, 0)
		
		confirm_fuse_btn = fusion_confirm_popup.find_child("ConfirmButton", true, false)
		cancel_fuse_btn = fusion_confirm_popup.find_child("CancelButton", true, false)
		confirm_label = fusion_confirm_popup.find_child("Label", true, false)
		
		if confirm_fuse_btn:
			confirm_fuse_btn.pressed.connect(_on_confirm_fusion_pressed)
		if cancel_fuse_btn:
			cancel_fuse_btn.pressed.connect(func(): fusion_confirm_popup.visible = false)
			
		# Find the checkbox added in the editor
		stabilizer_checkbox = fusion_confirm_popup.find_child("StabilizerCheckBox", true, false)
		
		if stabilizer_checkbox:
			var container = stabilizer_checkbox.get_parent()
			
			# Setup Styles (Shared)
			var sb_normal = StyleBoxFlat.new()
			sb_normal.bg_color = Color(0, 0, 0, 0.5)
			sb_normal.border_color = Color("#60fafc")
			sb_normal.border_width_left = 2
			sb_normal.border_width_top = 2
			sb_normal.border_width_right = 2
			sb_normal.border_width_bottom = 2
			sb_normal.set_corner_radius_all(8)
			sb_normal.content_margin_left = 20
			sb_normal.content_margin_right = 20
			
			var sb_hover = sb_normal.duplicate()
			sb_hover.bg_color = Color("#60fafc")
			sb_hover.bg_color.a = 0.2
			
			# Get siblings directly (No creation logic needed as they are in the scene)
			catalyst_checkbox = container.get_node_or_null("CatalystCheckBox")
			buy_stabilizer_btn = container.get_node_or_null("BuyStabilizerButton")
			buy_catalyst_btn = container.get_node_or_null("BuyCatalystButton")
			
			# CLEANUP: Remove any duplicates that might have accumulated from previous bugs
			var children = container.get_children()
			for child in children:
				if child == stabilizer_checkbox or child == catalyst_checkbox or child == buy_stabilizer_btn or child == buy_catalyst_btn:
					continue
				
				if child.name.begins_with("StabilizerCheckBox") or \
				   child.name.begins_with("CatalystCheckBox") or \
				   child.name.begins_with("BuyStabilizerButton") or \
				   child.name.begins_with("BuyCatalystButton") or \
				   (child is Button and child.text.begins_with("Buy")):
					print("Nexus: Removing duplicate node ", child.name)
					child.queue_free()
			
			# Setup UI Properties
			_setup_booster_ui(stabilizer_checkbox, buy_stabilizer_btn, "Use Magnetic Stabilizer (+10%)", "Buy Stabilizer (250 Dust)", sb_normal, sb_hover)
			_setup_booster_ui(catalyst_checkbox, buy_catalyst_btn, "Use Quantum Catalyst (+25%)", "Buy Catalyst (500 Dust)", sb_normal, sb_hover)
			
			# Connect Signals
			if not stabilizer_checkbox.toggled.is_connected(_on_stabilizer_toggled):
				stabilizer_checkbox.toggled.connect(_on_stabilizer_toggled)
			if buy_stabilizer_btn and not buy_stabilizer_btn.pressed.is_connected(_on_buy_stabilizer_pressed):
				buy_stabilizer_btn.pressed.connect(_on_buy_stabilizer_pressed)
			if catalyst_checkbox and not catalyst_checkbox.toggled.is_connected(_on_catalyst_toggled):
				catalyst_checkbox.toggled.connect(_on_catalyst_toggled)
			if buy_catalyst_btn and not buy_catalyst_btn.pressed.is_connected(_on_buy_catalyst_pressed):
				buy_catalyst_btn.pressed.connect(_on_buy_catalyst_pressed)
			
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
		help_icon.tooltip_text = "Success depends on Parent Stability.\nFusions with high stability parents are more likely to succeed."
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
			selection_container.mouse_filter = Control.MOUSE_FILTER_PASS
			
		# Add Filter Row (Search + Sort)
		var filter_row = HBoxContainer.new()
		filter_row.layout_mode = 1 # Anchors
		filter_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
		filter_row.offset_left = 20
		filter_row.offset_right = -20
		filter_row.offset_top = 20
		filter_row.offset_bottom = 80
		filter_row.add_theme_constant_override("separation", 20)
		selection_panel.add_child(filter_row)
		
		search_bar = LineEdit.new()
		search_bar.placeholder_text = "Search..."
		search_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		search_bar.add_theme_font_size_override("font_size", 32)
		search_bar.text_changed.connect(_on_search_text_changed)
		filter_row.add_child(search_bar)

		# Add Sort Button programmatically if not present, or move it if it is
		sort_btn = selection_panel.find_child("SortButton", true, false)
		if not sort_btn:
			sort_btn = Button.new()
			sort_btn.name = "SortButton"
			sort_btn.text = "Sort: Atomic #"
			sort_btn.add_theme_font_size_override("font_size", 32)
		elif sort_btn.get_parent():
			sort_btn.get_parent().remove_child(sort_btn)
		
		filter_row.add_child(sort_btn)
		sort_btn.pressed.connect(_on_sort_pressed)
		
		# Adjust ScrollContainer to sit below the filter row
		if selection_container:
			var scroll = selection_container.get_parent()
			if scroll is ScrollContainer:
				scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
				scroll.offset_top = 100 # Push down below header
	
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

	# Trigger tutorial check
	if TutorialManager:
		TutorialManager.check_tutorial_progress()

func _on_sort_pressed():
	if current_sort_mode == SortMode.ATOMIC_NUMBER: current_sort_mode = SortMode.NAME
	elif current_sort_mode == SortMode.NAME: current_sort_mode = SortMode.STABILITY
	else: current_sort_mode = SortMode.ATOMIC_NUMBER
		
	match current_sort_mode:
		SortMode.ATOMIC_NUMBER: sort_btn.text = "Sort: Atomic #"
		SortMode.NAME: sort_btn.text = "Sort: Name"
		SortMode.STABILITY: sort_btn.text = "Sort: Stability"
	_populate_selection_list()

func _on_search_text_changed(new_text: String):
	search_text = new_text
	_populate_selection_list()

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
		status_label.text = "Fusion Successful! Sent to Synthesis Chamber."
	
	# Clear Visuals
	if is_instance_valid(atom_p1): atom_p1.queue_free()
	if is_instance_valid(atom_p2): atom_p2.queue_free()
	atom_p1 = null
	atom_p2 = null
	
	check_breeding_status()
	_update_success_rate_preview()

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
	elif PlayerData.get_first_empty_chamber_index() == -1:
		status_label.text = "No Synthesis Chambers available!"
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
		# Reset search
		if search_bar:
			search_bar.text = ""
			search_text = ""
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
	
	var sorted_list = PlayerData.owned_monsters.duplicate()
	
	if search_text != "":
		sorted_list = sorted_list.filter(func(m): return search_text.to_lower() in m.monster_name.to_lower())
	
	sorted_list.sort_custom(func(a, b):
		match current_sort_mode:
			SortMode.NAME: return a.monster_name < b.monster_name
			SortMode.STABILITY: return a.stability > b.stability
			_: return a.atomic_number < b.atomic_number
	)
	
	# Create a button for each monster in inventory
	for monster in sorted_list:
		# Skip if this monster is already selected in the other slot
		if (selecting_slot == 1 and monster == parent_2) or (selecting_slot == 2 and monster == parent_1):
			continue
			
		var current_time = int(Time.get_unix_time_from_system())
		var is_fatigued = monster.fatigue_expiry > current_time
		
		if monster_card_scene:
			print("Nexus: Using Monster Card Scene")
			# Create a wrapper to hold the card and an invisible button
			var wrapper = PanelContainer.new()
			wrapper.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			wrapper.custom_minimum_size = Vector2(0, 250)
			wrapper.mouse_filter = Control.MOUSE_FILTER_PASS
			selection_container.add_child(wrapper)
			
			var card = monster_card_scene.instantiate()
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_apply_font_override(card, 40) # Force larger font on all labels inside the card
			if card.has_method("set_monster"):
				card.set_monster(monster)
			wrapper.add_child(card)
			
			# Add gold border for 100% stability
			if monster.stability >= 100:
				var panel_style = card.get_theme_stylebox("panel", "PanelContainer")
				if panel_style:
					var mastery_style = panel_style.duplicate()
					mastery_style.border_width_left = 4
					mastery_style.border_width_top = 4
					mastery_style.border_width_right = 4
					mastery_style.border_width_bottom = 4
					mastery_style.border_color = Color("#ffd700") # Gold
					card.add_theme_stylebox_override("panel", mastery_style)
			
			# Add an invisible button on top to handle the click
			var btn = Button.new()
			btn.flat = true
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
			btn.mouse_filter = Control.MOUSE_FILTER_PASS
			btn.focus_mode = Control.FOCUS_NONE
			
			if is_fatigued:
				card.modulate = Color(0.5, 0.5, 0.5, 0.8)
				var time_left = monster.fatigue_expiry - current_time
				var mins = time_left / 60
				var secs = time_left % 60
				
				var lbl = Label.new()
				lbl.text = "Fatigued\n%02d:%02d" % [mins, secs]
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				lbl.add_theme_color_override("font_color", Color("#ff4d4d"))
				lbl.add_theme_font_size_override("font_size", 32)
				lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
				wrapper.add_child(lbl)
				
				btn.disabled = true
				btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
				
				var coolant_count = PlayerData.get_item_count("coolant_gel")
				if coolant_count > 0:
					var cool_btn = Button.new()
					cool_btn.text = "Use Coolant (%d)" % coolant_count
					cool_btn.add_theme_font_size_override("font_size", 24)
					
					var c_style = StyleBoxFlat.new()
					c_style.bg_color = Color("#60fafc")
					c_style.set_corner_radius_all(4)
					cool_btn.add_theme_stylebox_override("normal", c_style)
					cool_btn.add_theme_stylebox_override("hover", c_style)
					cool_btn.add_theme_stylebox_override("pressed", c_style)
					cool_btn.add_theme_color_override("font_color", Color("#010813"))
					cool_btn.size_flags_vertical = Control.SIZE_SHRINK_END
					cool_btn.custom_minimum_size = Vector2(0, 50)
					cool_btn.pressed.connect(func(): _on_use_coolant(monster))
					wrapper.add_child(cool_btn)
			else:
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
			btn.add_theme_constant_override("outline_size", 8)
			btn.add_theme_color_override("font_outline_color", Color.BLACK)
			btn.mouse_filter = Control.MOUSE_FILTER_PASS
			btn.focus_mode = Control.FOCUS_NONE
			
			if is_fatigued:
				var time_left = monster.fatigue_expiry - current_time
				var mins = time_left / 60
				var secs = time_left % 60
				btn.text += "\n(Fatigued %02d:%02d)" % [mins, secs]
				btn.disabled = true
				
				var coolant_count = PlayerData.get_item_count("coolant_gel")
				if coolant_count > 0:
					btn.text = "Use Coolant (%d)" % coolant_count
					btn.disabled = false
					btn.pressed.connect(func(): _on_use_coolant(monster))
			else:
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

func _on_use_coolant(monster: MonsterData):
	if PlayerData.consume_item("coolant_gel", 1):
		monster.fatigue_expiry = 0
		PlayerData.save_game()
		_populate_selection_list()

func _on_monster_selected(monster: MonsterData):
	if selecting_slot == 1:
		parent_1 = monster
		parent_1_btn.text = monster.monster_name
		_update_slot_visuals(1, monster)
	elif selecting_slot == 2:
		parent_2 = monster
		parent_2_btn.text = monster.monster_name
		_update_slot_visuals(2, monster)
		
		# Tutorial: Advance if P2 selected
		if TutorialManager and PlayerData.tutorial_step == TutorialManager.Step.SELECT_PARENT_2:
			TutorialManager.advance_step()
	
	# Tutorial: Advance if P1 selected
	if selecting_slot == 1 and TutorialManager and PlayerData.tutorial_step == TutorialManager.Step.SELECT_PARENT_1:
		TutorialManager.advance_step()
	
	selection_panel.visible = false
	_update_success_rate_preview()

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
	
	var target_z = parent_1.atomic_number + parent_2.atomic_number
	var cost = AtomicConfig.calculate_fusion_cost(target_z)
	
	if PlayerData.resources.get("binding_energy", 0) < cost:
		status_label.text = "Not enough Binding Energy! Need %d." % cost
		return
		
	# Show confirmation popup instead of immediate fusion
	if fusion_confirm_popup:
		var chance = 0.0
		if SynthesisManager.has_method("calculate_success_rate"):
			chance = SynthesisManager.calculate_success_rate(parent_1.stability, parent_2.stability, target_z)
			
		# Reset checkboxes state based on inventory
		if stabilizer_checkbox:
			stabilizer_checkbox.button_pressed = false
		if catalyst_checkbox:
			catalyst_checkbox.button_pressed = false
			
		_refresh_boosters_ui()
			
		if confirm_label:
			_update_confirm_label(chance, cost, target_z)
			
		fusion_confirm_popup.visible = true
		fusion_confirm_popup.move_to_front()
		
		if popup_particles:
			popup_particles.restart()
			popup_particles.emitting = true
	else:
		# Fallback if no popup exists
		SynthesisManager.attempt_fusion(parent_1, parent_2)

func _refresh_boosters_ui():
	# Stabilizer
	if stabilizer_checkbox and buy_stabilizer_btn:
		var count = PlayerData.get_item_count("magnetic_stabilizer")
		if count > 0:
			stabilizer_checkbox.visible = true
			buy_stabilizer_btn.visible = false
			stabilizer_checkbox.text = "Use Magnetic Stabilizer (+10%%) [%d Owned]" % count
		else:
			stabilizer_checkbox.visible = false
			buy_stabilizer_btn.visible = true
			buy_stabilizer_btn.text = "Buy Stabilizer (250 Dust)"
			
	# Catalyst
	if catalyst_checkbox and buy_catalyst_btn:
		var count = PlayerData.get_item_count("quantum_catalyst")
		if count > 0:
			catalyst_checkbox.visible = true
			buy_catalyst_btn.visible = false
			catalyst_checkbox.text = "Use Quantum Catalyst (+25%%) [%d Owned]" % count
		else:
			catalyst_checkbox.visible = false
			buy_catalyst_btn.visible = true
			buy_catalyst_btn.text = "Buy Catalyst (500 Dust)"

func _on_buy_stabilizer_pressed():
	var cost = 250
	_handle_buy_booster("magnetic_stabilizer", cost, buy_stabilizer_btn, stabilizer_checkbox, "Buy Stabilizer (250 Dust)")

func _on_buy_catalyst_pressed():
	var cost = 500
	_handle_buy_booster("quantum_catalyst", cost, buy_catalyst_btn, catalyst_checkbox, "Buy Catalyst (500 Dust)")

func _handle_buy_booster(item_id: String, cost: int, btn: Button, checkbox: CheckBox, default_text: String):
	if PlayerData.spend_resource("neutron_dust", cost):
		PlayerData.add_item(item_id, 1)
		_refresh_boosters_ui()
		# Auto-select for convenience
		if checkbox:
			checkbox.button_pressed = true
	else:
		btn.text = "Not enough Dust!"
		var tween = create_tween()
		tween.tween_interval(1.0)
		tween.tween_callback(func(): if btn: btn.text = default_text)

func _on_stabilizer_toggled(_pressed: bool):
	_update_chance_display()

func _on_catalyst_toggled(_pressed: bool):
	_update_chance_display()

func _update_chance_display():
	if not parent_1 or not parent_2: return
	var target_z = parent_1.atomic_number + parent_2.atomic_number
	var cost = AtomicConfig.calculate_fusion_cost(target_z)
	var chance = 0.0
	if SynthesisManager.has_method("calculate_success_rate"):
		chance = SynthesisManager.calculate_success_rate(parent_1.stability, parent_2.stability, target_z)
	
	_update_confirm_label(chance, cost, target_z)
	
	# Animate the stability bar to reflect the boosted chance
	var final_chance = chance
	if stabilizer_checkbox and stabilizer_checkbox.button_pressed:
		final_chance += 10.0
	if catalyst_checkbox and catalyst_checkbox.button_pressed:
		final_chance += 25.0
		
	if stability_bar:
		if stability_bar.has_meta("anim_tween"):
			var t = stability_bar.get_meta("anim_tween")
			if t and t.is_valid(): t.kill()
		var tween = create_tween()
		tween.tween_property(stability_bar, "value", final_chance, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		stability_bar.set_meta("anim_tween", tween)
		_update_bar_color(final_chance)

	if stability_label:
		stability_label.text = "Chance of Success: %d%%" % int(final_chance)

func _update_confirm_label(base_chance: float, cost: int, target_z: int):
	var final_chance = base_chance
	if stabilizer_checkbox and stabilizer_checkbox.button_pressed:
		final_chance += 10.0
	if catalyst_checkbox and catalyst_checkbox.button_pressed:
		final_chance += 25.0
	
	confirm_label.text = "Fuse %s and %s?\nTarget Z: %d\nSuccess Rate: %d%%\nCost: %d Binding Energy" % \
		[parent_1.monster_name, parent_2.monster_name, target_z, int(final_chance), cost]

func _on_confirm_fusion_pressed():
	if fusion_confirm_popup:
		fusion_confirm_popup.visible = false
	
	var target_z = parent_1.atomic_number + parent_2.atomic_number
	var cost = AtomicConfig.calculate_fusion_cost(target_z)
	
	if PlayerData.spend_resource("binding_energy", cost):
		# Consume boosters if checked
		var bonus = 0
		if stabilizer_checkbox and stabilizer_checkbox.button_pressed:
			if PlayerData.consume_item("magnetic_stabilizer", 1):
				bonus += 10
		if catalyst_checkbox and catalyst_checkbox.button_pressed:
			if PlayerData.consume_item("quantum_catalyst", 1):
				bonus += 25
		
		# Pass bonus to SynthesisManager if it supports it
		if SynthesisManager.has_method("attempt_fusion_with_bonus"):
			SynthesisManager.attempt_fusion_with_bonus(parent_1, parent_2, bonus)
		else:
			# Fallback to standard (Bonus item consumed but effect depends on Manager implementation)
			SynthesisManager.attempt_fusion(parent_1, parent_2)
			
		# Tutorial: Advance after clicking Fuse
		if TutorialManager and PlayerData.tutorial_step == TutorialManager.Step.CLICK_FUSE:
			TutorialManager.advance_step()
	else:
		status_label.text = "Not enough Binding Energy!"

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
		var target_size = icon_rect.size
		if target_size == Vector2.ZERO: target_size = icon_rect.custom_minimum_size
		if target_size == Vector2.ZERO: target_size = Vector2(200, 200)
		
		var visual = _create_monster_visual(monster, target_size)
		if visual:
			icon_rect.add_child(visual)
			visual.position = icon_rect.size / 2.0
			if slot_idx == 1: atom_p1 = visual
			else: atom_p2 = visual

func _update_success_rate_preview():
	if parent_1 and parent_2:
		var target_z = parent_1.atomic_number + parent_2.atomic_number
		var chance = 0.0
		
		if SynthesisManager.has_method("calculate_success_rate"):
			chance = SynthesisManager.calculate_success_rate(parent_1.stability, parent_2.stability, target_z)
		
		if stability_bar:
			if stability_bar.has_meta("anim_tween"):
				var t = stability_bar.get_meta("anim_tween")
				if t and t.is_valid(): t.kill()
			var tween = create_tween()
			tween.tween_property(stability_bar, "value", chance, 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			stability_bar.set_meta("anim_tween", tween)
			
			_update_bar_color(chance)
			
		if stability_label:
			stability_label.text = "Chance of Success: %d%%" % int(chance)
	else:
		if stability_bar:
			var tween = create_tween()
			tween.tween_property(stability_bar, "value", 0.0, 0.5)
		if stability_label: stability_label.text = "Chance of Success: --"

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

func _setup_booster_ui(checkbox: CheckBox, btn: Button, check_text: String, btn_text: String, style_normal: StyleBox, style_hover: StyleBox):
	if checkbox:
		checkbox.text = check_text
		checkbox.add_theme_font_size_override("font_size", 28)
		checkbox.add_theme_color_override("font_color", Color("#60fafc"))
		checkbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		checkbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		checkbox.custom_minimum_size.y = 60
		checkbox.add_theme_constant_override("h_separation", 15)
		checkbox.add_theme_stylebox_override("normal", style_normal)
		checkbox.add_theme_stylebox_override("hover", style_hover)
		checkbox.add_theme_stylebox_override("pressed", style_hover)
		checkbox.add_theme_stylebox_override("focus", style_hover)
		checkbox.add_theme_stylebox_override("hover_pressed", style_hover)
		
	if btn:
		btn.text = btn_text
		btn.visible = false
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.custom_minimum_size.y = 60
		btn.add_theme_font_size_override("font_size", 28)
		btn.add_theme_color_override("font_color", Color("#60fafc"))
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_hover)

func _create_monster_visual(monster: MonsterData, container_size: Vector2) -> Node2D:
	var anim_name = monster.monster_name.replace(" ", "")
	if "animation_override" in monster and monster.animation_override != "":
		anim_name = monster.animation_override
		
	var anim_path = "res://Assets/Animations/" + anim_name + ".tres"
	
	if ResourceLoader.exists(anim_path):
		var sprite_frames = load(anim_path)
		var sprite = AnimatedSprite2D.new()
		sprite.sprite_frames = sprite_frames
		
		var anim_to_play = "idle"
		if not sprite_frames.has_animation(anim_to_play):
			if sprite_frames.has_animation("default"):
				anim_to_play = "default"
			else:
				var anims = sprite_frames.get_animation_names()
				if anims.size() > 0:
					anim_to_play = anims[0]
		
		sprite.play(anim_to_play)
		
		# Scale to fit container
		var tex = sprite_frames.get_frame_texture(anim_to_play, 0)
		if tex:
			var target_h = container_size.y * 0.8
			if target_h <= 0: target_h = 150.0
			var s = target_h / float(tex.get_height())
			sprite.scale = Vector2(s, s)
			
		return sprite
	elif monster.icon:
		var sprite = Sprite2D.new()
		sprite.texture = monster.icon
		
		var target_h = container_size.y * 0.8
		if target_h <= 0: target_h = 150.0
		var s = target_h / float(monster.icon.get_height())
		sprite.scale = Vector2(s, s)
		
		return sprite
		
	return null

func _debug_add_starters():
	print("DEBUG: Inventory empty. Adding starter atoms (H, H, He)...")
	var h = _get_monster_by_atomic_number(1) # Hydrogen
	var he = _get_monster_by_atomic_number(2) # Helium
	var li = _get_monster_by_atomic_number(3) # Lithium (if implemented)
	
	if h: 
		PlayerData.owned_monsters.append(h)
	if he:
		PlayerData.owned_monsters.append(he)
	if li:
		PlayerData.owned_monsters.append(li)
	
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
		node.add_theme_constant_override("outline_size", 6)
		node.add_theme_color_override("font_outline_color", Color.BLACK)
	
	for child in node.get_children():
		_apply_font_override(child, size)
