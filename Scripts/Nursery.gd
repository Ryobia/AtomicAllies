extends Control

var capsule_list # Container for inventory capsules
var chambers_grid # Container for the 4 synthesis chambers
var capsule_panel_popup

var dissolve_popup
var dissolve_label
var dissolve_ok_btn
var fusion_result_popup
var fusion_ok_btn

var selected_chamber_index: int = -1
var pending_stabilize_index: int = -1

func _ready():
	# Find nodes dynamically
	capsule_panel_popup = find_child("CapsulePanelPopup", true, false)
	capsule_list = find_child("CapsuleList", true, false) # Needs a VBoxContainer in scene
	if not capsule_list: print("Nursery: CapsuleList node not found!")
	
	chambers_grid = find_child("ChambersGrid", true, false) # Needs a GridContainer/VBoxContainer
	
	dissolve_popup = find_child("DissolvePopup", true, false)
	fusion_result_popup = find_child("FusionResultPopup", true, false)
	
	if dissolve_popup:
		dissolve_label = dissolve_popup.find_child("Label", true, false)
		dissolve_ok_btn = dissolve_popup.find_child("OkButton", true, false)
		dissolve_popup.visible = false
		if dissolve_ok_btn:
			dissolve_ok_btn.pressed.connect(_on_dissolve_ok_pressed)

	if fusion_result_popup:
		fusion_ok_btn = fusion_result_popup.find_child("OkButton", true, false)
		fusion_result_popup.visible = false
		if fusion_ok_btn:
			fusion_ok_btn.pressed.connect(_on_fusion_ok_pressed)

	var back_btn = find_child("BackButton", true, false)
	if back_btn:
		back_btn.z_index = 10 # Force button to render on top of everything else
		back_btn.move_to_front() # Reorder node to be drawn last (on top)
		if not back_btn.pressed.is_connected(_on_back_pressed):
			back_btn.pressed.connect(_on_back_pressed)
	
	# Listen for completion from the manager
	if not SynthesisManager.fusion_completed.is_connected(_on_synthesis_completed):
		SynthesisManager.fusion_completed.connect(_on_synthesis_completed)
	
	update_ui()

func _process(_delta):
	# Update timer UI in real-time
	if chambers_grid:
		for i in range(PlayerData.synthesis_chambers.size()):
			var chamber_data = PlayerData.synthesis_chambers[i]
			if chamber_data.capsule:
				var timer_id = "synthesis_chamber_%d" % i
				var time_left = TimeManager.get_time_left(timer_id)
				
				# Find the label in the grid (assuming specific structure from update_ui)
				# We can optimize this by caching nodes, but for MVP finding by index/name is okay
				var slot = chambers_grid.get_child(i)
				if slot:
					var lbl = slot.find_child("StatusLabel", true, false)
					var btn = slot.find_child("ActionButton", true, false)
					
					if time_left > 0:
						if lbl: lbl.text = "Stabilizing... %ds" % time_left
						if btn: 
							btn.text = "Wait"
							btn.disabled = true
					elif btn and btn.disabled and btn.text == "Wait":
						# Timer just finished
						update_ui()

func update_ui():
	# Clear capsule list
	if capsule_list:
		for child in capsule_list.get_children():
			capsule_list.remove_child(child)
			child.queue_free()
			
	# Rebuild Chambers Grid
	if chambers_grid:
		for child in chambers_grid.get_children():
			chambers_grid.remove_child(child)
			child.queue_free()
			
		for i in range(PlayerData.synthesis_chambers.size()):
			var chamber_data = PlayerData.synthesis_chambers[i]
			var slot = _create_chamber_slot(i, chamber_data)
			chambers_grid.add_child(slot)

	# Show capsule list only if we are selecting for a chamber
	var show_inventory = (selected_chamber_index != -1)
	
	if capsule_panel_popup:
		capsule_panel_popup.visible = show_inventory
	
	if show_inventory and capsule_list:
		_populate_capsule_list()

func _create_chamber_slot(index: int, data: Dictionary) -> Control:
	var container = VBoxContainer.new()
	container.name = "ChamberSlot_%d" % index
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	# Visual placeholder for the capsule animation
	var visual = CenterContainer.new()
	visual.name = "CapsuleVisual"
	visual.custom_minimum_size = Vector2(0, 150)
	container.add_child(visual)
	
	var pivot = Control.new()
	visual.add_child(pivot)
	
	var sprite = AnimatedSprite2D.new()
	sprite.name = "CapsuleSprite"
	sprite.position = Vector2(0, -50)
	pivot.add_child(sprite)
	
	var label = Label.new()
	label.name = "StatusLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var lbl_style = StyleBoxFlat.new()
	lbl_style.bg_color = Color("#010813")
	lbl_style.content_margin_left = 10
	lbl_style.content_margin_right = 10
	lbl_style.content_margin_top = 5
	lbl_style.content_margin_bottom = 5
	label.add_theme_stylebox_override("normal", lbl_style)
	label.add_theme_color_override("font_color", Color("#60fafc"))
	label.add_theme_font_size_override("font_size", 24)
	container.add_child(label)
	
	var btn = Button.new()
	btn.name = "ActionButton"
	btn.custom_minimum_size = Vector2(0, 40)
	container.add_child(btn)
	_style_button(btn)
	btn.add_theme_font_size_override("font_size", 24)
	
	if not data.is_unlocked:
		label.text = "Chamber Locked"
		visual.visible = false
		btn.text = "Unlock (500 Dust)"
		btn.pressed.connect(func(): _on_unlock_pressed(index))
	elif data.capsule == null:
		label.text = "Empty Chamber"
		visual.visible = false
		btn.text = "Insert Capsule"
		btn.pressed.connect(func(): _on_insert_pressed(index))
	else:
		# Busy or Ready
		var timer_id = "synthesis_chamber_%d" % index
		var time_left = TimeManager.get_time_left(timer_id)
		if time_left > 0:
			label.text = "Stabilizing... %ds" % time_left
			btn.text = "Wait"
			btn.disabled = true
			
			# Load the resource you just created
			var anim_path = "res://Assets/Animations/CapsuleStabilizing.tres"
			if FileAccess.file_exists(anim_path):
				var anim_frames = load(anim_path)
				if anim_frames:
					sprite.sprite_frames = anim_frames
					sprite.play("energycapsule") # Plays the animation you set up in the editor
					
					if anim_frames.has_animation("energycapsule") and anim_frames.get_frame_count("energycapsule") > 0:
						var tex = anim_frames.get_frame_texture("energycapsule", 0)
						if tex:
							var s = 150.0 / float(tex.get_height())
							sprite.scale = Vector2(s, s)
			else:
				print("Warning: Capsule animation not found at: ", anim_path)
			
			visual.visible = true
		else:
			label.text = "Isotope Stable!"
			btn.text = "Stabilize"
			btn.pressed.connect(func(): _on_stabilize_pressed(index))
			# Optional: Change visual to "Ready" state
			visual.visible = true
			
	return container

func _populate_capsule_list():
	print("Populating inventory. Count: ", PlayerData.capsules.size())
	
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 40)
	close_btn.pressed.connect(func():
		selected_chamber_index = -1
		update_ui()
	)
	capsule_list.add_child(close_btn)
	
	if PlayerData.capsules.is_empty():
		var lbl = Label.new()
		lbl.text = "No Capsules in Inventory.\nFuse elements to create more!"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		lbl.add_theme_color_override("font_color", Color("#60fafc"))
		capsule_list.add_child(lbl)
		return

	for capsule in PlayerData.capsules:
		var btn = Button.new()
		var parents = capsule.get("parents", [0, 0])
		btn.text = "Capsule: Z%d + Z%d" % [parents[0], parents[1]]
		btn.custom_minimum_size = Vector2(0, 50)
		
		# To add a sprite animation here, you can add a TextureRect as a child of the button
		# or assign an AnimatedTexture to the button's icon.
		# Example:
		# btn.icon = load("res://path/to/animated_capsule.tres")
		# btn.expand_icon = true
		
		btn.pressed.connect(func(): _on_capsule_selected(capsule))
		capsule_list.add_child(btn)

func _on_capsule_selected(capsule):
	if selected_chamber_index == -1: return
	
	# Move from Inventory to Chamber
	PlayerData.remove_capsule(capsule.id)
	PlayerData.synthesis_chambers[selected_chamber_index]["capsule"] = capsule
	
	# Start Timer (Duration based on Atomic Number Z)
	# Example: 10 seconds per Z. Z=1 (10s), Z=10 (100s)
	var duration = capsule.z * 10
	TimeManager.start_timer("synthesis_chamber_%d" % selected_chamber_index, duration)
	
	selected_chamber_index = -1 # Reset selection
	update_ui()

func _on_insert_pressed(index):
	print("Insert button pressed for chamber: ", index)
	selected_chamber_index = index
	update_ui()

func _on_unlock_pressed(index):
	var cost = 500 # Fixed cost for now
	if PlayerData.spend_resource("neutron_dust", cost):
		PlayerData.synthesis_chambers[index]["is_unlocked"] = true
		PlayerData.save_game()
		update_ui()
	else:
		# Optional: Show "Not enough dust" feedback
		pass

func _on_stabilize_pressed(index):
	var capsule = PlayerData.synthesis_chambers[index]["capsule"]
	if not capsule: return
	
	pending_stabilize_index = index
	# Call the manager to finish the process
	# This will trigger the fusion_completed signal
	SynthesisManager.complete_synthesis(capsule.z)

func _on_synthesis_completed(z_num, success, reward):
	# Clear the chamber
	if pending_stabilize_index != -1:
		PlayerData.synthesis_chambers[pending_stabilize_index]["capsule"] = null
		TimeManager.active_timers.erase("synthesis_chamber_%d" % pending_stabilize_index)
		pending_stabilize_index = -1
		PlayerData.save_game()
	
	if not success:
		# Duplicate found (Dissolved)
		if dissolve_label:
			if z_num > SynthesisManager.MAX_Z:
				dissolve_label.text = "Ship Capacity Exceeded!\nZ-%d is too unstable.\nDissolved into %d Neutron Dust." % [z_num, reward]
			else:
				dissolve_label.text = "Duplicate Z-%d found!\nDissolved into %d Neutron Dust." % [z_num, reward]
		if dissolve_popup: dissolve_popup.visible = true
	else:
		# New Monster
		if fusion_result_popup:
			var new_monster = PlayerData.owned_monsters.back()
			var name_lbl = fusion_result_popup.find_child("NameLabel", true, false)
			var icon_tex = fusion_result_popup.find_child("IconTexture", true, false)
			
			if name_lbl: name_lbl.text = new_monster.monster_name
			if icon_tex: icon_tex.texture = new_monster.icon
			fusion_result_popup.visible = true
	
	update_ui()

func _on_dissolve_ok_pressed():
	if dissolve_popup: dissolve_popup.visible = false
	update_ui()

func _on_fusion_ok_pressed():
	if fusion_result_popup: fusion_result_popup.visible = false
	update_ui()

func _on_back_pressed():
	GlobalManager.switch_scene("main_menu")

func _style_button(btn: Button):
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#60fafc")
	style.bg_color.a = 0.9
	
	var hover_style = style.duplicate()
	hover_style.bg_color = style.bg_color.lightened(0.2)
	
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_color_override("font_color", Color("#010813"))
