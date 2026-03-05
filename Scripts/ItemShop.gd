extends Control

@onready var grid = find_child("ShopGrid", true, false)
@onready var back_btn = find_child("BackButton", true, false)

# Define the items available in the shop
const SHOP_ITEMS = [
	{
		"id": "coolant_gel",
		"name": "Coolant Gel",
		"description": "Instantly reduces fatigue timer by 10 minutes.",
		"cost": 100,
		"currency": "neutron_dust",
		"category": "Fusion"
	},
	{
		"id": "magnetic_stabilizer",
		"name": "Magnetic Stabilizer",
		"description": "Increases fusion success rate by 10% for one reaction.",
		"cost": 250,
		"currency": "neutron_dust",
		"category": "Fusion"
	},
	{
		"id": "quantum_catalyst",
		"name": "Quantum Catalyst",
		"description": "Increases fusion success rate by 25% for one reaction.",
		"cost": 500,
		"currency": "neutron_dust",
		"category": "Fusion"
	},
	{
		"id": "repair_nanites",
		"name": "Repair Nanites",
		"description": "Restores 50% HP to a unit during combat.",
		"cost": 200,
		"currency": "neutron_dust",
		"category": "Battle"
	},
	{
		"id": "adrenaline_shot",
		"name": "Adrenaline Shot",
		"description": "Increases Attack by 20% for 3 turns.",
		"cost": 150,
		"currency": "neutron_dust",
		"category": "Battle"
	},
	{
		"id": "emergency_shield",
		"name": "Emergency Shield",
		"description": "Grants a shield absorbing damage equal to 30% Max HP.",
		"cost": 300,
		"currency": "neutron_dust",
		"category": "Battle"
	},
	# Ship Upgrades
	{
		"id": "fusion_speed",
		"name": "Catalytic Injectors",
		"description": "Reduces fusion time by 10% per level.",
		"base_cost": 500,
		"cost_scale": 1.5,
		"max_level": 5,
		"currency": "neutron_dust",
		"category": "Ship Upgrades",
		"is_upgrade": true
	},
	{
		"id": "dust_efficiency",
		"name": "Dust Siphon",
		"description": "Increases Neutron Dust gain from failed fusions by 10% per level.",
		"base_cost": 300,
		"cost_scale": 1.3,
		"max_level": 10,
		"currency": "neutron_dust",
		"category": "Ship Upgrades",
		"is_upgrade": true
	},
	{
		"id": "scanner_range",
		"name": "Isotope Scanner",
		"description": "Increases chance of higher stability results by 2% per level.",
		"base_cost": 750,
		"cost_scale": 1.4,
		"max_level": 5,
		"currency": "neutron_dust",
		"category": "Ship Upgrades",
		"is_upgrade": true
	},
	{
		"id": "combat_hull",
		"name": "Nanoweave Hull",
		"description": "Increases Max HP of all units by 5% per level.",
		"base_cost": 1000,
		"cost_scale": 1.5,
		"max_level": 5,
		"currency": "neutron_dust",
		"category": "Ship Upgrades",
		"is_upgrade": true
	},
	{
		"id": "combat_optics",
		"name": "Targeting Optics",
		"description": "Increases Attack of all units by 5% per level.",
		"base_cost": 1000,
		"cost_scale": 1.5,
		"max_level": 5,
		"currency": "neutron_dust",
		"category": "Ship Upgrades",
		"is_upgrade": true
	},
	{
		"id": "combat_shielding",
		"name": "Phase Shielding",
		"description": "Increases Defense of all units by 5% per level.",
		"base_cost": 1000,
		"cost_scale": 1.5,
		"max_level": 5,
		"currency": "neutron_dust",
		"category": "Ship Upgrades",
		"is_upgrade": true
	}
]

func _ready():
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	_populate_shop()

func _populate_shop():
	if not grid: return
	
	for child in grid.get_children():
		child.queue_free()
		
	var categories = {}
	for item in SHOP_ITEMS:
		var cat = item.get("category", "Other")
		if not categories.has(cat):
			categories[cat] = []
		categories[cat].append(item)
	
	var order = ["Ship Upgrades", "Fusion", "Battle", "Other"]
	for cat in order:
		if categories.has(cat):
			_create_category_section(cat, categories[cat])

func _create_category_section(name: String, items: Array):
	var header = Label.new()
	header.text = name
	header.add_theme_font_size_override("font_size", 56)
	header.add_theme_color_override("font_color", Color("#ffd700"))
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_child(header)
	
	var section_grid = GridContainer.new()
	section_grid.columns = 2
	section_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section_grid.add_theme_constant_override("h_separation", 20)
	section_grid.add_theme_constant_override("v_separation", 20)
	section_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	grid.add_child(section_grid)
	
	for item in items:
		_create_item_card(item, section_grid)

func _create_item_card(item: Dictionary, parent_grid: Control):
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 320)
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#010813")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color("#60fafc")
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(vbox)
	
	# Name
	var name_lbl = Label.new()
	name_lbl.text = item.name
	name_lbl.add_theme_font_size_override("font_size", 48)
	name_lbl.add_theme_color_override("font_color", Color("#60fafc"))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)
	
	# Description
	var desc_lbl = Label.new()
	desc_lbl.text = item.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_font_size_override("font_size", 28)
	desc_lbl.add_theme_color_override("font_color", Color("#cccccc"))
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_lbl)
	
	# Owned Count / Level
	var status_lbl = Label.new()
	var current_level = 0
	var is_maxed = false
	var cost = item.get("cost", 0)
	
	if item.get("is_upgrade", false):
		current_level = PlayerData.get_upgrade_level(item.id)
		is_maxed = current_level >= item.max_level
		cost = int(item.base_cost * pow(item.cost_scale, current_level))
		status_lbl.text = "Level: %d / %d" % [current_level, item.max_level]
	else:
		var owned_count = PlayerData.get_item_count(item.id)
		status_lbl.text = "Owned: %d" % owned_count
		
	status_lbl.add_theme_font_size_override("font_size", 28)
	status_lbl.add_theme_color_override("font_color", Color("#ffd700"))
	status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(status_lbl)
	
	# Buy Button
	var btn = Button.new()
	var currency_label = "Dust"
	if item.currency == "gems": currency_label = "Gems"
	elif item.currency == "binding_energy": currency_label = "Energy"
	
	if is_maxed:
		btn.text = "MAXED"
		btn.disabled = true
	else:
		if item.get("is_upgrade", false):
			btn.text = "Upgrade (%d %s)" % [cost, currency_label]
		else:
			btn.text = "Buy (%d %s)" % [cost, currency_label]
			
	btn.add_theme_font_size_override("font_size", 32)
	btn.custom_minimum_size.y = 70
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color("#60fafc")
	btn_style.bg_color.a = 0.2
	btn_style.border_width_left = 1
	btn_style.border_width_top = 1
	btn_style.border_width_right = 1
	btn_style.border_width_bottom = 1
	btn_style.border_color = Color("#60fafc")
	btn.add_theme_stylebox_override("normal", btn_style)
	
	btn.pressed.connect(func(): _on_buy_pressed(item, status_lbl, btn))
	vbox.add_child(btn)
	
	parent_grid.add_child(panel)

func _on_buy_pressed(item: Dictionary, status_lbl: Label, btn: Button):
	if item.get("is_upgrade", false):
		var current_level = PlayerData.get_upgrade_level(item.id)
		var cost = int(item.base_cost * pow(item.cost_scale, current_level))
		
		if PlayerData.purchase_ship_upgrade(item.id, cost):
			var new_level = PlayerData.get_upgrade_level(item.id)
			status_lbl.text = "Level: %d / %d" % [new_level, item.max_level]
			
			# Visual feedback
			var tween = create_tween()
			tween.tween_property(status_lbl, "scale", Vector2(1.2, 1.2), 0.1)
			tween.tween_property(status_lbl, "scale", Vector2.ONE, 0.1)
			
			if new_level >= item.max_level:
				btn.text = "MAXED"
				btn.disabled = true
			else:
				var next_cost = int(item.base_cost * pow(item.cost_scale, new_level))
				var currency_label = "Dust"
				if item.currency == "gems": currency_label = "Gems"
				elif item.currency == "binding_energy": currency_label = "Energy"
				btn.text = "Upgrade (%d %s)" % [next_cost, currency_label]
		else:
			_show_not_enough_funds(status_lbl, "Level: %d / %d" % [current_level, item.max_level])
	else:
		if PlayerData.spend_resource(item.currency, item.cost):
			PlayerData.add_item(item.id, 1)
			var new_count = PlayerData.get_item_count(item.id)
			status_lbl.text = "Owned: %d" % new_count
			
			# Visual feedback
			var tween = create_tween()
			tween.tween_property(status_lbl, "scale", Vector2(1.2, 1.2), 0.1)
			tween.tween_property(status_lbl, "scale", Vector2.ONE, 0.1)
		else:
			_show_not_enough_funds(status_lbl, "Owned: %d" % PlayerData.get_item_count(item.id))

func _show_not_enough_funds(lbl: Label, original_text: String):
	var original_color = lbl.get_theme_color("font_color")
	lbl.text = "Not enough Dust!"
	lbl.add_theme_color_override("font_color", Color("#ff4d4d"))
	
	var tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_callback(func():
		lbl.text = original_text
		lbl.add_theme_color_override("font_color", original_color)
	)

func _on_back_pressed():
	GlobalManager.switch_scene("main_menu")
