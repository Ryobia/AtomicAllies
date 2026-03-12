extends Control

# Signals to tell the Manager what the player wants to do
signal action_selected(action_type) # "attack", "swap", "synthesize"
signal target_selected(index) # 0-2
signal move_selected(move) # New signal for specific moves
signal cancel_targeting
signal inspect_unit(index, is_player) # New signal for long press
signal item_selected(item_id)
signal swap_selected(index)

# --- Resource Icons ---
@export var icon_energy: Texture2D
@export var icon_dust: Texture2D
@export var icon_gem: Texture2D

# --- UI References ---
# We use a flexible lookup to find slots so you can rearrange them in the editor
@onready var enemy_slots = [
	find_child("Enemy2", true, false),
	find_child("Enemy1", true, false),
	find_child("Enemy3", true, false)  # Flank (Right)
]

@onready var player_slots = [
	find_child("PlayerSlot2", true, false), # Vanguard (Center)
	find_child("PlayerSlot1", true, false), # Flank (Left)
	find_child("PlayerSlot3", true, false)  # Flank (Right)
]

@onready var stat_cards = [
	find_child("StatCard2", true, false), # Vanguard (Center)
	find_child("StatCard1", true, false), # Flank (Left)
	find_child("StatCard3", true, false)  # Flank (Right)
]

@onready var log_label = find_child("BattleLogLabel", true, false)
@onready var reaction_space = find_child("ReactionSpace", true, false)

@onready var action_buttons = [
	find_child("AttackButton", true, false),
	find_child("SwapButton", true, false),
	find_child("ItemButton", true, false)
]

@onready var move_container = find_child("MoveContainer", true, false)

@onready var back_btn = find_child("Quit", true, false)

# Cache for UI nodes to avoid find_child every frame
var _ui_cache = { "player": [], "enemy": [] }

# Input State
var _targeting_active: bool = false
var _valid_target_indices: Array = []
var _targeting_allies: bool = false

var _pressed_slot_index: int = -1
var _pressed_is_player: bool = false
var _press_timer: float = 0.0
var _long_press_triggered: bool = false
var _stat_popup_instance: Control = null

var bench_container: HBoxContainer
var _control_deck_grid: GridContainer = null
var _default_columns: int = 1
var _can_swap_state: bool = true

var stat_popup_scene = preload("res://Scenes/StatPopup.tscn")
var cooldowns: Dictionary = {}

func _ready():
	# Connect Control Deck Buttons
	_connect_btn("AttackButton", "attack")
	_connect_btn("SwapButton", "swap")
	_connect_btn("ItemButton", "item")
	
	if back_btn:
		if not back_btn.pressed.is_connected(_on_back_pressed):
			back_btn.pressed.connect(_on_back_pressed)

	if log_label:
		log_label.mouse_filter = MOUSE_FILTER_IGNORE
			
	# Ensure move container is hidden initially
	if move_container:
		move_container.visible = false
		# Check if parent is a GridContainer (ControlDeck)
		var parent = move_container.get_parent()
		if parent is GridContainer:
			_control_deck_grid = parent
			_default_columns = _control_deck_grid.columns
			# Ensure MoveContainer expands to fill the grid when active
			move_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			move_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
	# Hide action buttons initially
	for btn in action_buttons:
		if btn: btn.visible = false
		
	# Configure buttons for GridContainer layout
	for btn in action_buttons:
		if btn:
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
	# Connect target buttons on enemy slots
	for i in range(enemy_slots.size()):
		var slot = enemy_slots[i]
		_setup_slot_input(slot, i, false)
				
	# Connect target buttons on player slots (for Ally targeting)
	for i in range(player_slots.size()):
		var slot = player_slots[i]
		_setup_slot_input(slot, i, true)
		
	# Create Bench Container for Swap Moves
	bench_container = HBoxContainer.new()
	bench_container.name = "BenchContainer"
	bench_container.alignment = BoxContainer.ALIGNMENT_CENTER
	bench_container.add_theme_constant_override("separation", 20)
	bench_container.visible = false
	bench_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bench_container.position.y -= 580 # Offset above player row
	add_child(bench_container)
	
	_build_ui_cache()

func _process(delta):
	if _pressed_slot_index != -1:
		_press_timer += delta
		if _press_timer >= 0.5 and not _long_press_triggered: # 0.5s is usually enough for "long press" feel
			_long_press_triggered = true
			inspect_unit.emit(_pressed_slot_index, _pressed_is_player)
			# Reset press so we don't trigger again
			_pressed_slot_index = -1

func _setup_slot_input(slot: Control, index: int, is_player: bool):
	if not slot: return
	var btn = slot.find_child("TargetButton", true, false)
	if btn:
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.disabled = false # Always enabled to catch input
		
		# Input Handling
		btn.button_down.connect(func():
			_pressed_slot_index = index
			_pressed_is_player = is_player
			_press_timer = 0.0
			_long_press_triggered = false
		)
		
		btn.button_up.connect(func():
			_pressed_slot_index = -1
		)
		
		btn.pressed.connect(func():
			if _long_press_triggered: return # Ignore click if it was a long press
			
			# Handle Targeting Click
			if _targeting_active:
				# Check if this slot is a valid target
				if is_player == _targeting_allies and index in _valid_target_indices:
					target_selected.emit(index)
		)

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
			var hp_bar = player_slots[i].find_child("HPBar", true, false)
			if hp_bar: 
				hp_bar.show_percentage = false
				hp_bar.custom_minimum_size.y = 50
				hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_ui_cache.player[i]["slot_hp"] = hp_bar
			_ui_cache.player[i]["slot_hp_lbl"] = player_slots[i].find_child("HPLabel", true, false)
			_ui_cache.player[i]["status_container"] = player_slots[i].find_child("StatusContainer", true, false)
			
		if i < stat_cards.size() and stat_cards[i]:
			_ui_cache.player[i]["card_speed"] = stat_cards[i].find_child("SpeedBar", true, false)
			var card_hp = stat_cards[i].find_child("HPBar", true, false)
			if card_hp: 
				card_hp.show_percentage = false
				card_hp.custom_minimum_size.y = 50
				card_hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_ui_cache.player[i]["card_hp"] = card_hp
			_ui_cache.player[i]["card_hp_lbl"] = stat_cards[i].find_child("HPLabel", true, false)
			_ui_cache.player[i]["card_status_container"] = stat_cards[i].find_child("StatusContainer", true, false)
			
		# Enemy Cache
		if i < enemy_slots.size() and enemy_slots[i]:
			var enemy_hp = enemy_slots[i].find_child("HPBar", true, false)
			if enemy_hp: 
				enemy_hp.show_percentage = false
				enemy_hp.custom_minimum_size.y = 50
				enemy_hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_ui_cache.enemy[i]["hp"] = enemy_hp
			_ui_cache.enemy[i]["hp_lbl"] = enemy_slots[i].find_child("HPLabel", true, false)
			_ui_cache.enemy[i]["speed"] = enemy_slots[i].find_child("SpeedBar", true, false)
			_ui_cache.enemy[i]["status_container"] = enemy_slots[i].find_child("StatusContainer", true, false)

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
			# Update Stat Card
			var bar = _ui_cache.player[index].get("card_hp")
			if bar: 
				bar.max_value = max_hp
				bar.value = new_hp
				_update_hp_bar_style(bar, new_hp, max_hp)
			var lbl = _ui_cache.player[index].get("card_hp_lbl")
			if lbl:
				lbl.text = "%d/%d" % [int(new_hp), int(max_hp)]
				
			# Update Slot (Visual)
			var slot_bar = _ui_cache.player[index].get("slot_hp")
			if slot_bar:
				slot_bar.max_value = max_hp
				slot_bar.value = new_hp
				_update_hp_bar_style(slot_bar, new_hp, max_hp)
			var slot_lbl = _ui_cache.player[index].get("slot_hp_lbl")
			if slot_lbl:
				slot_lbl.text = "%d/%d" % [int(new_hp), int(max_hp)]
	else:
		if index < _ui_cache.enemy.size():
			var bar = _ui_cache.enemy[index].get("hp")
			if bar:
				bar.max_value = max_hp
				bar.value = new_hp
				_update_hp_bar_style(bar, new_hp, max_hp)
			var lbl = _ui_cache.enemy[index].get("hp_lbl")
			if lbl:
				lbl.text = "%d/%d" % [int(new_hp), int(max_hp)]

func update_shield(is_player: bool, index: int, shield: float, max_hp: float):
	var cache = _ui_cache.player if is_player else _ui_cache.enemy
	if index < cache.size():
		var hp_bar = cache[index].get("slot_hp") if is_player else cache[index].get("hp")
		# Also handle stat card for player
		var card_hp = cache[index].get("card_hp") if is_player else null
		
		if hp_bar: _update_single_shield_bar(hp_bar, shield, max_hp)
		if card_hp: _update_single_shield_bar(card_hp, shield, max_hp)

func _update_single_shield_bar(hp_bar: ProgressBar, shield: float, max_hp: float):
	var shield_bar = hp_bar.get_node_or_null("ShieldBar")
	if not shield_bar:
		shield_bar = ProgressBar.new()
		shield_bar.name = "ShieldBar"
		shield_bar.show_percentage = false
		shield_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# Style: Cyan overlay
		var style = StyleBoxFlat.new()
		style.bg_color = Color("#60fafc")
		style.bg_color.a = 0.6
		shield_bar.add_theme_stylebox_override("fill", style)
		shield_bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
		
		hp_bar.add_child(shield_bar)
		shield_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shield_bar.z_index = 1
	
	shield_bar.max_value = max_hp
	shield_bar.value = shield
	shield_bar.visible = (shield > 0)

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

func update_status_effects(is_player: bool, index: int, effects: Array):
	var cache = _ui_cache.player if is_player else _ui_cache.enemy
	if index >= cache.size(): return
	
	# Update Slot Container (On-field)
	var slot_container = cache[index].get("status_container")
	if slot_container:
		for child in slot_container.get_children():
			child.queue_free()
		for effect in effects:
			var icon = _create_status_icon(effect)
			if icon:
				slot_container.add_child(icon)
	
	# Update Card Container (Dashboard - Player Only)
	if is_player:
		var card_container = cache[index].get("card_status_container")
		if card_container:
			for child in card_container.get_children():
				child.queue_free()
			for effect in effects:
				var icon = _create_status_icon(effect)
				if icon:
					card_container.add_child(icon)

func _create_status_icon(effect: Dictionary) -> Control:
	var panel = PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var style = StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	
	var lbl = Label.new()
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color.BLACK)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var type = effect.get("type", "")
	if type == "":
		if effect.has("status"): type = "status"
		elif effect.has("stat"): type = "stat_mod"
		else: return null
	
	var bg_color = Color("#2ecc71") # Default Green (Buff)
	var text = "??"
	var tooltip_text = ""
	
	if type == "stat_mod":
		if effect.get("amount", 0) < 0:
			bg_color = Color("#ff4d4d") # Red (Debuff)
		text = effect.get("stat", "").substr(0, 3).to_upper()
		var sign = "+" if effect.get("amount", 0) > 0 else ""
		tooltip_text = "Stat: %s\nAmount: %s%d\nDuration: %d turns" % [effect.get("stat").capitalize(), sign, effect.get("amount"), effect.get("duration")]
	elif type == "status":
		var s = str(effect.get("status", "")).to_lower()
		if s == "": return null
		
		var is_debuff = effect.has("damage_multiplier") or s in ["poison", "stun", "silence_special", "vulnerable", "corrosion", "reactive_vapor", "radiation", "refracted", "insanity"]
		
		# Known Debuffs
		if is_debuff:
			bg_color = Color("#ff4d4d")
			tooltip_text = s.capitalize()
			if effect.has("damage_multiplier"):
				tooltip_text += "\nDamage Taken: x%.1f" % effect.get("damage_multiplier", 1.0)
			tooltip_text += "\nDuration: %d turns" % effect.get("duration", 0)
		# Known Buffs/Special
		elif s == "invulnerable":
			bg_color = Color("#ffd700") # Gold
			tooltip_text = "Invulnerable\nDuration: %d turns" % effect.get("duration", 0)
		elif s == "taunt":
			bg_color = Color("#ff9360") # Orange
			tooltip_text = "Taunting\nDuration: %d turns" % effect.get("duration", 0)
		elif s == "static_reflection":
			bg_color = Color("#60fafc") # Cyan
			tooltip_text = "Reflecting Damage\nDuration: %d turns" % effect.get("duration", 0)
		elif s == "physical_resist":
			bg_color = Color("#a0a0a0") # Silver/Grey
			tooltip_text = "Physical Resist\nDuration: %d turns" % effect.get("duration", 0)
		elif s == "mirror_coat":
			bg_color = Color("#e0e0e0") # Silver/White
			tooltip_text = "Reflecting Next Hit\nDuration: %d turns" % effect.get("duration", 0)
		elif s == "toxic_feedback":
			bg_color = Color("#6dc000") # Radioactive Green
			tooltip_text = "Toxic Feedback\nDuration: %d turns" % effect.get("duration", 0)
		elif s == "reflective_shell":
			bg_color = Color("#e0e0e0") # Silver/White
			tooltip_text = "Reflective Shell\nReflects 30% of next hit."
		elif s == "absorb_shield":
			bg_color = Color("#2ecc71") # Green
			var pct = int(float(effect.get("absorb_percent", 0.3)) * 100)
			tooltip_text = "Absorb Shield\nAbsorbs next hit, converting %d%% to HP." % pct
		elif s == "special_resist":
			bg_color = Color("#6495ed") # Cornflower Blue
			tooltip_text = "Special Resist\nDuration: %d turns" % effect.get("duration", 0)
		elif s == "regeneration":
			bg_color = Color("#2ecc71") # Green
			tooltip_text = "Regeneration\nHeals HP each turn.\nDuration: %d turns" % effect.get("duration", 0)
		
		if s == "marked_covalent": text = "COV"
		elif s == "unstable": text = "UNS"
		elif s == "carbonized": text = "CAR"
		elif s == "guarded": text = "GRD"
		elif s == "oxidized": text = "OXI"
		elif s == "explosive": text = "EXP"
		elif s == "physical_resist": text = "PHY"
		elif s == "toxic_feedback": text = "TFB"
		elif s == "mirror_coat": text = "MIR"
		elif s == "reflective_shell": text = "RSH"
		elif s == "absorb_shield": text = "ABS"
		elif s == "special_resist": text = "SPR"
		elif s == "regeneration": text = "REG"
		elif s == "overload": text = "OVL"
		elif s == "reactive_vapor": text = "VAP"
		elif s == "radiation": text = "RAD"
		elif s == "invulnerable": text = "INV"
		elif s == "taunt": text = "AGG"
		elif s == "poison": text = "POI"
		elif s == "stun": text = "STN"
		elif s == "insanity": text = "INS"
		elif s == "static_reflection": text = "RFL"
		else: text = s.substr(0, 3).to_upper()

	elif type == "swap_stats":
		bg_color = Color("#ff4d4d")
		text = "SWP"
		tooltip_text = "Stats Swapped\nDuration: %d turns" % effect.get("duration", 0)
	
	if text == "": text = "??"
		
	style.bg_color = bg_color
	lbl.text = text
	
	if tooltip_text != "":
		panel.tooltip_text = tooltip_text
	
	panel.add_theme_stylebox_override("panel", style)
	panel.add_child(lbl)
	return panel

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

func _update_hp_bar_style(bar: ProgressBar, current: float, max_val: float):
	var percent = 1.0
	if max_val > 0:
		percent = current / max_val
	
	var style = bar.get_theme_stylebox("fill")
	
	# Ensure unique stylebox
	if not bar.has_meta("hp_style_unique"):
		if style is StyleBoxFlat:
			style = style.duplicate()
		else:
			style = StyleBoxFlat.new()
			style.bg_color = Color("#2ecc71") # Default
		bar.add_theme_stylebox_override("fill", style)
		bar.set_meta("hp_style_unique", true)
	
	style = bar.get_theme_stylebox("fill")
	if not style is StyleBoxFlat: return

	# Color Transition
	if percent <= 0.25:
		style.bg_color = Color("#ff4d4d") # Red
	elif percent <= 0.5:
		style.bg_color = Color("#ffd700") # Gold
	else:
		style.bg_color = Color("#2ecc71") # Green

func highlight_active_unit(is_player: bool, index: int):
	var target_slots = player_slots if is_player else enemy_slots
	var active_slot = null
	if index >= 0 and index < target_slots.size():
		active_slot = target_slots[index]

	# Reset all slots to normal
	for slot in enemy_slots + player_slots:
		if slot:
			if slot.has_meta("active_tween"):
				var t = slot.get_meta("active_tween")
				if t and t.is_valid():
					t.kill()
			
			if slot == active_slot:
				continue
				
			var tween = create_tween()
			tween.tween_property(slot, "scale", Vector2.ONE, 0.2)
			tween.tween_property(slot, "modulate", Color.WHITE, 0.2)
			slot.z_index = 0
			
	# Highlight the active one
	if active_slot:
		active_slot.z_index = 10
		active_slot.modulate = Color(1.3, 1.3, 1.3)
		
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(active_slot, "scale", Vector2(1.15, 1.15), 0.8).from(Vector2(1.05, 1.05)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(active_slot, "scale", Vector2(1.05, 1.05), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		active_slot.set_meta("active_tween", tween)

func log_message(text: String):
	if reaction_space:
		# Clear previous messages to keep the space clean
		for child in reaction_space.get_children():
			child.queue_free()
			
		var panel = PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.set_anchors_preset(Control.PRESET_CENTER)
		panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		panel.grow_vertical = Control.GROW_DIRECTION_BOTH
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.85) # High contrast background
		style.border_width_top = 4
		style.border_width_bottom = 4
		style.border_color = Color("#60fafc") # Cyan accents
		style.set_corner_radius_all(12)
		style.content_margin_left = 40
		style.content_margin_right = 40
		style.content_margin_top = 15
		style.content_margin_bottom = 15
		panel.add_theme_stylebox_override("panel", style)
		
		var label = Label.new()
		label.text = text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 56)
		label.add_theme_color_override("font_color", Color("#ffd700")) # Gold text
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 16) # Thick outline
		
		panel.add_child(label)
		reaction_space.add_child(panel)
		
		# Animate entrance and exit
		panel.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(panel, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_interval(2.0)
		tween.tween_property(panel, "modulate:a", 0.0, 0.5)
		tween.tween_callback(panel.queue_free)
		return

	if log_label:
		log_label.text = text
		# Optional: Fade out effect
		log_label.modulate.a = 1.0
		var tween = create_tween()
		tween.tween_property(log_label, "modulate:a", 0.0, 2.0).set_delay(1.0)

func set_targeting_mode(enabled: bool, valid_indices: Array = [], target_allies: bool = false, bench_targets: Dictionary = {}):
	_targeting_active = enabled
	_valid_target_indices = valid_indices
	_targeting_allies = target_allies
	
	if not enabled:
		# Clear all indicators on both sides to be safe
		for slot in player_slots + enemy_slots:
			if slot:
				# var btn = slot.find_child("TargetButton", true, false)
				var indicator = slot.find_child("TargetIndicator", true, false)
				
				# if btn: btn.disabled = true # Don't disable anymore!
				if indicator: indicator.visible = false
				
				# Reset visual effect
				var tween = create_tween()
				tween.tween_property(slot, "modulate", Color.WHITE, 0.1)
		bench_container.visible = false
		return
		
	if not bench_targets.is_empty():
		show_bench_targets(bench_targets.data, bench_targets.indices)
	else:
		bench_container.visible = false

	var slots = player_slots if target_allies else enemy_slots
	
	for i in range(slots.size()):
		var slot = slots[i]
		if slot and slot.visible:
			var btn = slot.find_child("TargetButton", true, false)
			var indicator = slot.find_child("TargetIndicator", true, false) # e.g. a TextureRect with a reticle
			
			# Only enable if the mode is on AND this specific slot is a valid target
			var is_valid = enabled and (i in valid_indices)
			
			# if btn: btn.disabled = not is_valid # Don't disable anymore!
			
			if indicator:
				indicator.visible = is_valid
			
			# Optional: Add a visual effect to the whole slot
			var tween = create_tween()
			var color = Color(1.2, 1.2, 0.8) if is_valid else Color.WHITE
			tween.tween_property(slot, "modulate", color, 0.1)

func show_bench_targets(bench_data: Array, valid_indices: Array):
	bench_container.visible = true
	for child in bench_container.get_children():
		child.queue_free()
		
	for i in range(bench_data.size()):
		var data = bench_data[i]
		if not (i in valid_indices): continue
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(140, 140)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color("#010813")
		style.border_color = Color("#60fafc")
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		btn.add_theme_stylebox_override("normal", style)
		
		var hover = style.duplicate()
		hover.bg_color = Color("#0a1a2a")
		hover.border_color = Color("#ffd700")
		btn.add_theme_stylebox_override("hover", hover)
		btn.add_theme_stylebox_override("pressed", hover)
		
		var margin = MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(margin)
		
		var icon_rect = TextureRect.new()
		if data.icon: icon_rect.texture = data.icon
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		margin.add_child(icon_rect)
		
		# 10+ index signifies bench unit to BattleManager
		btn.pressed.connect(func(): target_selected.emit(10 + i))
		
		bench_container.add_child(btn)

func _set_slot_visual(slot: Control, monster: MonsterData, is_vanguard: bool = false):
	var icon_rect = slot.find_child("IconTexture", true, false)
	if not icon_rect: return

	# Fix layout collapse when texture is null
	if icon_rect:
		# Ensure it has a reasonable minimum size to push other elements down
		if icon_rect.custom_minimum_size.y < 150:
			icon_rect.custom_minimum_size = Vector2(max(icon_rect.custom_minimum_size.x, 150), 150)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	# Cleanup old container from previous fix attempt
	var old_center = icon_rect.find_child("SpriteCenter", false, false)
	if old_center: old_center.queue_free()

	# 1. Find or create a pivot control to center the sprite
	# We use a Control node anchored to the center (0.5, 0.5)
	var sprite_pivot = icon_rect.find_child("SpritePivot", false, false)
	if not sprite_pivot:
		sprite_pivot = Control.new()
		sprite_pivot.name = "SpritePivot"
		sprite_pivot.set_anchors_preset(Control.PRESET_CENTER)
		sprite_pivot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.add_child(sprite_pivot)

	# 2. Cleanup existing sprite from the pivot
	for child in sprite_pivot.get_children():
		child.queue_free()

	# 3. Reset static texture on the parent
	icon_rect.texture = null

	if monster:
		# 4. Try to load the animation resource
		var anim_name = monster.monster_name.replace(" ", "")
		if "animation_override" in monster and monster.animation_override != "":
			anim_name = monster.animation_override

		var anim_path = "res://Assets/Animations/" + anim_name + ".tres"
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

			sprite.z_index = 5 # Ensure sprite renders above health bars
			sprite.play(anim_to_play)

			var target_height = icon_rect.size.y
			if target_height <= 0:
				target_height = icon_rect.custom_minimum_size.y

			_scale_sprite_to_fit(sprite, target_height)
			sprite_pivot.add_child(sprite)
		elif monster.icon:
			# Fallback to static icon
			icon_rect.texture = monster.icon

	var shield = slot.find_child("VanguardShield", true, false)
	if shield:
		shield.visible = is_vanguard
		
	var name_lbl = slot.find_child("NameLabel", true, false)
	if name_lbl:
		name_lbl.text = monster.monster_name
		name_lbl.z_index = 6 # Ensure label is above sprite (z=5)
		name_lbl.visible = true
		
		var default_color = Color.WHITE
		if slot in enemy_slots:
			default_color = Color("#010813")
		_apply_mastery_border(name_lbl, monster, default_color)
		
	var stats = monster.get_current_stats()
	var hp_bar = slot.find_child("HPBar", true, false)
	if hp_bar:
		hp_bar.max_value = stats.max_hp
		hp_bar.value = stats.max_hp
		hp_bar.z_index = 6
		_update_hp_bar_style(hp_bar, stats.max_hp, stats.max_hp)
	var hp_lbl = slot.find_child("HPLabel", true, false)
	if hp_lbl:
		hp_lbl.text = "%d/%d" % [int(stats.max_hp), int(stats.max_hp)]
		hp_lbl.z_index = 6
		
	var speed_bar = slot.find_child("SpeedBar", true, false)
	if speed_bar:
		speed_bar.value = 0
		speed_bar.z_index = 6

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
	var hp_lbl = card.find_child("HPLabel", true, false)
	var stab_bar = card.find_child("StabilityBar", true, false)
	var speed_bar = card.find_child("SpeedBar", true, false)
	
	if name_lbl: 
		name_lbl.text = monster.monster_name
		_apply_mastery_border(name_lbl, monster, Color.WHITE)
		
	var stats = monster.get_current_stats()
	if hp_bar:
		hp_bar.max_value = stats.max_hp
		hp_bar.value = stats.max_hp
		_update_hp_bar_style(hp_bar, stats.max_hp, stats.max_hp)
	if hp_lbl:
		hp_lbl.text = "%d/%d" % [int(stats.max_hp), int(stats.max_hp)]
	if stab_bar:
		stab_bar.max_value = 100 # Or a value from monster data if it varies
		stab_bar.value = 100 # Start full
	if speed_bar:
		speed_bar.value = 0

func _apply_mastery_border(label: Label, monster: MonsterData, default_color: Color = Color.WHITE):
	if monster and monster.stability >= 100:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.5) # Semi-transparent background
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color("#ffd700") # Gold
		style.set_corner_radius_all(4)
		style.content_margin_left = 8
		style.content_margin_right = 8
		label.add_theme_stylebox_override("normal", style)
		label.add_theme_color_override("font_color", Color("#ffd700"))
	else:
		label.remove_theme_stylebox_override("normal")
		label.add_theme_color_override("font_color", default_color)

func _connect_btn(name: String, action: String):
	var btn = find_child(name, true, false)
	if btn:
		if not btn.pressed.is_connected(_emit_action):
			btn.pressed.connect(_emit_action.bind(action))

func _emit_action(action: String):
	action_selected.emit(action)

func _on_back_pressed():
	_show_quit_confirmation()

func _on_quit_confirmed():
	# This is called when the user clicks "OK" on the dialog
	GlobalManager.switch_scene("main_menu")

func show_moves(moves: Array, move_cooldowns: Dictionary = {}):
	# Hide main actions
	for btn in action_buttons:
		if btn: btn.visible = false
	if back_btn: back_btn.visible = false

	# Show move container
	if not move_container:
		print("BattleHUD Error: No 'MoveContainer' found to display moves.")
		return
		
	if move_container is GridContainer:
		move_container.columns = 2
		
	_toggle_grid_layout(true)
	move_container.visible = true
	
	# Clear old buttons
	for child in move_container.get_children():
		child.queue_free()
		
	# Create new buttons
	for move in moves:
		var btn = Button.new()

		if move_cooldowns.has(move.name):
			var turns_left = move_cooldowns[move.name]
			btn.text = "%s\n(Cooldown: %d)" % [move.name, turns_left]
			btn.disabled = true
			
			# Visual Cooldown Indicator (Progress Bar Overlay)
			var progress = ProgressBar.new()
			progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
			progress.set_anchors_preset(Control.PRESET_FULL_RECT)
			progress.show_percentage = false
			
			var bg_style = StyleBoxFlat.new()
			bg_style.bg_color = Color(0, 0, 0, 0.6) # Dark background for unavailable part
			
			var fill_style = StyleBoxFlat.new()
			fill_style.bg_color = Color("#60fafc") # Theme Cyan
			fill_style.bg_color.a = 0.25 # Semi-transparent
			
			progress.add_theme_stylebox_override("background", bg_style)
			progress.add_theme_stylebox_override("fill", fill_style)
			
			progress.max_value = float(move.cooldown)
			progress.value = float(move.cooldown - turns_left)
			
			btn.add_child(progress)
		else:
			var snipe_text = " [Snipe]" if move.is_snipe else ""
			btn.text = "%s%s\n(%d Pwr)" % [move.name, snipe_text, move.power]
			btn.pressed.connect(func(): _on_move_btn_pressed(move))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_style_button(btn)
		move_container.add_child(btn)
	var cancel_btn = Button.new()
	cancel_btn.text = "Back"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(cancel_btn)
	cancel_btn.pressed.connect(show_actions)
	move_container.add_child(cancel_btn)

func show_move_details(move: MoveData):
	if not move_container: return
	_toggle_grid_layout(true)
	move_container.visible = true
	
	if move_container is GridContainer:
		move_container.columns = 1
		
	
	for child in move_container.get_children():
		child.queue_free()
		
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	move_container.add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)
	
	var title = Label.new()
	var snipe_text = " [Snipe]" if move.is_snipe else ""
	title.text = "%s%s" % [move.name, snipe_text]
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("#60fafc"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var stats = Label.new()
	stats.text = "Type: %s  |  Power: %d  |  Acc: %d%%" % [move.type, move.power, move.accuracy]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 42)
	stats.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(stats)
	
	var desc = Label.new()
	desc.text = move.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_size_override("font_size", 42)
	desc.add_theme_color_override("font_color", Color("#cccccc"))
	vbox.add_child(desc)
	
	var btn = Button.new()
	btn.text = "Cancel"
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 80)
	_style_button(btn)
	btn.pressed.connect(func(): cancel_targeting.emit())
	vbox.add_child(btn)

func show_items(items: Dictionary):
	# Hide main actions
	for btn in action_buttons:
		if btn: btn.visible = false
	if back_btn: back_btn.visible = false

	if not move_container: return
	if move_container is GridContainer:
		move_container.columns = 1
		
	_toggle_grid_layout(true)
	move_container.visible = true
	
	for child in move_container.get_children():
		child.queue_free()
		
	for item_id in items:
		var count = items[item_id]
		var data = CombatManager.get_item_data(item_id)
		var btn = Button.new()
		btn.text = "%s (x%d)" % [data.name, count]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_style_button(btn)
		btn.pressed.connect(func(): item_selected.emit(item_id))
		move_container.add_child(btn)
		
	var cancel_btn = Button.new()
	cancel_btn.text = "Back"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(cancel_btn)
	cancel_btn.pressed.connect(show_actions)
	move_container.add_child(cancel_btn)

func show_actions():
	if move_container: move_container.visible = false
	_toggle_grid_layout(false)
	
	for btn in action_buttons:
		if btn: 
			btn.visible = true
			if btn.name == "SwapButton":
				btn.disabled = not _can_swap_state
				btn.modulate = Color(0.5, 0.5, 0.5, 1.0) if not _can_swap_state else Color.WHITE
				
	if back_btn: back_btn.visible = true

func set_swap_disabled(disabled: bool):
	_can_swap_state = !disabled
	for btn in action_buttons:
		if btn and btn.name == "SwapButton":
			btn.disabled = disabled
			btn.modulate = Color(0.5, 0.5, 0.5, 1.0) if disabled else Color.WHITE

func _on_move_btn_pressed(move):
	move_selected.emit(move)

func show_swap_options(monsters: Array, forced: bool = false):
	# Hide main actions
	for btn in action_buttons:
		if btn: btn.visible = false
	if back_btn: back_btn.visible = false
		
	# Show move container (reused for swap list)
	if not move_container: return
	_toggle_grid_layout(true)
	move_container.visible = true
	
	if move_container is GridContainer:
		move_container.columns = 1
		
	
	# Clear old buttons
	for child in move_container.get_children():
		child.queue_free()
		
	# Create buttons for benched monsters
	for i in range(monsters.size()):
		var data = monsters[i]
		var m = data.monster
		var is_dead = data.is_dead
		
		var btn = Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 100)
		_style_button(btn)
		
		var margin = MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_top", 5)
		margin.add_theme_constant_override("margin_bottom", 5)
		btn.add_child(margin)
		
		var hbox = HBoxContainer.new()
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_theme_constant_override("separation", 15)
		margin.add_child(hbox)
		
		var icon_con = Control.new()
		icon_con.custom_minimum_size = Vector2(80, 80)
		icon_con.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_con.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(icon_con)
		
		_load_monster_visual(icon_con, m)
		
		var lbl = Label.new()
		if is_dead:
			lbl.text = "%s (Fainted)" % [m.monster_name]
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.5, 0.8)
		else:
			lbl.text = "%s" % [m.monster_name]
			
		lbl.add_theme_font_size_override("font_size", 24)
		lbl.add_theme_color_override("font_color", Color("#010813"))
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(lbl)
		
		if not is_dead:
			btn.pressed.connect(func(): swap_selected.emit(i))
		move_container.add_child(btn)
		
	if not forced:
		# Cancel Button
		var cancel_btn = Button.new()
		cancel_btn.text = "Back"
		cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cancel_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cancel_btn.custom_minimum_size = Vector2(0, 80)
		_style_button(cancel_btn)
		cancel_btn.pressed.connect(show_actions)
		move_container.add_child(cancel_btn)

func _load_monster_visual(parent: Control, monster: MonsterData):
	if not monster: return
	
	var anim_path = "res://Assets/Animations/" + monster.monster_name.replace(" ", "") + ".tres"
	var anim_frames = null
	
	if ResourceLoader.exists(anim_path):
		anim_frames = load(anim_path)
		
	if anim_frames:
		var sprite = AnimatedSprite2D.new()
		sprite.sprite_frames = anim_frames
		
		var anim_to_play = "idle"
		if not anim_frames.has_animation(anim_to_play):
			if anim_frames.has_animation("default"):
				anim_to_play = "default"
			else:
				var anims = anim_frames.get_animation_names()
				if anims.size() > 0:
					anim_to_play = anims[0]
		
		sprite.play(anim_to_play)
		sprite.position = parent.custom_minimum_size / 2
		_scale_sprite_to_fit(sprite, parent.custom_minimum_size.y)
		parent.add_child(sprite)
	elif monster.icon:
		var tex_rect = TextureRect.new()
		tex_rect.texture = monster.icon
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		parent.add_child(tex_rect)

func _style_button(btn: Button):
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#60fafc")
	style.bg_color.a = 0.75
	style.border_color = Color("#010813")
	style.set_border_width_all(2)
	
	var hover_style = style.duplicate()
	hover_style.bg_color = style.bg_color.lightened(0.2)
	hover_style.bg_color.a = 0.9
	
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_color_override("font_color", Color("#010813"))
	btn.add_theme_font_size_override("font_size", 50)
	btn.add_theme_constant_override("outline_size", 3)
	btn.add_theme_color_override("font_outline_color", Color("#010813"))

func show_result(player_won: bool, rewards: Dictionary = {}):
	# Hide interaction buttons
	_toggle_grid_layout(false)
	if move_container: move_container.visible = false
	for btn in action_buttons:
		if btn: btn.visible = false
	if back_btn: back_btn.visible = false
	
	# Create a full-screen overlay
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP # Block clicks
	overlay.z_index = 200 # Ensure overlay is above everything (sprites use z=5-10, effects z=100)
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
		
		if rewards.has("binding_energy"):
			var total_be = rewards["binding_energy"]
			
			var row = HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 15)
			vbox.add_child(row)
			
			if icon_energy:
				var icon = TextureRect.new()
				icon.texture = icon_energy
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.custom_minimum_size = Vector2(50, 50)
				row.add_child(icon)
			
			var be_lbl = Label.new()
			be_lbl.text = "+0 Binding Energy"
			be_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			be_lbl.add_theme_font_size_override("font_size", 40)
			row.add_child(be_lbl)
			
			var tween = create_tween()
			tween.tween_method(func(val): be_lbl.text = "+%d Binding Energy" % int(val), 0, total_be, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		if rewards.has("neutron_dust"):
			var total_dust = rewards["neutron_dust"]
			
			var row = HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 15)
			vbox.add_child(row)
			
			if icon_dust:
				var icon = TextureRect.new()
				icon.texture = icon_dust
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.custom_minimum_size = Vector2(50, 50)
				row.add_child(icon)
			
			var dust_lbl = Label.new()
			dust_lbl.text = "+0 Neutron Dust"
			dust_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			dust_lbl.add_theme_font_size_override("font_size", 40)
			row.add_child(dust_lbl)
			
			var tween = create_tween()
			tween.tween_method(func(val): dust_lbl.text = "+%d Neutron Dust" % int(val), 0, total_dust, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			
		if rewards.has("gems"):
			var total_gems = rewards["gems"]
			
			var row = HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 15)
			vbox.add_child(row)
			
			if icon_gem:
				var icon = TextureRect.new()
				icon.texture = icon_gem
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.custom_minimum_size = Vector2(50, 50)
				row.add_child(icon)
			
			var gems_lbl = Label.new()
			gems_lbl.text = "+0 Gems"
			gems_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			gems_lbl.add_theme_font_size_override("font_size", 40)
			row.add_child(gems_lbl)
			
			var tween = create_tween()
			tween.tween_method(func(val): gems_lbl.text = "+%d Gems" % int(val), 0, total_gems, 1.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	var btn = Button.new()
	btn.text = "Continue"
	btn.custom_minimum_size = Vector2(250, 60)
	_style_button(btn) # Reuse your styling
	btn.pressed.connect(_on_quit_confirmed)
	vbox.add_child(btn)

func _toggle_grid_layout(is_move_view: bool):
	if _control_deck_grid:
		if is_move_view:
			_control_deck_grid.columns = 1
		else:
			_control_deck_grid.columns = _default_columns

func show_stat_popup(unit: BattleMonster):
	if _stat_popup_instance: _stat_popup_instance.queue_free()
	
	_stat_popup_instance = stat_popup_scene.instantiate()
	add_child(_stat_popup_instance)
	_stat_popup_instance.set_anchors_preset(Control.PRESET_CENTER)
	
	if _stat_popup_instance.has_method("setup"):
		_stat_popup_instance.setup(unit)
		
	_stat_popup_instance.tree_exited.connect(func():
		if TutorialManager and PlayerData.tutorial_step == TutorialManager.Step.CLOSE_INSPECT_ENEMY:
			TutorialManager.advance_step() # To BATTLE_RESUME
	)

func _show_quit_confirmation():
	var popup = PanelContainer.new()
	popup.set_anchors_preset(Control.PRESET_CENTER)
	popup.grow_horizontal = Control.GROW_DIRECTION_BOTH
	popup.grow_vertical = Control.GROW_DIRECTION_BOTH
	popup.custom_minimum_size = Vector2(600, 0)
	popup.z_index = 100
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#010813")
	style.border_color = Color("#60fafc")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	popup.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	popup.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 25)
	margin.add_child(vbox)
	
	var title = Label.new()
	title.text = "RETREAT?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("#ff4d4d"))
	vbox.add_child(title)
	
	var lbl = Label.new()
	lbl.text = "Are you sure you want to flee?\nAny progress in this battle will be lost."
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 32)
	vbox.add_child(lbl)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color("#60fafc")
	btn_style.set_corner_radius_all(8)
	
	var hover_style = btn_style.duplicate()
	hover_style.bg_color = Color("#a0fcfd")
	
	var confirm_btn = Button.new()
	confirm_btn.text = "Retreat"
	confirm_btn.custom_minimum_size = Vector2(200, 70)
	confirm_btn.add_theme_stylebox_override("normal", btn_style)
	confirm_btn.add_theme_stylebox_override("hover", hover_style)
	confirm_btn.add_theme_stylebox_override("pressed", btn_style)
	confirm_btn.add_theme_color_override("font_color", Color("#010813"))
	confirm_btn.add_theme_font_size_override("font_size", 36)
	confirm_btn.pressed.connect(func():
		_on_quit_confirmed()
		popup.queue_free()
	)
	hbox.add_child(confirm_btn)
	
	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(200, 70)
	cancel_btn.add_theme_stylebox_override("normal", btn_style)
	cancel_btn.add_theme_stylebox_override("hover", hover_style)
	cancel_btn.add_theme_stylebox_override("pressed", btn_style)
	cancel_btn.add_theme_color_override("font_color", Color("#010813"))
	cancel_btn.add_theme_font_size_override("font_size", 36)
	cancel_btn.pressed.connect(popup.queue_free)
	hbox.add_child(cancel_btn)
	
	add_child(popup)
