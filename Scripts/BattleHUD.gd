extends Control

# Signals to tell the Manager what the player wants to do
signal action_selected(action_type) # "attack", "swap", "synthesize"
signal target_selected(index) # 0-2
signal move_selected(move) # New signal for specific moves

# --- UI References ---
# We use a flexible lookup to find slots so you can rearrange them in the editor
@onready var enemy_slots = [
	find_child("EnemySlot1", true, false),
	find_child("EnemySlot2", true, false),
	find_child("EnemySlot3", true, false)
]

@onready var player_slots = [
	find_child("PlayerSlot1", true, false),
	find_child("PlayerSlot2", true, false),
	find_child("PlayerSlot3", true, false)
]

@onready var stat_cards = [
	find_child("StatCard1", true, false),
	find_child("StatCard2", true, false),
	find_child("StatCard3", true, false)
]

@onready var log_label = find_child("BattleLogLabel", true, false)

@onready var action_buttons = [
	find_child("AttackButton", true, false),
	find_child("SwapButton", true, false),
	find_child("SynthesizeButton", true, false)
]

@onready var move_container = find_child("MoveContainer", true, false)

func _ready():
	# Connect Control Deck Buttons
	_connect_btn("AttackButton", "attack")
	_connect_btn("SwapButton", "swap")
	_connect_btn("SynthesizeButton", "synthesize")
	
	# Connect Back Button
	var back_btn = find_child("BackButton", true, false)
	if back_btn:
		if not back_btn.pressed.is_connected(_on_back_pressed):
			back_btn.pressed.connect(_on_back_pressed)
			
	# Ensure move container is hidden initially
	if move_container:
		move_container.visible = false

func setup_ui(player_team: Array, enemy_team: Array):
	# 1. Setup Enemies (Top Row)
	for i in range(3):
		var slot = enemy_slots[i]
		if i < enemy_team.size() and enemy_team[i] != null:
			slot.visible = true
			_set_slot_visual(slot, enemy_team[i])
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
			_set_slot_visual(slot, monster)
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

func log_message(text: String):
	if log_label:
		log_label.text = text
		# Optional: Fade out effect
		log_label.modulate.a = 1.0
		var tween = create_tween()
		tween.tween_property(log_label, "modulate:a", 0.0, 2.0).set_delay(1.0)

func _set_slot_visual(slot: Control, monster: MonsterData):
	var icon = slot.find_child("IconTexture", true, false)
	if icon:
		icon.texture = monster.texture
		# Optional: Add DynamicAtom here if you want them spinning in battle!

func _set_stat_card(card: Control, monster: MonsterData):
	var name_lbl = card.find_child("NameLabel", true, false)
	var hp_bar = card.find_child("HPBar", true, false)
	var stab_bar = card.find_child("StabilityBar", true, false)
	
	if name_lbl: name_lbl.text = monster.monster_name
	if hp_bar:
		hp_bar.max_value = monster.base_health
		hp_bar.value = monster.base_health
	if stab_bar:
		stab_bar.max_value = 100
		stab_bar.value = 100 # Start full

func _connect_btn(name: String, action: String):
	var btn = find_child(name, true, false)
	if btn:
		if not btn.pressed.is_connected(_emit_action):
			btn.pressed.connect(_emit_action.bind(action))

func _emit_action(action: String):
	action_selected.emit(action)

func _on_back_pressed():
	GlobalManager.switch_scene("main_menu")

func show_moves(moves: Array):
	# Hide main actions
	for btn in action_buttons:
		if btn: btn.visible = false
		
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

func _on_move_btn_pressed(move):
	move_selected.emit(move)
