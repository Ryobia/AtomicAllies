extends CanvasLayer

# Tutorial Steps Enum for clarity
enum Step {
	INTRO_NEXUS = 0,
	SELECT_PARENT_1 = 1,
	SELECT_PARENT_2 = 2,
	CLICK_FUSE = 3,
	WAIT_FOR_FUSION = 4,
	GO_TO_NURSERY = 5, # Triggered after fusion starts
	STABILIZE_CAPSULE = 6,
	COMPLETE = 999
}

var overlay: ColorRect
var highlight_rect: ReferenceRect
var instruction_label: Label
var current_target_node: Control = null
var story_popup: PanelContainer
var _bounce_tween: Tween
var _typewriter_tween: Tween

func _ready():
	# Ensure this layer is above everything else
	layer = 100
	_create_ui()
	_create_story_popup()
	
	# Listen for scene changes to update tutorial state
	if GlobalManager:
		GlobalManager.scene_changed.connect(_on_scene_changed)
	
	# Check immediately (deferred to wait for scene load)
	call_deferred("check_tutorial_progress")

func _create_ui():
	# Dimmed Background
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE # Let clicks pass through by default
	overlay.visible = false
	add_child(overlay)
	
	# Highlight Box (Visual only, clicks pass through to target)
	highlight_rect = ReferenceRect.new()
	highlight_rect.border_color = Color("#ffd700") # Gold
	highlight_rect.border_width = 4.0
	highlight_rect.editor_only = false
	highlight_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(highlight_rect)
	
	# Instruction Text
	instruction_label = Label.new()
	instruction_label.add_theme_font_size_override("font_size", 32)
	instruction_label.add_theme_color_override("font_color", Color("#60fafc"))
	instruction_label.add_theme_color_override("font_outline_color", Color.BLACK)
	instruction_label.add_theme_constant_override("outline_size", 8)
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction_label.custom_minimum_size = Vector2(600, 0)
	
	# Position label at top center by default
	instruction_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	instruction_label.position.y = 100
	overlay.add_child(instruction_label)

func _create_story_popup():
	story_popup = PanelContainer.new()
	story_popup.set_anchors_preset(Control.PRESET_CENTER)
	story_popup.custom_minimum_size = Vector2(700, 450)
	story_popup.visible = false
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#010813")
	style.border_color = Color("#60fafc")
	style.set_border_width_all(4)
	style.set_corner_radius_all(16)
	story_popup.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	story_popup.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = "SYSTEM ALERT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("#ff4d4d"))
	vbox.add_child(title)
	
	var desc = Label.new()
	desc.text = "The Void is consuming the cosmos.\nEntropy levels are critical.\n\nYou are the Architect.\nSynthesize elements. Rebuild reality.\n\nInitiate Fusion Protocol?"
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 32)
	desc.add_theme_color_override("font_color", Color("#60fafc"))
	vbox.add_child(desc)
	
	var btn = Button.new()
	btn.text = "INITIALIZE"
	btn.custom_minimum_size = Vector2(0, 80)
	btn.add_theme_font_size_override("font_size", 36)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color("#60fafc")
	btn_style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_stylebox_override("hover", btn_style)
	btn.add_theme_stylebox_override("pressed", btn_style)
	btn.add_theme_color_override("font_color", Color("#010813"))
	
	btn.pressed.connect(_on_story_start_pressed)
	vbox.add_child(btn)
	
	# Pulse Animation
	btn.resized.connect(func(): btn.pivot_offset = btn.size / 2)
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	add_child(story_popup)

func _process(_delta):
	if overlay.visible and current_target_node and is_instance_valid(current_target_node):
		# Keep highlight rect synced with target position (in case of layout updates)
		var global_pos = current_target_node.get_global_rect().position
		var size = current_target_node.get_global_rect().size
		highlight_rect.position = global_pos
		highlight_rect.size = size
		
		# Pulse effect
		var t = Time.get_ticks_msec() / 200.0
		highlight_rect.border_color.a = 0.5 + 0.5 * sin(t)

func _on_scene_changed(_scene_name):
	# Wait a frame for UI to settle
	await get_tree().process_frame
	check_tutorial_progress()

func check_tutorial_progress():
	var step = PlayerData.tutorial_step
	var scene = get_tree().current_scene
	
	if not scene: return
	
	hide_tutorial()
	
	if step == Step.COMPLETE:
		return

	if step == Step.INTRO_NEXUS:
		if scene.name == "MainMenu" or scene.name == "Nexus":
			show_story_popup()
		return

	if scene.name == "Nexus":
		if step == Step.SELECT_PARENT_1:
			var btn = scene.find_child("Parent1Button", true, false)
			show_instruction("Welcome Commander!\nStart by selecting your first element.", btn)
		elif step == Step.SELECT_PARENT_2:
			var btn = scene.find_child("Parent2Button", true, false)
			show_instruction("Excellent. Now select a second element to fuse.", btn)
		elif step == Step.CLICK_FUSE:
			var btn = scene.find_child("BreedButton", true, false)
			show_instruction("Fusion ready! Tap the button to combine them.", btn)
		elif step == Step.GO_TO_NURSERY:
			var btn = scene.find_child("BackButton", true, false)
			show_instruction("Fusion started! Return to the Main Menu to check the Nursery.", btn)
			
	elif scene.name == "MainMenu":
		if step == Step.GO_TO_NURSERY:
			var btn = scene.find_child("NurseryButton", true, false)
			if btn: show_instruction("Go to the Nursery to stabilize your new element.", btn)
			
	elif scene.name == "Nursery":
		if step == Step.GO_TO_NURSERY:
			# They arrived at nursery, advance step
			PlayerData.tutorial_step = Step.STABILIZE_CAPSULE
			PlayerData.save_game()
			check_tutorial_progress()
		elif step == Step.STABILIZE_CAPSULE:
			# Find the first active chamber button
			var grid = scene.find_child("ChambersGrid", true, false)
			if grid and grid.get_child_count() > 0:
				var slot = grid.get_child(0)
				var btn = slot.find_child("ActionButton", true, false)
				if btn:
					show_instruction("The isotope is unstable! Tap to stabilize it.", btn)

func show_instruction(text: String, target: Control):
	if not target: return
	
	current_target_node = target
	instruction_label.text = text
	overlay.visible = true
	
	# Move label to avoid covering target
	if target.get_global_rect().position.y < 300:
		# Target is at top, move label to bottom
		instruction_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		instruction_label.position.y = get_viewport().get_visible_rect().size.y - 200
	else:
		# Target is lower, move label to top
		instruction_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		instruction_label.position.y = 150
		
	_start_bounce_animation()
	
	# Typewriter Effect
	if _typewriter_tween and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
	
	var duration = text.length() * 0.03
	_typewriter_tween = create_tween()
	_typewriter_tween.tween_property(instruction_label, "visible_ratio", 1.0, duration)

func show_story_popup():
	if overlay: overlay.visible = true
	if story_popup: story_popup.visible = true
	current_target_node = null

func _on_story_start_pressed():
	story_popup.visible = false
	overlay.visible = false
	
	# If we are not in Nexus, go there
	if get_tree().current_scene.name != "Nexus":
		if GlobalManager:
			GlobalManager.switch_scene("nexus")
	
	# Advance to step 1 (Select Parent 1)
	advance_step()

func hide_tutorial():
	overlay.visible = false
	if story_popup: story_popup.visible = false
	current_target_node = null

func advance_step():
	PlayerData.tutorial_step += 1
	PlayerData.save_game()
	check_tutorial_progress()

func complete_tutorial():
	PlayerData.tutorial_step = Step.COMPLETE
	PlayerData.save_game()
	hide_tutorial()
	
	# Optional: Show a completion popup
	var popup = AcceptDialog.new()
	popup.title = "Tutorial Complete"
	popup.dialog_text = "You have synthesized your first element!\n\nExplore the Campaign to find more blueprints."
	add_child(popup)
	popup.popup_centered()

func _start_bounce_animation():
	if _bounce_tween and _bounce_tween.is_valid():
		_bounce_tween.kill()
		
	var base_y = instruction_label.position.y
	_bounce_tween = create_tween()
	_bounce_tween.set_loops()
	_bounce_tween.tween_property(instruction_label, "position:y", base_y - 10, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bounce_tween.tween_property(instruction_label, "position:y", base_y, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
