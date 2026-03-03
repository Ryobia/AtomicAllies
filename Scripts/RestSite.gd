extends Control

@export var icon_gem: Texture2D
@export var icon_energy: Texture2D

@onready var retreat_btn = find_child("RetreatButton", true, false)
@onready var continue_btn = find_child("ContinueButton", true, false)
@onready var monster_grid = find_child("MonsterGrid", true, false)
@onready var title_label = find_child("TitleLabel", true, false)
@onready var loot_label = find_child("LootLabel", true, false)
@onready var full_heal_btn = find_child("FullHealButton", true, false)

var monster_card_scene = preload("res://Scenes/TeamSlot.tscn") # Reusing TeamSlot for visuals
var _anim_cache: Dictionary = {} # Cache loaded animations
var _selected_swap_index: int = -1

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

func _on_retreat_pressed():
	if CampaignManager:
		# Bank rewards
		PlayerData.add_resource("binding_energy", CampaignManager.current_run_energy)
		CampaignManager.is_rogue_run = false
		CampaignManager.current_run_energy = 0
	GlobalManager.switch_scene("main_menu")

func _on_continue_pressed():
	if CampaignManager:
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
			current_hp = CampaignManager.run_team_state[monster]
		var max_hp = monster.get_current_stats().max_hp
		
		if current_hp > 0 and current_hp < max_hp:
			var cost = max(1, int(CampaignManager.current_run_energy * 0.1))
			if CampaignManager.current_run_energy >= cost:
				CampaignManager.current_run_energy -= cost
				CampaignManager.run_team_state[monster] = max_hp
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
		if CampaignManager and CampaignManager.run_team_state.has(m): chp = CampaignManager.run_team_state[m]
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
			current_hp = CampaignManager.run_team_state[monster]
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
		
		var anim_frames = _get_anim_frames(monster.monster_name)
		
		# Setup visual (reusing TeamSlot logic if available, or basic setup)
		if slot.has_method("setup"):
			slot.setup(monster, i, false, anim_frames)
		
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
			CampaignManager.run_team_state[monster] = max_hp
			print("Rest Site: Healed %s for %d energy" % [monster.monster_name, cost])
	_update_loot_label()
	_populate_monster_grid([monster])

func _revive_monster(monster: MonsterData):
	if PlayerData.spend_resource("gems", PlayerData.REVIVE_COST):
		if CampaignManager:
			var max_hp = monster.get_current_stats().max_hp
			CampaignManager.run_team_state[monster] = max_hp
			print("Rest Site: Revived ", monster.monster_name)
		_populate_monster_grid([monster])
	else:
		if title_label: title_label.text = "Not enough Gems!"

func _update_loot_label():
	if loot_label and CampaignManager:
		loot_label.text = "Current Loot: %d Binding Energy" % CampaignManager.current_run_energy

func _get_anim_frames(monster_name: String) -> SpriteFrames:
	if _anim_cache.has(monster_name): return _anim_cache[monster_name]
	
	var path = "res://Assets/Animations/" + monster_name.replace(" ", "") + ".tres"
	var frames = null
	if ResourceLoader.exists(path):
		frames = load(path)
	
	_anim_cache[monster_name] = frames
	return frames

func _flash_slot(slot: Control):
	var tween = create_tween()
	tween.tween_property(slot, "modulate", Color(0.5, 1.5, 0.5), 0.2) # Bright green
	tween.tween_property(slot, "modulate", Color.WHITE, 0.3)
