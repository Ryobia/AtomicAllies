extends Control

@export var icon_gem: Texture2D

var chambers_grid # Container for the 4 synthesis chambers

var dissolve_popup
var dissolve_label
var dissolve_ok_btn
var fusion_result_popup
var fusion_ok_btn

var pending_stabilize_index: int = -1

func _ready():
	# Find nodes dynamically
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
	
	# Trigger tutorial check
	if TutorialManager:
		TutorialManager.check_tutorial_progress()
	
	update_ui()

func _process(_delta):
	# Update timer UI in real-time
	if chambers_grid:
		for i in range(PlayerData.synthesis_chambers.size()):
			var chamber_data = PlayerData.synthesis_chambers[i]
			if chamber_data.capsule:
				var finish_time = chamber_data.capsule.get("finish_time", 0)
				var current_time = int(Time.get_unix_time_from_system())
				var time_left = max(0, finish_time - current_time)
				
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
	if chambers_grid:
		# If the grid is empty (first run or dynamic), populate it. 
		# If it has children (from editor), reuse them.
		var existing_slots = chambers_grid.get_children()
		
		# Ensure we have enough slots for the data (fallback if not set up in editor)
		while existing_slots.size() < PlayerData.synthesis_chambers.size():
			var slot = Control.new()
			slot.name = "ChamberSlot_%d" % existing_slots.size()
			slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
			chambers_grid.add_child(slot)
			existing_slots.append(slot)
			
		for i in range(PlayerData.synthesis_chambers.size()):
			var chamber_data = PlayerData.synthesis_chambers[i]
			var slot = existing_slots[i]
			_update_chamber_slot(slot, i, chamber_data)

func _update_chamber_slot(slot: Control, index: int, data: Dictionary):
	# 1. Ensure Internal Structure Exists
	var container = slot.find_child("ContentBox", false, false)
	if not container:
		container = VBoxContainer.new()
		container.name = "ContentBox"
		container.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot.add_child(container)
		
		# Visual placeholder (Expands to push buttons down)
		var visual = CenterContainer.new()
		visual.name = "CapsuleVisual"
		visual.size_flags_vertical = Control.SIZE_EXPAND_FILL 
		container.add_child(visual)
		
		var pivot = Control.new()
		visual.add_child(pivot)
		
		var sprite = AnimatedSprite2D.new()
		sprite.name = "CapsuleSprite"
		sprite.position = Vector2(0, -50)
		pivot.add_child(sprite)
		
		# Bottom Container for Title and Buttons
		var bottom_box = VBoxContainer.new()
		bottom_box.name = "BottomBox"
		bottom_box.alignment = BoxContainer.ALIGNMENT_END
		bottom_box.add_theme_constant_override("separation", 10)
		container.add_child(bottom_box)
		
		var status_row = HBoxContainer.new()
		status_row.name = "StatusRow"
		status_row.alignment = BoxContainer.ALIGNMENT_CENTER
		bottom_box.add_child(status_row)
		
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
		label.add_theme_font_size_override("font_size", 32)
		status_row.add_child(label)
		
		var btn = Button.new()
		btn.name = "ActionButton"
		btn.custom_minimum_size = Vector2(0, 50)
		bottom_box.add_child(btn)
		_style_button(btn)
		btn.add_theme_font_size_override("font_size", 32)

	# 2. Get References
	var visual = container.find_child("CapsuleVisual", true, false)
	var sprite = container.find_child("CapsuleSprite", true, false)
	var label = container.find_child("StatusLabel", true, false)
	var btn = container.find_child("ActionButton", true, false)
	var status_row = container.find_child("StatusRow", true, false)
	
	# Clear old speed up button if it exists (it's added dynamically)
	for child in status_row.get_children():
		if child is Button: child.queue_free()

	# Clear old signals on main button
	if btn.pressed.is_connected(_on_unlock_pressed): btn.pressed.disconnect(_on_unlock_pressed)
	# Since we use lambdas/binds, we must clear all connections to be safe
	for conn in btn.pressed.get_connections():
		btn.pressed.disconnect(conn.callable)

	# 3. Update Content
	if not data.is_unlocked:
		label.text = "Chamber Locked"
		visual.visible = false
		btn.text = "Unlock (500 Dust)"
		btn.visible = true
		btn.disabled = false
		btn.pressed.connect(func(): _on_unlock_pressed(index))
	elif data.capsule == null:
		label.text = "Empty Chamber"
		visual.visible = false
		btn.visible = false
	else:
		# Busy or Ready
		btn.visible = true
		var finish_time = data.capsule.get("finish_time", 0)
		var current_time = int(Time.get_unix_time_from_system())
		var time_left = max(0, finish_time - current_time)
		if time_left > 0:
			label.text = "Stabilizing... %ds" % time_left
			btn.text = "Wait"
			btn.disabled = true
			
			# Load the resource you just created
			var anim_path = "res://Assets/Animations/CapsuleStabilizing.tres"
			if ResourceLoader.exists(anim_path):
				var anim_frames = load(anim_path)
				if anim_frames:
					sprite.sprite_frames = anim_frames
					sprite.play("energycapsule") # Plays the animation you set up in the editor
					
					if anim_frames.has_animation("energycapsule") and anim_frames.get_frame_count("energycapsule") > 0:
						var tex = anim_frames.get_frame_texture("energycapsule", 0)
						if tex:
							var s = 200.0 / float(tex.get_height())
							sprite.scale = Vector2(s, s)
			else:
				print("Warning: Capsule animation not found at: ", anim_path)
			
			visual.visible = true
			_start_bobbing_tween(sprite)
			
			var speed_btn = Button.new()
			speed_btn.text = "Speed (1)"
			if icon_gem:
				speed_btn.icon = icon_gem
				speed_btn.expand_icon = true
			speed_btn.custom_minimum_size = Vector2(0, 40)
			
			var spd_style = StyleBoxFlat.new()
			spd_style.bg_color = Color("#ffd700")
			spd_style.bg_color.a = 0.9
			var spd_hover = spd_style.duplicate()
			spd_hover.bg_color = spd_style.bg_color.lightened(0.2)
			
			speed_btn.add_theme_stylebox_override("normal", spd_style)
			speed_btn.add_theme_stylebox_override("hover", spd_hover)
			speed_btn.add_theme_stylebox_override("pressed", spd_style)
			speed_btn.add_theme_color_override("font_color", Color("#010813"))
			speed_btn.pressed.connect(func(): _on_speed_up_pressed(index))
			status_row.add_child(speed_btn)
		else:
			label.text = "Isotope Stable!"
			btn.text = "Stabilize"
			btn.disabled = false
			btn.pressed.connect(func(): _on_stabilize_pressed(index))
			
			# Load the resource for the ready state
			var anim_path = "res://Assets/Animations/CapsuleStabilizing.tres"
			if ResourceLoader.exists(anim_path):
				var anim_frames = load(anim_path)
				if anim_frames:
					sprite.sprite_frames = anim_frames
					if anim_frames.has_animation("ready"):
						sprite.play("ready")
						if anim_frames.get_frame_count("ready") > 0:
							var tex = anim_frames.get_frame_texture("ready", 0)
							if tex:
								var s = 200.0 / float(tex.get_height())
								sprite.scale = Vector2(s, s)
					else:
						sprite.play("energycapsule")

			visual.visible = true
			_start_bobbing_tween(sprite)

func _on_unlock_pressed(index):
	var cost = 500 # Fixed cost for now
	if PlayerData.spend_resource("neutron_dust", cost):
		PlayerData.synthesis_chambers[index]["is_unlocked"] = true
		PlayerData.save_game()
		update_ui()
	else:
		# Optional: Show "Not enough dust" feedback
		pass

func _on_speed_up_pressed(index):
	_show_gem_confirmation("Speed Up Synthesis", 1, func():
		if PlayerData.spend_resource("gems", 1):
			var chamber = PlayerData.synthesis_chambers[index]
			if chamber.capsule:
				chamber.capsule["finish_time"] = int(Time.get_unix_time_from_system())
				PlayerData.save_game()
				update_ui()
	)

func _on_stabilize_pressed(index):
	var capsule = PlayerData.synthesis_chambers[index]["capsule"]
	if not capsule: return
	
	pending_stabilize_index = index
	# Call the manager to finish the process
	# This will trigger the fusion_completed signal
	var stab = capsule.get("stability", 50)
	
	if TutorialManager and PlayerData.tutorial_step == TutorialManager.Step.STABILIZE_CAPSULE:
		TutorialManager.complete_tutorial()
		
	SynthesisManager.complete_synthesis(capsule.z, stab)

func _on_synthesis_completed(z_num, success, reward):
	# Clear the chamber
	if pending_stabilize_index != -1:
		PlayerData.synthesis_chambers[pending_stabilize_index]["capsule"] = null
		pending_stabilize_index = -1
		PlayerData.save_game()
	
	if not success:
		# Duplicate found (Dissolved)
		if dissolve_label:
			# If reward is a String, it's a pre-formatted message from the manager
			if reward is String:
				dissolve_label.text = reward
			else:
				if z_num > SynthesisManager.MAX_Z:
					dissolve_label.text = "Ship Capacity Exceeded!\nZ-%d is too unstable.\nDissolved into %d Neutron Dust." % [z_num, reward]
				else:
					dissolve_label.text = "Duplicate Z-%d found!\nDissolved into %d Neutron Dust." % [z_num, reward]
		if dissolve_popup: 
			dissolve_popup.visible = true
			dissolve_popup.move_to_front()
	else:
		# New Monster
		if fusion_result_popup:
			fusion_result_popup.visible = true # Show first so UI layout updates size
			fusion_result_popup.move_to_front()
			
			var new_monster = PlayerData.owned_monsters.back()
			var name_lbl = fusion_result_popup.find_child("NameLabel", true, false)
			var icon_tex = fusion_result_popup.find_child("IconTexture", true, false)
			
			if name_lbl: name_lbl.text = new_monster.monster_name
			if icon_tex:
				icon_tex.texture = new_monster.icon
				# Clear previous atoms
				for child in icon_tex.get_children():
					child.queue_free()
				var atom = _create_atom(new_monster)
				if atom:
					icon_tex.add_child(atom)
					# Wait one frame for layout to calculate correct size
					get_tree().process_frame.connect(func():
						if is_instance_valid(atom) and is_instance_valid(icon_tex):
							atom.position = icon_tex.size / 2
					, CONNECT_ONE_SHOT)
	
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

func _start_bobbing_tween(node: Node2D):
	if node.has_meta("bob_tween"):
		var t = node.get_meta("bob_tween")
		if t and t.is_valid(): t.kill()
		
	var start_y = node.position.y
	var tween = node.create_tween()
	node.set_meta("bob_tween", tween)
	tween.set_loops()
	tween.tween_property(node, "position:y", start_y - 10, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "position:y", start_y, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _show_gem_confirmation(action_name: String, cost: int, on_confirm: Callable):
	var popup = PanelContainer.new()
	popup.set_anchors_preset(Control.PRESET_CENTER)
	popup.custom_minimum_size = Vector2(500, 300)
	popup.z_index = 100
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#010813")
	style.border_color = Color("#60fafc")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	popup.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	popup.add_child(vbox)
	
	var lbl = Label.new()
	lbl.text = "Spend %d Gem(s) to %s?" % [cost, action_name]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size.x = 460
	lbl.add_theme_font_size_override("font_size", 32)
	vbox.add_child(lbl)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)
	
	var confirm_btn = Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.custom_minimum_size = Vector2(150, 60)
	confirm_btn.pressed.connect(func():
		on_confirm.call()
		popup.queue_free()
	)
	hbox.add_child(confirm_btn)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(150, 60)
	cancel_btn.pressed.connect(popup.queue_free)
	hbox.add_child(cancel_btn)
	
	add_child(popup)
	popup.position = (get_viewport_rect().size - popup.custom_minimum_size) / 2
