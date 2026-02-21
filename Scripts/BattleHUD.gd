extends Control

# Signals to tell the Manager what the player wants to do
signal action_selected(action_type) # "attack", "swap", "synthesize"
signal target_selected(index) # 0-2
signal move_selected(move) # New signal for specific moves
signal cancel_targeting
signal swap_selected(index)

# --- UI References ---
# We use a flexible lookup to find slots so you can rearrange them in the editor
@onready var enemy_slots = [
	find_child("Enemy2", true, false), # Vanguard (Middle)
	find_child("Enemy1", true, false), # Flank (Left)
	find_child("Enemy3", true, false)  # Flank (Right)
]

@onready var player_slots = [
	find_child("PlayerSlot2", true, false), # Vanguard (Middle)
	find_child("PlayerSlot1", true, false), # Flank (Left)
	find_child("PlayerSlot3", true, false)  # Flank (Right)
]

@onready var stat_cards = [
	find_child("StatCard2", true, false), # Vanguard (Middle)
	find_child("StatCard1", true, false), # Flank (Left)
	find_child("StatCard3", true, false)  # Flank (Right)
]

@onready var log_label = find_child("BattleLogLabel", true, false)

@onready var action_buttons = [
	find_child("AttackButton", true, false),
	find_child("SwapButton", true, false),
	find_child("SynthesizeButton", true, false)
]

@onready var move_container = find_child("MoveContainer", true, false)

@onready var back_btn = find_child("Quit", true, false)
@onready var quit_dialog = find_child("QuitConfirmationDialog", true, false)

# Cache for UI nodes to avoid find_child every frame
var _ui_cache = { "player": [], "enemy": [] }

func _ready():
	# Connect Control Deck Buttons
	_connect_btn("AttackButton", "attack")
	_connect_btn("SwapButton", "swap")
	_connect_btn("SynthesizeButton", "synthesize")
	
	if back_btn:
		if not back_btn.pressed.is_connected(_on_back_pressed):
			back_btn.pressed.connect(_on_back_pressed)

	if log_label:
		log_label.mouse_filter = MOUSE_FILTER_IGNORE
			
	if quit_dialog:
		quit_dialog.confirmed.connect(_on_quit_confirmed)

	# Ensure move container is hidden initially
	if move_container:
		move_container.visible = false
		
	# Hide action buttons initially
	for btn in action_buttons:
		if btn: btn.visible = false
		
	# Connect target buttons on enemy slots
	for i in range(enemy_slots.size()):
		var slot = enemy_slots[i]
		if slot:
			# Assumes each slot has a Button child named "TargetButton"
			var btn = slot.find_child("TargetButton", true, false)
			if btn:
				# Ensure the button covers the entire slot and intercepts clicks
				btn.set_anchors_preset(Control.PRESET_FULL_RECT)
				btn.mouse_filter = Control.MOUSE_FILTER_STOP
				btn.pressed.connect(func(): target_selected.emit(i))
	
	_build_ui_cache()

func _unhandled_input(event):
	# Universal cancel action (Esc key or right mouse button)
	# We emit this signal, and the BattleManager will decide if it's in a state to act on it.
	if event.is_action_pressed("ui_cancel"):
		cancel_targeting.emit()

func _gui_input(event: InputEvent):
	# For mobile, tapping the background should also cancel targeting.
	# This works because buttons and other interactive elements will consume
	# the input event, preventing it from reaching here.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		cancel_targeting.emit()

func _build_ui_cache():
	# Pre-fetch all bars and labels so we don't use find_child in _process
	for i in range(3):
		_ui_cache.player.append({})
		_ui_cache.enemy.append({})
		
		# Player Cache
		if i < player_slots.size() and player_slots[i]:
			_ui_cache.player[i]["slot_speed"] = player_slots[i].find_child("SpeedBar", true, false)
			_ui_cache.player[i]["slot_hp"] = player_slots[i].find_child("HPBar", true, false)
			
		if i < stat_cards.size() and stat_cards[i]:
			_ui_cache.player[i]["card_speed"] = stat_cards[i].find_child("SpeedBar", true, false)
			_ui_cache.player[i]["card_hp"] = stat_cards[i].find_child("HPBar", true, false)
			
		# Enemy Cache
		if i < enemy_slots.size() and enemy_slots[i]:
			_ui_cache.enemy[i]["hp"] = enemy_slots[i].find_child("HPBar", true, false)
			_ui_cache.enemy[i]["speed"] = enemy_slots[i].find_child("SpeedBar", true, false)

func setup_ui(player_team: Array, enemy_team: Array):
	# 1. Setup Enemies (Top Row)
	for i in range(3):
		var slot = enemy_slots[i]
		if i < enemy_team.size() and enemy_team[i] != null:
			slot.visible = true
			_set_slot_visual(slot, enemy_team[i], i == 0)
		else:
			slot.visible = false

	# 2. Setup Players (Bottom Row & Dashboard)
	for i in range(3):
		var slot = player_slots[i]
		var card = stat_cards[i]
		
		if i < player_team.size() and player_team[i] != null:
			slot.visible = true
			card.visible = true
			
			var monster = player_team[i]
			_set_slot_visual(slot, monster, i == 0)
			_set_stat_card(card, monster)
		else:
			slot.visible = false
			card.visible = false

func update_hp(is_player: bool, index: int, new_hp: float, max_hp: float):
	if is_player:
		if index < _ui_cache.player.size():
			var bar = _ui_cache.player[index].get("card_hp")
			if bar: 
				bar.max_value = max_hp
				bar.value = new_hp
	else:
		if index < _ui_cache.enemy.size():
			var bar = _ui_cache.enemy[index].get("hp")
			if bar:
				bar.max_value = max_hp
				bar.value = new_hp

func update_stability(is_player: bool, index: int, new_stability: float, max_stability: float = 100.0):
	var slots = player_slots if is_player else enemy_slots
	if index < slots.size():
		# Assuming stability bar is on the main slot for both player and enemy
		var bar = slots[index].find_child("StabilityBar", true, false)
		if bar:
			bar.max_value = max_stability
			bar.value = new_stability

func update_speed_bar(is_player: bool, index: int, value: float, max_value: float = 100.0):
	var is_full = value >= max_value
	
	if is_player:
		if index < _ui_cache.player.size():
			var cache = _ui_cache.player[index]
			if cache.get("slot_speed"):
				_update_single_bar(cache["slot_speed"], value, max_value, is_full)
			if cache.get("card_speed"):
				_update_single_bar(cache["card_speed"], value, max_value, is_full)
	else:
		if index < _ui_cache.enemy.size():
			var bar = _ui_cache.enemy[index].get("speed")
			if bar:
				_update_single_bar(bar, value, max_value, is_full)

func _update_single_bar(bar: ProgressBar, value: float, max_val: float, is_full: bool):
	bar.max_value = max_val
	bar.value = value
	_update_bar_style(bar, is_full)

func _update_bar_style(bar: ProgressBar, is_full: bool):
	var style = bar.get_theme_stylebox("fill")
	
	# Ensure the stylebox is unique to this instance to prevent sharing issues
	if not bar.has_meta("style_unique"):
		if style is StyleBoxFlat:
			style = style.duplicate()
		else:
			style = StyleBoxFlat.new()
		bar.add_theme_stylebox_override("fill", style)
		bar.set_meta("style_unique", true)
	
	# Refresh reference to the (now unique) override
	style = bar.get_theme_stylebox("fill")
	
	if not style is StyleBoxFlat:
		return

	if is_full:
		if not bar.has_meta("pulsing") or not bar.get_meta("pulsing"):
			bar.set_meta("pulsing", true)
			_start_pulse_tween(bar, style)
	else:
		if bar.has_meta("pulsing") and bar.get_meta("pulsing"):
			bar.set_meta("pulsing", false)
			if bar.has_meta("pulse_tween"):
				var t = bar.get_meta("pulse_tween")
				if t and t.is_valid():
					t.kill()
			style.bg_color = Color("#ff9360")
		elif style.bg_color != Color("#ff9360"):
			style.bg_color = Color("#ff9360")

func _start_pulse_tween(bar: ProgressBar, style: StyleBoxFlat):
	var tween = bar.create_tween()
	tween.set_loops()
	tween.tween_property(style, "bg_color", Color("#fff5cc"), 0.5).from(Color("#ffd700"))
	tween.tween_property(style, "bg_color", Color("#ffd700"), 0.5)
	bar.set_meta("pulse_tween", tween)

func highlight_active_unit(is_player: bool, index: int):
	# Reset all slots to normal
	for slot in enemy_slots + player_slots:
		if slot:
			var tween = create_tween()
			tween.tween_property(slot, "scale", Vector2.ONE, 0.2)
			tween.tween_property(slot, "modulate", Color.WHITE, 0.2)
			slot.z_index = 0
			
	# Highlight the active one
	var target_slots = player_slots if is_player else enemy_slots
	if index >= 0 and index < target_slots.size():
		var slot = target_slots[index]
		if slot:
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(slot, "scale", Vector2(1.1, 1.1), 0.2)
			tween.tween_property(slot, "modulate", Color(1.2, 1.2, 1.2), 0.2)
			slot.z_index = 10

func log_message(text: String):
	if log_label:
		log_label.text = text
		# Optional: Fade out effect
		log_label.modulate.a = 1.0
		var tween = create_tween()
		tween.tween_property(log_label, "modulate:a", 0.0, 2.0).set_delay(1.0)

func set_targeting_mode(enabled: bool, valid_indices: Array = []):
	for i in range(enemy_slots.size()):
		var slot = enemy_slots[i]
		if slot and slot.visible:
			var btn = slot.find_child("TargetButton", true, false)
			var indicator = slot.find_child("TargetIndicator", true, false) # e.g. a TextureRect with a reticle
			
			# Only enable if the mode is on AND this specific slot is a valid target
			var is_valid = enabled and (i in valid_indices)
			
			if btn:
				btn.disabled = not is_valid
			if indicator:
				indicator.visible = is_valid
			
			# Optional: Add a visual effect to the whole slot
			var tween = create_tween()
			var color = Color(1.2, 1.2, 0.8) if is_valid else Color.WHITE
			tween.tween_property(slot, "modulate", color, 0.1)

func _set_slot_visual(slot: Control, monster: MonsterData, is_vanguard: bool = false):
	var icon = slot.find_child("IconTexture", true, false)
	
	# 1. Cleanup existing animation if we are refreshing the slot
	if icon:
		for child in icon.get_children():
			if child.name.begins_with("UIAnimSprite"):
				icon.remove_child(child)
				child.queue_free()
	
	# 2. Reset static texture
	if icon: icon.texture = null

	if icon and monster:
		# 3. Try to load the animation resource
		var anim_path = "res://Assets/Animations/" + monster.monster_name.replace(" ", "") + ".tres"
		var anim_frames = null
		
		if ResourceLoader.exists(anim_path):
			anim_frames = load(anim_path)
		else:
			print("BattleHUD: Animation NOT found at: ", anim_path)
			
		if anim_frames:
			# Create an AnimatedSprite2D for the UI
			var sprite = AnimatedSprite2D.new()
			sprite.name = "UIAnimSprite"
			sprite.sprite_frames = anim_frames
			
			# Robust animation playing: Check for 'idle', then 'default', then first available
			var anim_to_play = "idle"
			if not anim_frames.has_animation(anim_to_play):
				if anim_frames.has_animation("default"):
					anim_to_play = "default"
				else:
					var anims = anim_frames.get_animation_names()
					if anims.size() > 0:
						anim_to_play = anims[0]
			
			sprite.play(anim_to_play)
			sprite.position = icon.size / 2 # Center it
			_scale_sprite_to_fit(sprite, icon.size.y)
			icon.add_child(sprite)
		elif monster.icon:
			# Fallback to static icon
			icon.texture = monster.icon
	
	var shield = slot.find_child("VanguardShield", true, false)
	if shield:
		shield.visible = is_vanguard
		
	var name_lbl = slot.find_child("NameLabel", true, false)
	if name_lbl:
		name_lbl.text = monster.monster_name
		
	var stats = monster.get_current_stats()
	var hp_bar = slot.find_child("HPBar", true, false)
	if hp_bar:
		hp_bar.max_value = stats.max_hp
		hp_bar.value = stats.max_hp
		
	var speed_bar = slot.find_child("SpeedBar", true, false)
	if speed_bar:
		speed_bar.value = 0

func _scale_sprite_to_fit(sprite: AnimatedSprite2D, target_height: float):
	# Helper to ensure the sprite fits in the UI slot
	if target_height <= 0: target_height = 150.0 # Default fallback
	
	var anim = sprite.animation
	if not sprite.sprite_frames.has_animation(anim):
		return

	var tex = sprite.sprite_frames.get_frame_texture(anim, 0)
	if tex:
		var s = target_height / float(tex.get_height())
		sprite.scale = Vector2(s, s)

func _set_stat_card(card: Control, monster: MonsterData):
	var name_lbl = card.find_child("NameLabel", true, false)
	var hp_bar = card.find_child("HPBar", true, false)
	var stab_bar = card.find_child("StabilityBar", true, false)
	var speed_bar = card.find_child("SpeedBar", true, false)
	
	if name_lbl: name_lbl.text = monster.monster_name
	var stats = monster.get_current_stats()
	if hp_bar:
		hp_bar.max_value = stats.max_hp
		hp_bar.value = stats.max_hp
	if stab_bar:
		stab_bar.max_value = 100 # Or a value from monster data if it varies
		stab_bar.value = 100 # Start full
	if speed_bar:
		speed_bar.value = 0

func _connect_btn(name: String, action: String):
	var btn = find_child(name, true, false)
	if btn:
		if not btn.pressed.is_connected(_emit_action):
			btn.pressed.connect(_emit_action.bind(action))

func _emit_action(action: String):
	action_selected.emit(action)

func _on_back_pressed():
	if quit_dialog:
		quit_dialog.popup_centered()
	else:
		# Fallback if no dialog is found
		print("No quit dialog found, returning to main menu directly.")
		GlobalManager.switch_scene("main_menu")

func _on_quit_confirmed():
	# This is called when the user clicks "OK" on the dialog
	GlobalManager.switch_scene("main_menu")

func show_moves(moves: Array):
	# Hide main actions
	for btn in action_buttons:
		if btn: btn.visible = false
	if back_btn: back_btn.visible = false

	# Show move container
	if not move_container:
		print("BattleHUD Error: No 'MoveContainer' found to display moves.")
		return
		
	move_container.visible = true
	
	# Clear old buttons
	for child in move_container.get_children():
		child.queue_free()
		
	# Create new buttons
	for move in moves:
		var btn = Button.new()
		btn.text = "%s\n(%d Pwr)" % [move.name, move.power]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_style_button(btn)
		btn.pressed.connect(func(): _on_move_btn_pressed(move))
		move_container.add_child(btn)
		
	# Cancel Button
	var cancel_btn = Button.new()
	cancel_btn.text = "Back"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(cancel_btn)
	cancel_btn.pressed.connect(show_actions)
	move_container.add_child(cancel_btn)

func show_actions():
	if move_container: move_container.visible = false
	for btn in action_buttons:
		if btn: btn.visible = true
	if back_btn: back_btn.visible = true

func _on_move_btn_pressed(move):
	move_selected.emit(move)

func show_swap_options(monsters: Array):
	# Hide main actions
	for btn in action_buttons:
		if btn: btn.visible = false
	if back_btn: back_btn.visible = false
		
	# Show move container (reused for swap list)
	if not move_container: return
	move_container.visible = true
	
	# Clear old buttons
	for child in move_container.get_children():
		child.queue_free()
		
	# Create buttons for benched monsters
	for i in range(monsters.size()):
		var m = monsters[i]
		var btn = Button.new()
		btn.text = "Swap to %s (Lv. %d)" % [m.monster_name, m.level]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_style_button(btn)
		btn.pressed.connect(func(): swap_selected.emit(i))
		move_container.add_child(btn)
		
	# Cancel Button
	var cancel_btn = Button.new()
	cancel_btn.text = "Back"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(cancel_btn)
	cancel_btn.pressed.connect(show_actions)
	move_container.add_child(cancel_btn)

func _style_button(btn: Button):
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#60fafc")
	style.bg_color.a = 0.75
	
	var hover_style = style.duplicate()
	hover_style.bg_color = style.bg_color.lightened(0.2)
	hover_style.bg_color.a = 0.9
	
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_color_override("font_color", Color("#010813"))
	btn.add_theme_font_size_override("font_size", 40)

func show_result(player_won: bool, rewards: Dictionary = {}):
	# Hide interaction buttons
	if move_container: move_container.visible = false
	for btn in action_buttons:
		if btn: btn.visible = false
	if back_btn: back_btn.visible = false
	
	# Create a full-screen overlay
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP # Block clicks
	add_child(overlay)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)
	center.add_child(vbox)
	
	var label = Label.new()
	label.text = "VICTORY!" if player_won else "DEFEAT..."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 80)
	label.add_theme_color_override("font_color", Color("#ffd700") if player_won else Color("#ff4d4d"))
	vbox.add_child(label)
	
	# Display Rewards
	if player_won and not rewards.is_empty():
		var reward_header = Label.new()
		reward_header.text = "REWARDS"
		reward_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		reward_header.add_theme_font_size_override("font_size", 30)
		reward_header.add_theme_color_override("font_color", Color("#60fafc"))
		vbox.add_child(reward_header)
		
		if rewards.has("xp"):
			var xp_lbl = Label.new()
			xp_lbl.text = "+%d XP" % rewards["xp"]
			xp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			xp_lbl.add_theme_font_size_override("font_size", 50)
			vbox.add_child(xp_lbl)
	
	var btn = Button.new()
	btn.text = "Continue"
	btn.custom_minimum_size = Vector2(250, 60)
	_style_button(btn) # Reuse your styling
	btn.pressed.connect(_on_quit_confirmed)
	vbox.add_child(btn)
