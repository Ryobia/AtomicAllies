extends Control

@export var icon_gem: Texture2D
@export var icon_dust: Texture2D

var chambers_grid # Container for the 4 synthesis chambers

var dissolve_popup
var dissolve_label
var dissolve_ok_btn
var fusion_result_popup
var fusion_ok_btn
var _dissolve_stability_box: VBoxContainer
var _pending_dust_reward: int = 0

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
	var stab = capsule.get("stability", 50)
	
	if TutorialManager and PlayerData.tutorial_step == TutorialManager.Step.STABILIZE_CAPSULE:
		TutorialManager.complete_tutorial()
		
	var slot = chambers_grid.get_child(index) if chambers_grid and chambers_grid.get_child_count() > index else self
	var start_pos = slot.global_position + (slot.size / 2.0) if slot else (get_viewport_rect().size / 2.0)
	
	_play_stabilization_animation(capsule.z, stab, start_pos)

func _play_stabilization_animation(z_target: int, stability: int, slot_global_pos: Vector2):
	var ui_layer = CanvasLayer.new()
	ui_layer.layer = 150
	add_child(ui_layer)

	var flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_layer.add_child(flash)

	var dummy = AnimatedSprite2D.new()
	var anim_path = "res://Assets/Animations/CapsuleStabilizing.tres"
	if ResourceLoader.exists(anim_path):
		dummy.sprite_frames = load(anim_path)
		dummy.play("energycapsule")
	
	dummy.global_position = slot_global_pos
	ui_layer.add_child(dummy)

	var center_pos = get_viewport_rect().size / 2.0
	var tween = create_tween()

	tween.tween_property(dummy, "global_position", center_pos, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(dummy, "scale", Vector2(2.5, 2.5), 1.0)

	var shake_tween = create_tween()
	shake_tween.tween_interval(1.0) 
	for i in range(20):
		var offset = Vector2(randf_range(-20, 20), randf_range(-20, 20))
		shake_tween.tween_property(dummy, "position", center_pos + offset, 0.05)
	shake_tween.tween_property(dummy, "position", center_pos, 0.05)

	tween.chain().tween_property(flash, "color:a", 1.0, 0.3)

	tween.tween_callback(func():
		dummy.queue_free()
		
		# Spawn the expanding energy ring
		var burst = CPUParticles2D.new()
		burst.emitting = true
		burst.one_shot = true
		burst.explosiveness = 1.0
		burst.amount = 120
		burst.lifetime = 0.8
		burst.spread = 180.0
		burst.gravity = Vector2.ZERO
		burst.initial_velocity_min = 400.0
		burst.initial_velocity_max = 800.0
		burst.scale_amount_min = 6.0
		burst.scale_amount_max = 14.0
		
		var grad = Gradient.new()
		grad.set_color(0, Color.WHITE)
		grad.add_point(0.2, Color("#60fafc"))
		grad.set_color(1, Color(0.376, 0.98, 0.988, 0.0)) # Transparent Cyan
		burst.color_ramp = grad
		
		ui_layer.add_child(burst)
		burst.global_position = center_pos
		
		SynthesisManager.complete_synthesis(z_target, stability)
	)

	tween.tween_property(flash, "color:a", 0.0, 0.8).set_delay(0.2)
	tween.tween_callback(func():
		ui_layer.queue_free()
	)

func _on_synthesis_completed(z_num, success, reward):
	# Clear the chamber
	if pending_stabilize_index != -1:
		PlayerData.synthesis_chambers[pending_stabilize_index]["capsule"] = null
		pending_stabilize_index = -1
		PlayerData.save_game()
	
	if not success:
		# Duplicate found (Dissolved)
		_pending_dust_reward = 0
		if dissolve_label:
			if typeof(reward) == TYPE_DICTIONARY:
				if reward.get("type") == "capacity":
					_pending_dust_reward = reward.get("dust", 0)
					dissolve_label.text = "Ship Capacity Exceeded!\nZ-%d is too unstable.\nDissolved into %d Neutron Dust." % [reward.z, reward.dust]
					_hide_stability_ui()
				elif reward.get("type") == "duplicate":
					_pending_dust_reward = reward.get("dust", 0)
					dissolve_label.text = "Duplicate Z-%d found!\nDissolved into %d Neutron Dust." % [reward.z, reward.dust]
					_show_stability_ui(reward.old_stability, reward.new_stability)
			else:
				if reward is String:
					dissolve_label.text = reward
				else:
					_pending_dust_reward = reward
					if z_num > SynthesisManager.MAX_Z:
						dissolve_label.text = "Ship Capacity Exceeded!\nZ-%d is too unstable.\nDissolved into %d Neutron Dust." % [z_num, reward]
					else:
						dissolve_label.text = "Duplicate Z-%d found!\nDissolved into %d Neutron Dust." % [z_num, reward]
				_hide_stability_ui()
				
			# Show the actual monster icon instead of the generic vial placeholder
			if dissolve_popup:
				var icon_tex = dissolve_popup.find_child("IconTexture", true, false)
				if icon_tex and PlayerData:
					var path = PlayerData.get_monster_path_by_z(z_num)
					if path != "" and ResourceLoader.exists(path):
						var m = load(path)
						if m and m.icon:
							icon_tex.texture = m.icon
							
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
			
			if fusion_result_popup.has_method("populate_details"):
				fusion_result_popup.populate_details(new_monster)
				
			if name_lbl: name_lbl.text = new_monster.monster_name
			if icon_tex:
				icon_tex.texture = null
				for child in icon_tex.get_children():
					child.queue_free()
				
				var anim_name = new_monster.monster_name.replace(" ", "")
				if "animation_override" in new_monster and new_monster.animation_override != "":
					anim_name = new_monster.animation_override
					
				var anim_path = "res://Assets/Animations/" + anim_name + ".tres"
				if ResourceLoader.exists(anim_path):
					var sprite = AnimatedSprite2D.new()
					sprite.sprite_frames = load(anim_path)
					icon_tex.add_child(sprite)
					
					get_tree().process_frame.connect(func():
						if is_instance_valid(sprite) and is_instance_valid(icon_tex):
							sprite.position = icon_tex.size / 2.0
							var tex = sprite.sprite_frames.get_frame_texture("idle", 0) if sprite.sprite_frames.has_animation("idle") else null
							if tex:
								var s = min(icon_tex.size.x, icon_tex.size.y) / float(max(tex.get_height(), 1))
								sprite.scale = Vector2(s, s)
							if fusion_result_popup.has_method("setup_sprite_cycling"):
								fusion_result_popup.setup_sprite_cycling(sprite)
					, CONNECT_ONE_SHOT)
				else:
					icon_tex.texture = new_monster.icon
					var atom = _create_atom(new_monster)
					if atom:
						icon_tex.add_child(atom)
						get_tree().process_frame.connect(func():
							if is_instance_valid(atom) and is_instance_valid(icon_tex):
								atom.position = icon_tex.size / 2
						, CONNECT_ONE_SHOT)
	
	update_ui()

func _show_stability_ui(old_stab: int, new_stab: int):
	if not _dissolve_stability_box:
		_dissolve_stability_box = VBoxContainer.new()
		_dissolve_stability_box.add_theme_constant_override("separation", 10)
		
		var title = Label.new()
		title.name = "StabTitle"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 32)
		title.add_theme_color_override("font_color", Color.WHITE)
		_dissolve_stability_box.add_child(title)
		
		var bar = ProgressBar.new()
		bar.name = "StabBar"
		bar.custom_minimum_size = Vector2(400, 30)
		bar.show_percentage = false
		
		var bg = StyleBoxFlat.new()
		bg.bg_color = Color("#050508")
		bg.border_width_left = 2; bg.border_width_top = 2
		bg.border_width_right = 2; bg.border_width_bottom = 2
		bg.border_color = Color("#404050")
		bg.set_corner_radius_all(6)
		bar.add_theme_stylebox_override("background", bg)
		
		var fill = StyleBoxFlat.new()
		fill.bg_color = Color("#60fafc")
		fill.set_corner_radius_all(6)
		fill.border_width_top = 2
		fill.border_blend = true
		bar.add_theme_stylebox_override("fill", fill)
		
		_dissolve_stability_box.add_child(bar)
		
		# Dynamically inject above the OK Button
		var vbox = dissolve_popup.find_child("VBoxContainer", true, false)
		if vbox and dissolve_ok_btn:
			vbox.add_child(_dissolve_stability_box)
			vbox.move_child(_dissolve_stability_box, dissolve_ok_btn.get_index())
			
	_dissolve_stability_box.visible = true
	var title_lbl = _dissolve_stability_box.get_node("StabTitle")
	var bar = _dissolve_stability_box.get_node("StabBar")
	
	bar.max_value = 100
	bar.value = 0
	
	var fill_style = bar.get_theme_stylebox("fill").duplicate()
	bar.add_theme_stylebox_override("fill", fill_style)
	
	var get_stab_colors = func(val: int) -> Dictionary:
		if val >= 100: return {"bg": Color("#ffd700", 1.0), "border": Color("#ffffaa")}
		elif val >= 80: return {"bg": Color("#60fafc", 0.9), "border": Color("#ccffff")}
		elif val >= 50: return {"bg": Color("#2ecc71", 0.9), "border": Color("#aaffaa")}
		else: return {"bg": Color("#ff4d4d", 0.9), "border": Color("#ffaaaa")}

	var target_colors = get_stab_colors.call(new_stab)
	var old_colors = get_stab_colors.call(old_stab)
	var zero_colors = get_stab_colors.call(0)
	
	fill_style.bg_color = zero_colors.bg
	fill_style.border_color = zero_colors.border

	if bar.has_meta("pulse_tween"):
		var t = bar.get_meta("pulse_tween")
		if t and t.is_valid(): t.kill()
		bar.set_meta("pulse_tween", null)

	if new_stab > old_stab:
		title_lbl.text = "Stability Increased: %d%% -> %d%%" % [old_stab, new_stab]
		title_lbl.add_theme_color_override("font_color", Color("#2ecc71"))
		
		var tween = create_tween()
		tween.tween_property(bar, "value", new_stab, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(fill_style, "bg_color", target_colors.bg, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(fill_style, "border_color", target_colors.border, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		if new_stab >= 100:
			if old_stab < 100:
				tween.chain().tween_callback(func(): _play_mastery_particles(bar))
			tween.chain().tween_callback(func(): _start_pulse(bar, fill_style))
	else:
		title_lbl.text = "Best Stability: %d%% (Rolled %d%%)" % [old_stab, new_stab]
		title_lbl.add_theme_color_override("font_color", Color("#a0a0a0"))
		
		# Animate drop to the bad roll, then bounce back up to their saved best
		var tween = create_tween()
		tween.tween_property(bar, "value", new_stab, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(fill_style, "bg_color", target_colors.bg, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(fill_style, "border_color", target_colors.border, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		tween.tween_property(bar, "value", old_stab, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.5)
		tween.parallel().tween_property(fill_style, "bg_color", old_colors.bg, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.5)
		tween.parallel().tween_property(fill_style, "border_color", old_colors.border, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.5)

		if old_stab >= 100:
			if new_stab < 100: tween.chain().tween_callback(func(): _play_mastery_particles(bar))
			tween.chain().tween_callback(func(): _start_pulse(bar, fill_style))

func _hide_stability_ui():
	if _dissolve_stability_box:
		_dissolve_stability_box.visible = false

func _on_dissolve_ok_pressed():
	if dissolve_popup: dissolve_popup.visible = false
	
	if _pending_dust_reward > 0:
		_play_dust_fly_animation(_pending_dust_reward)
		_pending_dust_reward = 0
	else:
		update_ui()

func _play_dust_fly_animation(amount: int):
	if not icon_dust:
		# Fallback if no icon is assigned in the inspector
		PlayerData.add_resource("neutron_dust", amount)
		update_ui()
		return
		
	var start_pos = get_viewport_rect().size / 2.0
	var target_pos = Vector2(start_pos.x, 50)
	
	var header = get_tree().root.find_child("ResourceHeader", true, false)
	if header:
		header.visible = true
		var dust_node = header.find_child("*Dust*", true, false)
		if dust_node:
			var rect = dust_node.get_global_rect()
			target_pos = rect.position + (rect.size / 2.0)
			
	var fly_icon = Sprite2D.new()
	fly_icon.texture = icon_dust
	fly_icon.global_position = start_pos
	fly_icon.z_index = 300
	
	var tex_size = icon_dust.get_size()
	if tex_size.x > 0:
		var s = 100.0 / max(tex_size.x, 1.0)
		fly_icon.scale = Vector2(s, s)
		
	add_child(fly_icon)
	
	var duration = 0.8
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(fly_icon, "global_position", target_pos, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(fly_icon, "scale", Vector2(0.2, 0.2), duration)
	tween.tween_property(fly_icon, "modulate:a", 0.0, 0.2).set_delay(duration - 0.2)
	
	var seq = create_tween()
	seq.tween_interval(duration)
	seq.tween_callback(func():
		fly_icon.queue_free()
		PlayerData.add_resource("neutron_dust", amount)
		update_ui()
	)

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

func _start_pulse(bar: ProgressBar, style: StyleBoxFlat):
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(style, "bg_color", Color("#fff5cc"), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(style, "bg_color", Color("#ffd700"), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bar.set_meta("pulse_tween", tween)

func _play_mastery_particles(parent_node: Control):
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 60
	particles.lifetime = 0.8
	particles.explosiveness = 1.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = parent_node.size / 2.0
	particles.spread = 180.0
	particles.gravity = Vector2(0, 0)
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 160.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 8.0
	particles.z_index = 50
	
	var grad = Gradient.new()
	grad.set_color(0, Color("#ffffff"))
	grad.add_point(0.2, Color("#ffd700"))
	grad.set_color(1, Color(1.0, 0.84, 0.0, 0.0))
	particles.color_ramp = grad
	
	parent_node.add_child(particles)
	particles.position = parent_node.size / 2.0
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)

func _show_gem_confirmation(action_name: String, cost: int, on_confirm: Callable):
	var popup = PanelContainer.new()
	popup.set_anchors_preset(Control.PRESET_CENTER)
	popup.custom_minimum_size = Vector2(1000, 600)
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
	lbl.custom_minimum_size.x = 920
	lbl.add_theme_font_size_override("font_size", 64)
	vbox.add_child(lbl)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)
	
	var confirm_btn = Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.custom_minimum_size = Vector2(300, 120)
	confirm_btn.add_theme_font_size_override("font_size", 48)
	confirm_btn.pressed.connect(func():
		on_confirm.call()
		popup.queue_free()
	)
	hbox.add_child(confirm_btn)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(300, 120)
	cancel_btn.add_theme_font_size_override("font_size", 48)
	cancel_btn.pressed.connect(popup.queue_free)
	hbox.add_child(cancel_btn)
	
	add_child(popup)
	popup.position = (get_viewport_rect().size - popup.custom_minimum_size) / 2
