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
	find_child("EnemySlot2", true, false), # Vanguard (Middle)
	find_child("EnemySlot1", true, false), # Flank (Left)
	find_child("EnemySlot3", true, false)  # Flank (Right)
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

@onready var back_btn = find_child("BackButton", true, false)
@onready var quit_dialog = find_child("QuitConfirmationDialog", true, false)

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
		if index < stat_cards.size():
			var bar = stat_cards[index].find_child("HPBar", true, false)
			if bar: bar.value = new_hp
	else:
		# Enemy HP bars are usually smaller/hidden or on the slot itself
		if index < enemy_slots.size():
			var bar = enemy_slots[index].find_child("HPBar", true, false)
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
	if icon and monster.icon:
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

func _set_stat_card(card: Control, monster: MonsterData):
	var name_lbl = card.find_child("NameLabel", true, false)
	var hp_bar = card.find_child("HPBar", true, false)
	var stab_bar = card.find_child("StabilityBar", true, false)
	
	if name_lbl: name_lbl.text = monster.monster_name
	var stats = monster.get_current_stats()
	if hp_bar:
		hp_bar.max_value = stats.max_hp
		hp_bar.value = stats.max_hp
	if stab_bar:
		stab_bar.max_value = 100 # Or a value from monster data if it varies
		stab_bar.value = 100 # Start full

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
		btn.pressed.connect(func(): _on_move_btn_pressed(move))
		move_container.add_child(btn)
		
	# Cancel Button
	var cancel_btn = Button.new()
	cancel_btn.text = "Back"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		btn.pressed.connect(func(): swap_selected.emit(i))
		move_container.add_child(btn)
		
	# Cancel Button
	var cancel_btn = Button.new()
	cancel_btn.text = "Back"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.pressed.connect(show_actions)
	move_container.add_child(cancel_btn)
