extends CanvasLayer

# Tutorial Steps Enum for clarity
enum Step {
	INTRO = 0,
	SELECT_LITHIUM = 1,
	CONFIRM_RUN = 2,
	# Battle Prep Sequence (Moved up)
	BATTLE_PREP_INTRO = 3,
	ASSIGN_VANGUARD = 4,
	SELECT_HELIUM = 5,
	INSPECT_HELIUM = 6,
	CLOSE_INSPECT = 7,
	ASSIGN_FLANK = 8,
	SELECT_HYDROGEN = 9,
	EXPLAIN_INTEL = 10,
	EXPLAIN_LEGEND = 11,
	START_BATTLE = 12,
	# Battle Tutorial Sequence
	BATTLE_INTRO = 13,
	EXPLAIN_ATB = 14,
	EXPLAIN_ACTIONS = 15,
	SELECT_ATTACK = 16,
	SELECT_MOVE = 17,
	EXPLAIN_TARGETING = 18,
	INSPECT_ENEMY = 19,
	CLOSE_INSPECT_ENEMY = 20,
	BATTLE_RESUME = 21,
	# Rest Site Sequence
	REST_SITE_INTRO = 22,
	EXPLAIN_LOOT = 23,
	SELECT_REWARD = 24,
	EXPLAIN_HEAL = 25,
	EXPLAIN_SWAP = 26,
	CONTINUE_RUN = 27,
	# Post-Run Sequence
	COMPLETE_RUN = 28,
	GO_TO_NEXUS = 29,
	SELECT_PARENT_1 = 30,
	SELECT_PARENT_2 = 31,
	CLICK_FUSE = 32,
	GO_TO_NURSERY = 33,
	STABILIZE_CAPSULE = 34,
	COMPLETE = 999
}

var overlay: Control
var dim_top: ColorRect
var dim_bottom: ColorRect
var dim_left: ColorRect
var dim_right: ColorRect
var highlight_rect: ReferenceRect
var instruction_label: Label
var current_target_node: Control = null
var lumn_sprite: AnimatedSprite2D
var dialog_root: Control
var dialog_panel: PanelContainer
var _bounce_tween: Tween
var _typewriter_tween: Tween
var story_button: Button
var current_intro_index: int = 0

const INTRO_SCRIPT = [
	"L.U.M.N.: \"Initial consciousness sync confirmed. Welcome back, Catalyst. I am L.U.M.N., your Luminous Utility & Monitoring Network.\"",
	"I must report that local sector stability has reached a critical threshold of 0.04%. The Periodic Table—the very blueprint of our reality—is effectively compromised.",
	"To prevent total entropic collapse, we must reconstruct all 118 elements. However, my archives for higher-order matter have been purged by the Void.",
	"To synthesize Lithium (Z=3), we first require its structural schematic. I have detected a faint resonance of a Lithium Blueprint within a nearby cluster of Void Motes.",
	"You must initiate a Discovery Run immediately. Navigate to the sector, neutralize the entropic interference, and retrieve the blueprint.",
	"Only then can we return to the Lab to begin the fusion process. The vessel is prepped for transit. The universe is waiting, Catalyst.\""
]

func _ready():
	# Ensure this layer is above everything else
	layer = 100
	_create_ui()
	
	# Listen for scene changes to update tutorial state
	if GlobalManager:
		GlobalManager.scene_changed.connect(_on_scene_changed)
	
	# Check immediately (deferred to wait for scene load)
	call_deferred("check_tutorial_progress")

func _create_ui():
	# Dimmed Background
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE # Let clicks pass through by default
	overlay.visible = false
	add_child(overlay)
	
	# Create 4 rects for the spotlight effect (Top, Bottom, Left, Right)
	var dim_color = Color(0, 0, 0, 0.5)
	
	dim_top = ColorRect.new(); dim_top.color = dim_color; dim_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim_top)
	
	dim_bottom = ColorRect.new(); dim_bottom.color = dim_color; dim_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim_bottom)
	
	dim_left = ColorRect.new(); dim_left.color = dim_color; dim_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim_left)
	
	dim_right = ColorRect.new(); dim_right.color = dim_color; dim_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim_right)
	
	# Highlight Box (Visual only, clicks pass through to target)
	highlight_rect = ReferenceRect.new()
	highlight_rect.border_color = Color("#ffd700") # Gold
	highlight_rect.border_width = 4.0
	highlight_rect.editor_only = false
	highlight_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(highlight_rect)
	
	# Dialog Root (Holds Panel + Sprite)
	dialog_root = Control.new()
	dialog_root.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dialog_root.offset_top = -500 # Height of area
	dialog_root.offset_bottom = -100 # Move up from bottom
	dialog_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dialog_root)
	
	# Text Panel
	dialog_panel = PanelContainer.new()
	dialog_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	dialog_panel.offset_top = 50 # Push down to leave room for LUMN head
	dialog_panel.offset_left = 20
	dialog_panel.offset_right = -20
	dialog_panel.offset_bottom = -20
	dialog_root.add_child(dialog_panel)
	
	var dialog_style = StyleBoxFlat.new()
	dialog_style.bg_color = Color("#010813")
	dialog_style.border_color = Color("#60fafc")
	dialog_style.set_border_width_all(2)
	dialog_style.set_corner_radius_all(12)
	dialog_panel.add_theme_stylebox_override("panel", dialog_style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 220) # Space for LUMN
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	dialog_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	
	# Instruction Text
	instruction_label = Label.new()
	instruction_label.add_theme_font_size_override("font_size", 44)
	instruction_label.add_theme_color_override("font_color", Color("#60fafc"))
	instruction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(instruction_label)
	
	# Story Button (Next)
	story_button = Button.new()
	story_button.text = "NEXT"
	story_button.custom_minimum_size = Vector2(250, 80)
	story_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	story_button.add_theme_font_size_override("font_size", 48)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color("#60fafc")
	btn_style.set_corner_radius_all(8)
	story_button.add_theme_stylebox_override("normal", btn_style)
	story_button.add_theme_stylebox_override("hover", btn_style)
	story_button.add_theme_stylebox_override("pressed", btn_style)
	var text_color = Color("#010813")
	story_button.add_theme_color_override("font_color", text_color)
	story_button.add_theme_color_override("font_pressed_color", text_color)
	story_button.add_theme_color_override("font_hover_color", text_color)
	story_button.add_theme_color_override("font_focus_color", text_color)
	
	story_button.pressed.connect(_on_story_button_pressed)
	story_button.pressed.connect(func(): _animate_button_press(story_button))
	story_button.resized.connect(func(): story_button.pivot_offset = story_button.size / 2)
	story_button.visible = false
	vbox.add_child(story_button)
	
	# L.U.M.N. AI Assistant
	var lumn_control = Control.new()
	lumn_control.custom_minimum_size = Vector2(250, 250)
	lumn_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialog_root.add_child(lumn_control)
	lumn_control.position = Vector2(20, 0) # Top-left of dialog_root (which is bottom area)
	
	lumn_sprite = AnimatedSprite2D.new()
	lumn_sprite.scale = Vector2(0.5, 0.5)
	var frames = load("res://Assets/Animations/LUMN.tres")
	if frames:
		lumn_sprite.sprite_frames = frames
		lumn_sprite.play("idle")
	lumn_control.add_child(lumn_sprite)
	lumn_sprite.position = Vector2(125, 125) # Center in control

func _process(_delta):
	if overlay.visible:
		var screen_size = get_viewport().get_visible_rect().size
		
		if current_target_node and is_instance_valid(current_target_node):
			# Keep highlight rect synced with target position (in case of layout updates)
			var global_pos = current_target_node.get_global_rect().position
			var size = current_target_node.get_global_rect().size
			
			highlight_rect.visible = true
			highlight_rect.position = global_pos
			highlight_rect.size = size
			
			# Pulse effect
			var t = Time.get_ticks_msec() / 200.0
			highlight_rect.border_color.a = 0.5 + 0.5 * sin(t)
			
			# Update Dimmers to create spotlight hole
			dim_top.position = Vector2.ZERO
			dim_top.size = Vector2(screen_size.x, global_pos.y)
			
			dim_bottom.position = Vector2(0, global_pos.y + size.y)
			dim_bottom.size = Vector2(screen_size.x, max(0, screen_size.y - (global_pos.y + size.y)))
			
			dim_left.position = Vector2(0, global_pos.y)
			dim_left.size = Vector2(global_pos.x, size.y)
			
			dim_right.position = Vector2(global_pos.x + size.x, global_pos.y)
			dim_right.size = Vector2(max(0, screen_size.x - (global_pos.x + size.x)), size.y)
		else:
			# No target, full dim
			highlight_rect.visible = false
			dim_top.position = Vector2.ZERO
			dim_top.size = screen_size
			dim_bottom.size = Vector2.ZERO
			dim_left.size = Vector2.ZERO
			dim_right.size = Vector2.ZERO

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

	if step == Step.INTRO:
		if scene.name == "MainMenu" or scene.name == "Nexus" or scene.name == "PeriodicTable":
			show_story_popup()
		return

	if scene.name == "PeriodicTable":
		if step == Step.SELECT_LITHIUM:
			# Access _card_nodes from PeriodicTable to find Lithium (Z=3)
			if "_card_nodes" in scene and scene._card_nodes.has(3):
				var card = scene._card_nodes[3]
				show_instruction("Select Lithium (Element 3) to acquire its blueprint.", card, "talk")
		elif step == Step.CONFIRM_RUN:
			var popup = scene.find_child("DiscoveryRunPopup", true, false)
			if popup and popup.visible:
				var btn = popup.find_child("ConfirmButton", true, false)
				if not btn: btn = popup.find_child("StartButton", true, false)
				show_instruction("Initiate the Discovery Run.", btn)

	if scene.name == "Nexus":
		if step == Step.GO_TO_NEXUS:
			advance_step() # Move to SELECT_PARENT_1
			
		if step == Step.SELECT_PARENT_1:
			var btn = scene.find_child("Parent1Button", true, false)
			show_instruction("Welcome Commander!\nStart by selecting your first element.", btn, "happy")
		elif step == Step.SELECT_PARENT_2:
			var btn = scene.find_child("Parent2Button", true, false)
			show_instruction("Excellent. Now select a second element to fuse.", btn, "happy")
		elif step == Step.CLICK_FUSE:
			var btn = scene.find_child("BreedButton", true, false)
			show_instruction("Fusion ready! Tap the button to combine them.", btn)
		elif step == Step.GO_TO_NURSERY:
			# Try to find the Nursery button in the NavBar first
			var btn = _find_nav_button("NurseryButton")
			if not btn: btn = scene.find_child("BackButton", true, false)
			show_instruction("Fusion started! Go to the Synthesis Chamber to stabilize your new element.", btn, "talk", "top")
			
	elif scene.name == "MainMenu":
		if step == Step.START_BATTLE or step == Step.COMPLETE_RUN:
			# Check if we actually got the blueprint (user might have retreated)
			if PlayerData.unlocked_blueprints.has(3):
				# Advance to GO_TO_NEXUS
				PlayerData.tutorial_step = Step.GO_TO_NEXUS
				PlayerData.save_game()
				check_tutorial_progress()
			else:
				# Failed run or retreated? Send them back to table.
				var btn = _find_nav_button("PeriodicTableButton")
				show_instruction("Mission incomplete. Return to the Periodic Table to retry the Discovery Run.", btn, "warning", "top")
		elif step == Step.GO_TO_NEXUS:
			var btn = _find_nav_button("NexusButton")
			show_instruction("Blueprint acquired! Go to the Nexus to synthesize it.", btn, "happy", "top")
		elif step == Step.GO_TO_NURSERY:
			var btn = _find_nav_button("NurseryButton")
			if btn: show_instruction("Go to the Synthesis Chamber to stabilize your new element.", btn, "talk", "top")
			
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
					show_instruction("The isotope is unstable! Tap to stabilize it.", btn, "warning")
					
	elif scene.name == "BattlePrepare":
		if step == Step.BATTLE_PREP_INTRO:
			# Auto-advance
			print("TutorialManager: Starting Battle Prep Tutorial")
			advance_step()
		elif step == Step.ASSIGN_VANGUARD:
			var container = scene.find_child("TeamContainer", true, false)
			if container and container.get_child_count() > 0:
				# Vanguard is index 1 in display order (Center)
				var slot = container.get_child(1) 
				show_instruction("The Vanguard takes the hits. Assign your toughest unit (Tank) here.", slot, "talk")
		elif step == Step.SELECT_HELIUM:
			# We need to find the Helium card in the collection popup
			# Since the popup is created dynamically, BattlePrepare needs to call us back or we check continuously
			# For now, we rely on BattlePrepare to trigger the highlight when the popup opens
			pass 
		elif step == Step.INSPECT_HELIUM:
			var container = scene.find_child("TeamContainer", true, false)
			if container and container.get_child_count() > 0:
				# Vanguard is index 1 in display order (Center)
				var slot = container.get_child(1) 
				show_instruction("Tap Helium again to inspect its details.", slot, "talk")
		elif step == Step.CLOSE_INSPECT:
			var btn = scene.find_child("PopupBackButton", true, false)
			if btn:
				show_instruction("Review stats and moves here. Tap Back to continue.", btn, "talk")
		elif step == Step.ASSIGN_FLANK:
			var container = scene.find_child("TeamContainer", true, false)
			if container and container.get_child_count() > 0:
				# Flank is index 0 (Left)
				var slot = container.get_child(0)
				show_instruction("Flanks are safer. Assign damage dealers or support units here.", slot, "talk")
		elif step == Step.SELECT_HYDROGEN:
			pass # Handled by BattlePrepare when popup opens
		elif step == Step.EXPLAIN_INTEL:
			var intel = scene.find_child("EnemyIntelLabel", true, false)
			show_instruction("Check Enemy Intel. Be prepared for multiple waves of hostiles.", intel, "warning")
			# Auto-advance after a delay or click? For now, let's make the user click the target or a "Next" button
			# Since we don't have a "Next" button for normal steps, we can use a timer or click detection
			# For simplicity, let's re-enable the story button for this explanation step
			story_button.visible = true
			story_button.text = "Got it"
			if not story_button.pressed.is_connected(advance_step):
				story_button.pressed.connect(advance_step, CONNECT_ONE_SHOT)
		elif step == Step.EXPLAIN_LEGEND:
			var legend = scene.find_child("LegendContainer", true, false)
			show_instruction("Consult the Legend. Each Atomic Class has unique combat specialties.", legend, "talk")
			story_button.visible = true
			story_button.text = "Understood"
			if not story_button.pressed.is_connected(advance_step):
				story_button.pressed.connect(advance_step, CONNECT_ONE_SHOT)
		elif step == Step.START_BATTLE:
			var btn = scene.find_child("StartButton", true, false)
			show_instruction("Tap a unit to view details, or press ENGAGE to start the mission!", btn, "happy")
			
	elif scene.name == "BattleManager":
		if step == Step.BATTLE_INTRO:
			# Triggered by BattleManager.start_battle
			show_instruction("Combat initiated. Your team is on the bottom, enemies on top.", null, "talk")
			story_button.visible = true
			story_button.text = "Roger"
			if not story_button.pressed.is_connected(advance_step):
				story_button.pressed.connect(advance_step, CONNECT_ONE_SHOT)
		elif step == Step.EXPLAIN_ATB:
			# Highlight a speed bar (e.g. Player 1's)
			var hud = scene.find_child("BattleHUD", true, false)
			if hud:
				var slot = hud.find_child("PlayerSlot1", true, false) # Vanguard
				var bar = slot.find_child("SpeedBar", true, false) if slot else null
				show_instruction("The Speed Bar (Yellow) determines turn order. When full, the unit acts.", bar, "talk")
				story_button.visible = true
				story_button.text = "Next"
				if not story_button.pressed.is_connected(advance_step):
					story_button.pressed.connect(advance_step, CONNECT_ONE_SHOT)
		elif step == Step.EXPLAIN_ACTIONS:
			# Highlight Action Deck
			var hud = scene.find_child("BattleHUD", true, false)
			var deck = hud.find_child("ControlDeck", true, false) if hud else null
			show_instruction("When it's your turn, select an action: Attack, Swap, or Item.", deck, "talk")
			story_button.visible = true
			story_button.text = "Fight!"
			if not story_button.pressed.is_connected(advance_step):
				story_button.pressed.connect(advance_step, CONNECT_ONE_SHOT)
		elif step == Step.SELECT_ATTACK:
			var hud = scene.find_child("BattleHUD", true, false)
			var btn = hud.find_child("AttackButton", true, false) if hud else null
			show_instruction("Select 'Attack' to view available moves.", btn, "talk")
		elif step == Step.SELECT_MOVE:
			var hud = scene.find_child("BattleHUD", true, false)
			var container = hud.find_child("MoveContainer", true, false) if hud else null
			var target_btn = null
			if container:
				for child in container.get_children():
					if child is Button and "Electronegativity" in child.text:
						target_btn = child
						break
			show_instruction("Choose 'Electronegativity' to slow the enemy.", target_btn, "talk")
		elif step == Step.EXPLAIN_TARGETING:
			var hud = scene.find_child("BattleHUD", true, false)
			var slot = hud.find_child("Enemy1", true, false) if hud else null
			show_instruction("Select a target. Move details are shown below.", slot, "talk")
			
			# Override position to middle to avoid blocking bottom UI (Move Details)
			# Use anchors to define a band in the lower-middle
			dialog_root.anchor_top = 0.5
			dialog_root.anchor_bottom = 0.8
			dialog_root.anchor_left = 0.0
			dialog_root.anchor_right = 1.0
			dialog_root.offset_top = 0
			dialog_root.offset_bottom = 0
		elif step == Step.INSPECT_ENEMY:
			var hud = scene.find_child("BattleHUD", true, false)
			var slot = hud.find_child("Enemy1", true, false) if hud else null
			show_instruction("Long-press the enemy to inspect stats and status effects.", slot, "talk")
		elif step == Step.CLOSE_INSPECT_ENEMY:
			var hud = scene.find_child("BattleHUD", true, false)
			var popup = hud.find_child("StatPopup", true, false) if hud else null
			var btn = popup.find_child("CloseButton", true, false) if popup else null
			show_instruction("Review the enemy status. Tap Close to resume.", btn, "talk")
		elif step == Step.BATTLE_RESUME:
			show_instruction("You are ready. Defeat the Void!", null, "happy")
			story_button.visible = true
			story_button.text = "Engage"
			if not story_button.pressed.is_connected(advance_step):
				story_button.pressed.connect(advance_step, CONNECT_ONE_SHOT)
				
	elif scene.name == "RestSite":
		if step == Step.REST_SITE_INTRO:
			show_instruction("Welcome to the Rest Site. Here you can recover and resupply.", null, "talk")
			story_button.visible = true
			story_button.text = "Next"
			if not story_button.pressed.is_connected(advance_step):
				story_button.pressed.connect(advance_step, CONNECT_ONE_SHOT)
		elif step == Step.EXPLAIN_LOOT:
			var loot = scene.find_child("LootContainer", true, false)
			if not loot: loot = scene.find_child("LootLabel", true, false)
			show_instruction("You have collected resources from the previous wave.", loot, "talk")
			story_button.visible = true
			story_button.text = "Next"
			if not story_button.pressed.is_connected(advance_step):
				story_button.pressed.connect(advance_step, CONNECT_ONE_SHOT)
		elif step == Step.SELECT_REWARD:
			var container = scene.find_child("RewardContainer", true, false)
			show_instruction("Choose a bonus to aid you in the next wave.", container, "happy")
		elif step == Step.EXPLAIN_HEAL:
			var btn = scene.find_child("FullHealButton", true, false)
			show_instruction("Healing units costs Binding Energy earned during the run.", btn, "talk")
			story_button.visible = true
			story_button.text = "Understood"
			if not story_button.pressed.is_connected(advance_step):
				story_button.pressed.connect(advance_step, CONNECT_ONE_SHOT)
		elif step == Step.EXPLAIN_SWAP:
			var grid = scene.find_child("MonsterGrid", true, false)
			show_instruction("Tap a unit to select, then tap another to swap positions.", grid, "talk")
			story_button.visible = true
			story_button.text = "Got it"
			if not story_button.pressed.is_connected(advance_step):
				story_button.pressed.connect(advance_step, CONNECT_ONE_SHOT)
		elif step == Step.CONTINUE_RUN:
			var btn = scene.find_child("ContinueButton", true, false)
			show_instruction("Press Continue when ready for the next wave.", btn, "talk")

func show_instruction(text: String, target: Control, emotion: String = "talk", force_position: String = ""):
	# if not target: return # Allow null target for general messages
	
	current_target_node = target
	instruction_label.text = text
	overlay.visible = true
	story_button.visible = false # Hide button for normal instructions
	
	# Dynamic Positioning: Avoid covering the target
	var viewport_height = get_viewport().get_visible_rect().size.y
	
	if force_position == "top":
		dialog_root.set_anchors_preset(Control.PRESET_TOP_WIDE)
		dialog_root.offset_top = 20
		dialog_root.offset_bottom = 370
	elif force_position == "bottom":
		dialog_root.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		dialog_root.offset_top = -500
		dialog_root.offset_bottom = -100
	elif target:
		var target_y = target.get_global_rect().get_center().y
		if target_y > viewport_height * 0.6:
			# Target is in bottom 40%, move dialog to top
			dialog_root.set_anchors_preset(Control.PRESET_TOP_WIDE)
			dialog_root.offset_top = 20
			dialog_root.offset_bottom = 370
		else:
			# Target is in top/middle, move dialog to bottom
			dialog_root.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
			dialog_root.offset_top = -500
			dialog_root.offset_bottom = -100
	else:
		# Default to bottom if no target
		dialog_root.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		dialog_root.offset_top = -500
		dialog_root.offset_bottom = -100
	
	dialog_root.visible = true
	_set_lumn_animation(emotion)
	
	# Typewriter Effect
	if _typewriter_tween and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
	
	var duration = text.length() * 0.03
	_typewriter_tween = create_tween()
	_typewriter_tween.tween_property(instruction_label, "visible_ratio", 1.0, duration)
	_typewriter_tween.tween_callback(func(): _set_lumn_animation("idle"))

func show_story_popup():
	overlay.visible = true
	dialog_root.visible = true
	story_button.visible = true
	
	current_target_node = null
	current_intro_index = 0
	_update_story_content()
	_set_lumn_animation("warning")

func _update_story_content():
	if not instruction_label or not story_button: return
	
	var text = INTRO_SCRIPT[current_intro_index]
	instruction_label.text = text
	instruction_label.visible_ratio = 0.0
	
	if _typewriter_tween and _typewriter_tween.is_valid():
		_typewriter_tween.kill()
	
	var duration = text.length() * 0.03
	_typewriter_tween = create_tween()
	_typewriter_tween.tween_property(instruction_label, "visible_ratio", 1.0, duration)
	
	if current_intro_index == INTRO_SCRIPT.size() - 1:
		story_button.text = "INITIALIZE"
	else:
		story_button.text = "NEXT"

func _on_story_button_pressed():
	if _typewriter_tween and _typewriter_tween.is_valid() and _typewriter_tween.is_running():
		_typewriter_tween.kill()
		instruction_label.visible_ratio = 1.0
		return

	# Only process intro logic if we are in the INTRO step
	if PlayerData.tutorial_step != Step.INTRO: return

	if current_intro_index < INTRO_SCRIPT.size() - 1:
		current_intro_index += 1
		_update_story_content()
	else:
		_on_story_start_pressed()

func _on_story_start_pressed():
	overlay.visible = false
	
	# If we are not in Periodic Table, go there
	if get_tree().current_scene.name != "PeriodicTable":
		if GlobalManager:
			GlobalManager.switch_scene("periodic_table")
	
	# Advance to step 1 (Select Lithium)
	advance_step()

func hide_tutorial():
	overlay.visible = false
	if dialog_root: dialog_root.visible = false
	current_target_node = null

func advance_step():
	PlayerData.tutorial_step += 1
	PlayerData.save_game()
	check_tutorial_progress()

func complete_tutorial():
	PlayerData.tutorial_step = Step.COMPLETE
	PlayerData.save_game()
	hide_tutorial()
	_show_completion_popup()

func _show_completion_popup():
	var popup = PanelContainer.new()
	popup.set_anchors_preset(Control.PRESET_CENTER)
	popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	popup.grow_vertical = Control.GROW_DIRECTION_BOTH
	popup.custom_minimum_size = Vector2(700, 450)
	popup.z_index = 100
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#010813")
	style.border_color = Color("#60fafc")
	style.set_border_width_all(4)
	style.set_corner_radius_all(16)
	popup.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	popup.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = "TUTORIAL COMPLETE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("#ffd700"))
	vbox.add_child(title)
	
	var desc = Label.new()
	desc.text = "You have synthesized your first element!\n\nExplore the Campaign to find more blueprints."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 40)
	desc.add_theme_color_override("font_color", Color("#60fafc"))
	vbox.add_child(desc)
	
	var btn = Button.new()
	btn.text = "CONTINUE"
	btn.custom_minimum_size = Vector2(0, 100)
	btn.add_theme_font_size_override("font_size", 48)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color("#60fafc")
	btn_style.set_corner_radius_all(8)
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_stylebox_override("hover", btn_style)
	btn.add_theme_stylebox_override("pressed", btn_style)
	var text_color = Color("#010813")
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_pressed_color", text_color)
	btn.add_theme_color_override("font_hover_color", text_color)
	btn.add_theme_color_override("font_focus_color", text_color)
	
	btn.pressed.connect(popup.queue_free)
	btn.pressed.connect(func(): _animate_button_press(btn))
	btn.resized.connect(func(): btn.pivot_offset = btn.size / 2)
	vbox.add_child(btn)
	
	add_child(popup)
	
	# Force center position based on viewport size
	popup.position = (get_viewport().get_visible_rect().size - popup.custom_minimum_size) / 2

func _start_bounce_animation():
	# Deprecated: Dialog is now fixed position
	pass

func _set_lumn_animation(anim_name: String):
	if lumn_sprite and lumn_sprite.sprite_frames:
		if lumn_sprite.sprite_frames.has_animation(anim_name):
			lumn_sprite.play(anim_name)
		else:
			lumn_sprite.play("idle")

func _find_nav_button(btn_name: String) -> Control:
	# 1. Try current scene (fallback)
	var scene = get_tree().current_scene
	var btn = scene.find_child(btn_name, true, false)
	if btn: return btn
	
	# 2. Try NavBar Autoload
	if has_node("/root/NavBar"):
		var navbar = get_node("/root/NavBar")
		btn = navbar.find_child(btn_name, true, false)
		if btn: return btn
		
	return null

func _animate_button_press(btn: Control):
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(btn, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_SINE)
