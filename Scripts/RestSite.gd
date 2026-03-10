extends Control

@export var icon_gem: Texture2D
@export var icon_energy: Texture2D
@export var icon_dust: Texture2D

@onready var retreat_btn = find_child("RetreatButton", true, false)
@onready var continue_btn = find_child("ContinueButton", true, false)
@onready var monster_grid = find_child("MonsterGrid", true, false)
@onready var title_label = find_child("TitleLabel", true, false)
@onready var loot_label = find_child("LootLabel", true, false)
@onready var full_heal_btn = find_child("FullHealButton", true, false)

var monster_card_scene = preload("res://Scenes/TeamSlot.tscn") # Reusing TeamSlot for visuals
var _anim_cache: Dictionary = {} # Cache loaded animations
var _selected_swap_index: int = -1
var _loot_container: HBoxContainer
var _reward_selection_container: Control

func _ready():
	if retreat_btn: retreat_btn.pressed.connect(_on_retreat_pressed)
	if continue_btn: continue_btn.pressed.connect(_on_continue_pressed)
	if full_heal_btn: full_heal_btn.pressed.connect(_on_full_heal_pressed)
	
	if monster_grid: 
		monster_grid.visible = true
		_populate_monster_grid()
	
	# Update title with wave info
	if title_label and CampaignManager:
		title_label.text = "Rest Site - Wave %d Complete" % (CampaignManager.current_run_wave - 1)
	_update_loot_label()
	
	# Find the container added in the editor
	_reward_selection_container = find_child("RewardContainer", true, false)
	
	_setup_reward_selection()
	
	# Trigger tutorial check
	if TutorialManager:
		TutorialManager.check_tutorial_progress()

func _on_retreat_pressed():
	if CampaignManager:
		# Bank rewards
		if CampaignManager.current_run_energy > 0: PlayerData.add_resource("binding_energy", CampaignManager.current_run_energy)
		if CampaignManager.current_run_dust > 0: PlayerData.add_resource("neutron_dust", CampaignManager.current_run_dust)
		if CampaignManager.current_run_gems > 0: PlayerData.add_resource("gems", CampaignManager.current_run_gems)
		CampaignManager.is_rogue_run = false
		CampaignManager.current_run_energy = 0
		CampaignManager.current_run_dust = 0
		CampaignManager.current_run_gems = 0
	GlobalManager.switch_scene("main_menu")

func _on_continue_pressed():
	if TutorialManager and PlayerData.tutorial_step == TutorialManager.Step.CONTINUE_RUN:
		TutorialManager.advance_step() # To COMPLETE_RUN (Wait for run finish)
		
	if CampaignManager:
		# Check for dead units in active slots (0-2) while living units exist in bench (3+)
		var roster = PlayerData.active_team
		if roster.is_empty(): roster = PlayerData.owned_monsters
		
		var dead_in_front = false
		var living_in_bench = false
		
		for i in range(roster.size()):
			var m = roster[i]
			if not m: continue
			
			var hp = m.get_current_stats().max_hp
			if CampaignManager.run_team_state.has(m):
				var state = CampaignManager.run_team_state[m]
				if typeof(state) == TYPE_INT: hp = state
				elif typeof(state) == TYPE_DICTIONARY: hp = state.get("hp", hp)
			
			if i < 3:
				if hp <= 0: dead_in_front = true
			else:
				if hp > 0: living_in_bench = true
		
		if dead_in_front and living_in_bench:
			if title_label:
				title_label.text = "Swap out fallen units!"
				var tween = create_tween()
				tween.tween_property(title_label, "modulate", Color.RED, 0.2)
				tween.tween_property(title_label, "modulate", Color.WHITE, 0.2)
			return

		CampaignManager.start_next_wave()

func _on_full_heal_pressed():
	if not CampaignManager: return
	
	var roster = PlayerData.active_team
	if roster.is_empty(): roster = PlayerData.owned_monsters
	
	var healed_monsters = []
	
	for monster in roster:
		if not monster: continue
		
		var current_hp = monster.get_current_stats().max_hp
		if CampaignManager.run_team_state.has(monster):
			var state = CampaignManager.run_team_state[monster]
			if typeof(state) == TYPE_INT: current_hp = state
			elif typeof(state) == TYPE_DICTIONARY: current_hp = state.get("hp", current_hp)
			
		var max_hp = monster.get_current_stats().max_hp
		
		if current_hp > 0 and current_hp < max_hp:
			var cost = max(1, int(CampaignManager.current_run_energy * 0.1))
			if CampaignManager.current_run_energy >= cost:
				CampaignManager.current_run_energy -= cost
				_update_monster_hp(monster, max_hp)
				healed_monsters.append(monster)
			else:
				break # Ran out of energy
	
	if not healed_monsters.is_empty():
		print("Rest Site: Full Heal performed.")
		_update_loot_label()
		_populate_monster_grid(healed_monsters)

func _populate_monster_grid(flashing_monsters: Array = []):
	if not monster_grid: return
	
	# Clear previous children to prevent duplicates if called multiple times
	for child in monster_grid.get_children():
		child.queue_free()
	
	# Get the roster used in the run
	var roster = PlayerData.active_team
	if roster.is_empty(): roster = PlayerData.owned_monsters
	
	# Calculate Full Heal Cost for button update
	var full_heal_cost = 0
	var sim_energy = 0
	if CampaignManager: sim_energy = CampaignManager.current_run_energy
	
	for m in roster:
		if not m: continue
		var chp = m.get_current_stats().max_hp
		if CampaignManager and CampaignManager.run_team_state.has(m):
			var state = CampaignManager.run_team_state[m]
			if typeof(state) == TYPE_INT: chp = state
			elif typeof(state) == TYPE_DICTIONARY: chp = state.get("hp", chp)
		if chp > 0 and chp < m.get_current_stats().max_hp:
			var c = max(1, int(sim_energy * 0.1))
			if sim_energy >= c:
				full_heal_cost += c
				sim_energy -= c
	
	if full_heal_btn:
		full_heal_btn.text = "Full Heal (%d)" % full_heal_cost
		full_heal_btn.disabled = (full_heal_cost == 0)
	
	for i in range(roster.size()):
		var monster = roster[i]
		if not monster: continue
		
		var current_hp = monster.get_current_stats().max_hp
		if CampaignManager.run_team_state.has(monster):
			var state = CampaignManager.run_team_state[monster]
			if typeof(state) == TYPE_INT: current_hp = state
			elif typeof(state) == TYPE_DICTIONARY: current_hp = state.get("hp", current_hp)
		var max_hp = monster.get_current_stats().max_hp
			
		var is_dead = (current_hp <= 0)
		
		# Create a container for the slot to stack items vertically
		var container = VBoxContainer.new()
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		monster_grid.add_child(container)
		
		# Action Button (Heal or Revive)
		if is_dead:
			var rev_btn = Button.new()
			rev_btn.text = "Revive (%d)" % PlayerData.REVIVE_COST
			rev_btn.icon = icon_gem
			rev_btn.expand_icon = true
			rev_btn.add_theme_color_override("font_color", Color("#ffd700"))
			rev_btn.add_theme_font_size_override("font_size", 40)
			rev_btn.custom_minimum_size.y = 60
			rev_btn.pressed.connect(func(): _revive_monster(monster))
			rev_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			container.add_child(rev_btn)
		elif current_hp < max_hp:
			var cost = max(1, int(CampaignManager.current_run_energy * 0.1))
			var heal_btn = Button.new()
			heal_btn.text = "Heal (%d)" % cost
			heal_btn.icon = icon_energy
			heal_btn.expand_icon = true
			heal_btn.add_theme_color_override("font_color", Color("#60fafc"))
			heal_btn.add_theme_font_size_override("font_size", 40)
			heal_btn.custom_minimum_size.y = 60
			heal_btn.pressed.connect(func(): _heal_monster(monster, cost))
			heal_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if CampaignManager.current_run_energy < cost:
				heal_btn.disabled = true
			container.add_child(heal_btn)
		else:
			var spacer = Control.new()
			spacer.custom_minimum_size.y = 31
			container.add_child(spacer)
		
		var slot = monster_card_scene.instantiate()
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.custom_minimum_size = Vector2(0, 250)
		container.add_child(slot)
		
		var anim_frames = _get_anim_frames(monster)
		
		# Setup visual (reusing TeamSlot logic if available, or basic setup)
		if slot.has_method("setup"):
			slot.setup(monster, i, false, anim_frames)
			
		# Add gold border for 100% stability
		if monster.stability >= 100:
			var panel_style = slot.get_theme_stylebox("panel", "PanelContainer")
			if panel_style:
				var mastery_style = panel_style.duplicate()
				mastery_style.border_width_left = 4
				mastery_style.border_width_top = 4
				mastery_style.border_width_right = 4
				mastery_style.border_width_bottom = 4
				mastery_style.border_color = Color("#ffd700") # Gold
				slot.add_theme_stylebox_override("panel", mastery_style)
		
		# Allow clicking to swap
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.focus_mode = Control.FOCUS_NONE
		slot.gui_input.connect(_on_slot_gui_input.bind(i))
		
		# Visual feedback for selection
		if i == _selected_swap_index:
			slot.modulate = Color(1.3, 1.3, 1.1) # Highlight
			var border = ReferenceRect.new()
			border.name = "SelectionBorder"
			border.border_color = Color("#ffd700")
			border.border_width = 4.0
			border.editor_only = false
			border.set_anchors_preset(Control.PRESET_FULL_RECT)
			border.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(border)
		
		var hp_lbl = Label.new()
		hp_lbl.text = "%d/%d HP" % [current_hp, max_hp]
		hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_lbl.add_theme_color_override("font_color", Color.GREEN if current_hp > 0 else Color.RED)
		hp_lbl.add_theme_font_size_override("font_size", 40)
		hp_lbl.add_theme_constant_override("outline_size", 4)
		hp_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		container.add_child(hp_lbl)
		
		if monster in flashing_monsters:
			_flash_slot(slot)

func _on_slot_gui_input(event, index):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_slot_clicked(index)

func _on_slot_clicked(index: int):
	if _selected_swap_index == -1:
		_selected_swap_index = index
		_populate_monster_grid()
	elif _selected_swap_index == index:
		_selected_swap_index = -1
		_populate_monster_grid()
	else:
		# Swap
		var roster = PlayerData.active_team
		if roster.is_empty(): roster = PlayerData.owned_monsters
		
		var temp = roster[index]
		roster[index] = roster[_selected_swap_index]
		roster[_selected_swap_index] = temp
		
		_selected_swap_index = -1
		_populate_monster_grid()

func _heal_monster(monster: MonsterData, cost: int):
	if CampaignManager:
		if CampaignManager.current_run_energy >= cost:
			CampaignManager.current_run_energy -= cost
			var max_hp = monster.get_current_stats().max_hp
			_update_monster_hp(monster, max_hp)
			print("Rest Site: Healed %s for %d energy" % [monster.monster_name, cost])
	_update_loot_label()
	_populate_monster_grid([monster])

func _revive_monster(monster: MonsterData):
	_show_gem_confirmation("Revive Unit", PlayerData.REVIVE_COST, func():
		if PlayerData.spend_resource("gems", PlayerData.REVIVE_COST):
			if CampaignManager:
				var max_hp = monster.get_current_stats().max_hp
				_update_monster_hp(monster, max_hp)
				print("Rest Site: Revived ", monster.monster_name)
			_populate_monster_grid([monster])
		else:
			if title_label: title_label.text = "Not enough Gems!"
	)

func _update_loot_label():
	if not loot_label or not CampaignManager: return
	
	loot_label.visible = false
	
	if not _loot_container:
		_loot_container = HBoxContainer.new()
		_loot_container.name = "LootContainer"
		_loot_container.alignment = BoxContainer.ALIGNMENT_CENTER
		_loot_container.add_theme_constant_override("separation", 20)
		
		var parent = loot_label.get_parent()
		if parent:
			parent.add_child(_loot_container)
			if parent is Container:
				parent.move_child(_loot_container, loot_label.get_index())
			else:
				# Copy positioning if not in a container
				_loot_container.set_anchors_preset(Control.PRESET_CENTER_TOP)
				_loot_container.position = loot_label.position
				_loot_container.size = Vector2(loot_label.size.x, 50)
				_loot_container.anchor_left = loot_label.anchor_left
				_loot_container.anchor_right = loot_label.anchor_right
				_loot_container.anchor_top = loot_label.anchor_top
				_loot_container.anchor_bottom = loot_label.anchor_bottom
				_loot_container.offset_left = loot_label.offset_left
				_loot_container.offset_top = loot_label.offset_top
				_loot_container.offset_right = loot_label.offset_right
				_loot_container.offset_bottom = loot_label.offset_bottom
	
	for child in _loot_container.get_children():
		child.queue_free()
		
	var title = Label.new()
	title.text = "Current Loot:"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color.WHITE)
	_loot_container.add_child(title)
	
	_add_loot_item(_loot_container, CampaignManager.current_run_energy, icon_energy)
	
	if CampaignManager.current_run_dust > 0:
		_add_loot_item(_loot_container, CampaignManager.current_run_dust, icon_dust)
	if CampaignManager.current_run_gems > 0:
		_add_loot_item(_loot_container, CampaignManager.current_run_gems, icon_gem)

func _add_loot_item(container: Control, amount: int, icon: Texture2D):
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 5)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	if icon:
		var tex = TextureRect.new()
		tex.texture = icon
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = Vector2(60, 60)
		hbox.add_child(tex)
		
	var lbl = Label.new()
	lbl.text = str(amount)
	lbl.add_theme_font_size_override("font_size", 56)
	lbl.add_theme_color_override("font_color", Color("#60fafc"))
	hbox.add_child(lbl)
	container.add_child(hbox)

func _get_anim_frames(monster: MonsterData) -> SpriteFrames:
	if _anim_cache.has(monster.monster_name): return _anim_cache[monster.monster_name]
	
	var anim_name = monster.monster_name.replace(" ", "")
	if "animation_override" in monster and monster.animation_override != "":
		anim_name = monster.animation_override
		
	var path = "res://Assets/Animations/" + anim_name + ".tres"
	var frames = null
	if ResourceLoader.exists(path):
		frames = load(path)
	
	_anim_cache[monster.monster_name] = frames
	return frames

func _flash_slot(slot: Control):
	var tween = create_tween()
	tween.tween_property(slot, "modulate", Color(0.5, 1.5, 0.5), 0.2) # Bright green
	tween.tween_property(slot, "modulate", Color.WHITE, 0.3)

func _setup_reward_selection():
	if not _reward_selection_container:
	
		print("RestSite Error: RewardContainer not found.")
		return
		
	_reward_selection_container.visible = true
	
	# Clear any placeholder children
	for child in _reward_selection_container.get_children():
		child.queue_free()
	
	# Options Container
	var options_hbox = HBoxContainer.new()
	options_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	options_hbox.add_theme_constant_override("separation", 30)
	options_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reward_selection_container.add_child(options_hbox)
	
	var rewards = _generate_rewards()
	
	for reward in rewards:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(280, 350)
		
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color("#010813")
		btn_style.border_color = Color("#60fafc")
		btn_style.set_border_width_all(3)
		btn_style.set_corner_radius_all(12)
		btn.add_theme_stylebox_override("normal", btn_style)
		
		var hover_style = btn_style.duplicate()
		hover_style.bg_color = Color("#0a1a2a")
		hover_style.border_color = Color("#ffd700") # Gold on hover
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", hover_style)
		
		var margin = MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left", 15)
		margin.add_theme_constant_override("margin_right", 15)
		margin.add_theme_constant_override("margin_top", 15)
		margin.add_theme_constant_override("margin_bottom", 15)
		btn.add_child(margin)
		
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		margin.add_child(vbox)
		
		var lbl = Label.new()
		lbl.text = reward.name
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 42)
		lbl.add_theme_color_override("font_color", Color("#60fafc"))
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		vbox.add_child(lbl)
		
		var desc = Label.new()
		desc.text = reward.desc
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 28)
		desc.add_theme_color_override("font_color", Color("#e0e0e0"))
		vbox.add_child(desc)
		
		btn.pressed.connect(func(): _select_reward(reward))
		options_hbox.add_child(btn)

func _generate_rewards() -> Array:
	var pool = [
		{ "type": "resource", "id": "neutron_dust", "amount": 200, "name": "Dust Cache", "desc": "+200 Neutron Dust" },
		{ "type": "resource", "id": "binding_energy", "amount": 100, "name": "Energy Cell", "desc": "+100 Binding Energy" },
		{ "type": "item", "id": "repair_nanites", "amount": 1, "name": "Nanites", "desc": "Get 1 Repair Nanite" },
		{ "type": "item", "id": "adrenaline_shot", "amount": 1, "name": "Adrenaline", "desc": "Get 1 Adrenaline Shot" },
		{ "type": "heal", "amount": 0.3, "name": "Field Repairs", "desc": "Heal Team 30%" },
		{ "type": "item", "id": "coolant_gel", "amount": 1, "name": "Coolant Gel", "desc": "Get 1 Coolant Gel" },
	]
	
	pool.shuffle()
	return pool.slice(0, 3)

func _select_reward(reward: Dictionary):
	if reward.type == "resource":
		if CampaignManager:
			if reward.id == "neutron_dust": CampaignManager.current_run_dust += reward.amount
			elif reward.id == "binding_energy": CampaignManager.current_run_energy += reward.amount
			elif reward.id == "gems": CampaignManager.current_run_gems += reward.amount
	elif reward.type == "item":
		PlayerData.add_item(reward.id, reward.amount)
	elif reward.type == "heal":
		var roster = PlayerData.active_team
		if roster.is_empty(): roster = PlayerData.owned_monsters
		for m in roster:
			if m:
				var max_hp = m.get_current_stats().max_hp
				var current = max_hp
				if CampaignManager and CampaignManager.run_team_state.has(m):
					var state = CampaignManager.run_team_state[m]
					if typeof(state) == TYPE_INT: current = state
					elif typeof(state) == TYPE_DICTIONARY: current = state.get("hp", current)
				
				if current > 0: # Don't revive
					var heal_amt = int(max_hp * reward.amount)
					var new_hp = min(max_hp, current + heal_amt)
					if CampaignManager:
						_update_monster_hp(m, new_hp)
		_populate_monster_grid()

	_update_loot_label()
	
	# Hide selection
	if _reward_selection_container:
		_reward_selection_container.visible = false
		
	if TutorialManager and PlayerData.tutorial_step == TutorialManager.Step.SELECT_REWARD:
		TutorialManager.advance_step() # To EXPLAIN_HEAL

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

func _update_monster_hp(monster: MonsterData, new_hp: int):
	if not CampaignManager: return
	var state = CampaignManager.run_team_state.get(monster, {})
	if typeof(state) == TYPE_INT:
		state = { "hp": new_hp, "stats": {} }
	elif typeof(state) == TYPE_DICTIONARY:
		state["hp"] = new_hp
	CampaignManager.run_team_state[monster] = state
