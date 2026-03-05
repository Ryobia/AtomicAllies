extends Control

@onready var topic_list = find_child("TopicList", true, false)
@onready var content_label = find_child("ContentLabel", true, false)
@onready var content_title = find_child("ContentTitle", true, false)
@onready var back_btn = find_child("BackButton", true, false)
@onready var content_panel = find_child("ContentPanel", true, false)
@onready var close_content_btn = find_child("CloseContentButton", true, false)

var details_container: VBoxContainer

const LORE = [
	{
		"title": "The Void",
		"text": "The Void is not merely an enemy; it is the absence of existence. An entropic force that seeks to unravel the atomic bonds that hold the universe together.\n\nIt manifests in three primary forms:\n\n• Null-Walkers: Mindless drones of static and smoke.\n• Molecular Shredders: Jagged constructs that target unstable elements.\n• Abyssal Weavers: Commanders that warp the laws of physics.\n\nAs the Architect, your duty is to synthesize stable matter to push back this encroaching nothingness.",
		"race_keyword": "Null"
	},
	{
		"title": "The Brood",
		"text": "A biological swarm that consumes all organic and inorganic matter to fuel its endless reproduction. Brood units rely on overwhelming numbers and rapid regeneration.\n\n• Grunts: Fast, swarming biters.\n• Assassins: Inject neurotoxins to paralyze prey.\n• Commanders: Emit pheromones to frenzy the hive.\n\nBeware their ability to call for reinforcements if not exterminated quickly.",
		"race_keyword": "Brood"
	},
	{
		"title": "The Chaos Glitch",
		"text": "An anomaly in the fabric of reality. These entities appear as corrupted data or pixelated horrors. Their attacks are unpredictable, often shuffling your team or altering stats at random.\n\n• Grunts: Unstable code fragments.\n• Assassins: Glitch through defenses to strike critical points.\n• Kings: Can shatter reality itself, dealing massive damage with low accuracy.",
		"race_keyword": "Chaos"
	},
	{
		"title": "Fission Core",
		"text": "Living nuclear reactors. These enemies are highly volatile and radioactive. They boast immense firepower but are often unstable, damaging themselves to unleash devastating attacks.\n\n• Grunts: Leaking radiation drones.\n• Brutes: Lead-shielded tanks that absorb damage.\n• Kings: Walking meltdowns that irradiate the entire battlefield.",
		"race_keyword": "Fission"
	},
	{
		"title": "Eldritch Horrors",
		"text": "Beings from beyond the known dimensions. They assault the mind rather than the body, inflicting madness and status ailments.\n\n• Grunts: Psychic leeches.\n• Commanders: Warp the perception of your units, causing them to attack allies or miss turns.\n• Kings: Induce cosmic horror, shattering the will to fight.",
		"race_keyword": "Eldritch"
	},
	{
		"title": "Alkali Metals",
		"text": "Group 1: The Spark of Life.\n\nHighly reactive and volatile, Alkali Metals (Lithium, Sodium, Potassium...) are the vanguard of any reaction. In combat, they act as 'Glass Cannons'—striking with immense speed and ignoring enemy defenses, but crumbling under pressure. Their instability is their weapon.",
		"group": AtomicConfig.Group.ALKALI_METAL
	},
	{
		"title": "Alkaline Earth Metals",
		"text": "Group 2: The Foundation.\n\nStable and resilient, these elements (Beryllium, Magnesium, Calcium...) form the bedrock of reality. They function as 'Tanks', absorbing punishment and building up defenses over time. They are the shield that protects the volatile spark of the Alkalis.",
		"group": AtomicConfig.Group.ALKALINE_EARTH
	},
	{
		"title": "Transition Metals",
		"text": "Groups 3-12: The Industrial Engine.\n\nVersatile and durable, Transition Metals (Iron, Copper, Gold...) are the workhorses of the periodic table. They serve as 'Bruisers', balancing offense and defense. Their conductive nature allows them to strike multiple times in rapid succession.",
		"group": AtomicConfig.Group.TRANSITION_METAL
	},
	{
		"title": "Post-Transition Metals",
		"text": "Groups 13-16: The Malleable Support.\n\nSofter than their transition cousins but highly useful. Elements like Aluminum and Tin serve as 'Utility' supports, enhancing the capabilities of their allies through buffs and structural reinforcement.",
		"group": AtomicConfig.Group.POST_TRANSITION
	},
	{
		"title": "Metalloids",
		"text": "The Borderline.\n\nExisting between metals and nonmetals, Metalloids (Silicon, Arsenic...) are masters of disruption. They act as 'Controllers', scrambling enemy signals and swapping stats to turn an opponent's strength into weakness.",
		"group": AtomicConfig.Group.METALLOID
	},
	{
		"title": "Nonmetals",
		"text": "The Breath of Cosmos.\n\nEssential for life and reaction. Nonmetals (Carbon, Nitrogen, Oxygen...) are 'Combo Primers'. Individually weak, they catalyze devastating chain reactions when paired with other elements, spreading chaos through enemy ranks.",
		"group": AtomicConfig.Group.NONMETAL
	},
	{
		"title": "Halogens",
		"text": "Group 17: The Corrosive Edge.\n\nOne electron away from perfection, Halogens (Fluorine, Chlorine...) are aggressively reactive. They serve as 'Assailants', inflicting potent damage-over-time effects and stripping away enemy resilience.",
		"group": AtomicConfig.Group.HALOGEN
	},
	{
		"title": "Noble Gases",
		"text": "Group 18: The Perfect Form.\n\nWith full electron shells, Noble Gases (Helium, Neon, Argon...) want for nothing. They are 'Pure Walls', virtually immune to chemical reactions. In battle, they provide impenetrable defense and passive regeneration.",
		"group": AtomicConfig.Group.NOBLE_GAS
	},
	{
		"title": "Lanthanides",
		"text": "The Rare Earths.\n\nHidden within the table, these elements possess unique magnetic and luminescent properties. They act as 'Enhancers', absorbing the strength of fallen foes to empower the entire team.",
		"group": AtomicConfig.Group.LANTHANIDE
	},
	{
		"title": "Actinides",
		"text": "The Nuclear Option.\n\nHeavy, unstable, and immensely powerful. Actinides (Uranium, Plutonium...) are 'Nukes'. They boast the highest raw stats but suffer from radioactive decay, losing health over time to fuel their devastating attacks.",
		"group": AtomicConfig.Group.ACTINIDE
	}
]

func _ready():
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	
	if close_content_btn:
		close_content_btn.pressed.connect(_on_close_content_pressed)
		
	if content_panel:
		content_panel.visible = false
		
	# Setup Details Container inside ScrollContainer
	if content_label:
		var parent = content_label.get_parent()
		if parent is VBoxContainer:
			details_container = parent
		else:
			parent.remove_child(content_label)
			details_container = VBoxContainer.new()
			details_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			details_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
			details_container.add_theme_constant_override("separation", 20)
			parent.add_child(details_container)
			details_container.add_child(content_label)
		
	if content_label:
		content_label.add_theme_font_size_override("normal_font_size", 40)
		
	if content_title:
		content_title.add_theme_font_size_override("font_size", 56)
		
	_populate_list()

func _populate_list():
	if not topic_list: return
	
	for child in topic_list.get_children():
		child.queue_free()
		
	for entry in LORE:
		# Filter: Only show enemies/lore (entries without a 'group' property)
		if entry.has("group"): continue
		
		var is_unlocked = false
		
		if entry.has("race_keyword"):
			if _has_seen_race(entry.race_keyword):
				is_unlocked = true
		elif entry.has("group"):
			# Check if player has discovered any element of this group
			var group = entry.group
			if PlayerData.class_resonance.get(group, 0) > 0:
				is_unlocked = true
		else:
			is_unlocked = true # Default unlocked
			
		var btn = Button.new()
		btn.text = entry.title if is_unlocked else "???"
		btn.disabled = not is_unlocked
		
		btn.custom_minimum_size = Vector2(0, 120)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		# Style
		btn.add_theme_font_size_override("font_size", 48)
		btn.add_theme_color_override("font_color", Color("#60fafc"))
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.1, 0.5)
		style.border_width_bottom = 1
		style.border_color = Color("#60fafc")
		style.content_margin_left = 20
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		
		if not is_unlocked:
			btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
			btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))
		
		if is_unlocked:
			btn.pressed.connect(func(): _show_content(entry))
		topic_list.add_child(btn)

func _show_content(entry):
	if content_title: content_title.text = entry.title
	if content_label: content_label.text = entry.text
	if content_panel: content_panel.visible = true

	# Clear previous enemy details
	if details_container:
		for i in range(details_container.get_child_count() - 1, -1, -1):
			var child = details_container.get_child(i)
			if child != content_label:
				child.queue_free()
				
	if entry.has("race_keyword"):
		_populate_enemy_details(entry.race_keyword)

func _on_close_content_pressed():
	if content_panel: content_panel.visible = false

func _on_back_pressed():
	GlobalManager.switch_scene("main_menu")

func _has_seen_race(keyword: String) -> bool:
	if not PlayerData: return false
	for enemy_name in PlayerData.seen_enemies:
		if keyword in enemy_name:
			return true
	return false

func _populate_enemy_details(keyword: String):
	var race_key = keyword.to_lower()
	if race_key == "null": race_key = "void"
	
	if not CampaignManager.RACE_CONFIG.has(race_key): return
	
	var enemies = CampaignManager.RACE_CONFIG[race_key]
	var order = ["grunt", "assassin", "brute", "commander", "king"]
	
	for type in order:
		if enemies.has(type):
			var path = enemies[type]
			if ResourceLoader.exists(path):
				var monster = load(path)
				
				# Only show specific enemy types that have been seen
				if PlayerData and PlayerData.seen_enemies.has(monster.monster_name):
					_create_enemy_card(monster, type.capitalize())

func _create_enemy_card(monster: MonsterData, role: String):
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.5)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 20)
	panel.add_child(hbox)
	
	# Visual
	var icon_con = Control.new()
	icon_con.custom_minimum_size = Vector2(200, 200)
	icon_con.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icon_con)
	
	var visual = _create_monster_visual(monster, Vector2(200, 200))
	if visual:
		icon_con.add_child(visual)
		visual.position = Vector2(100, 100)
		
	# Info
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	
	var name_lbl = Label.new()
	name_lbl.text = "%s (%s)" % [monster.monster_name, role]
	name_lbl.add_theme_font_size_override("font_size", 48)
	name_lbl.add_theme_color_override("font_color", Color("#60fafc"))
	vbox.add_child(name_lbl)
	
	var stats = monster.get_current_stats()
	var stat_lbl = Label.new()
	stat_lbl.text = "HP: %d  |  ATK: %d  |  DEF: %d  |  SPD: %d" % [stats.max_hp, stats.attack, stats.defense, stats.speed]
	stat_lbl.add_theme_font_size_override("font_size", 32)
	stat_lbl.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(stat_lbl)
	
	var moves = CombatManager.get_active_moves(monster)
	if not moves.is_empty():
		var move_lbl = Label.new()
		move_lbl.text = "Moves:"
		move_lbl.add_theme_font_size_override("font_size", 36)
		move_lbl.add_theme_color_override("font_color", Color("#a0a0a0"))
		vbox.add_child(move_lbl)
		
		for m in moves:
			var m_text = Label.new()
			m_text.text = "• %s (%s, %d Pwr)" % [m.name, m.type, m.power]
			m_text.add_theme_font_size_override("font_size", 28)
			vbox.add_child(m_text)
			
	details_container.add_child(panel)

func _create_monster_visual(monster: MonsterData, container_size: Vector2) -> Node2D:
	var anim_name = monster.monster_name.replace(" ", "")
	if "animation_override" in monster and monster.animation_override != "":
		anim_name = monster.animation_override
		
	var anim_path = "res://Assets/Animations/" + anim_name + ".tres"
	
	if ResourceLoader.exists(anim_path):
		var sprite_frames = load(anim_path)
		var sprite = AnimatedSprite2D.new()
		sprite.sprite_frames = sprite_frames
		
		var anim_to_play = "idle"
		if not sprite_frames.has_animation(anim_to_play):
			if sprite_frames.has_animation("default"):
				anim_to_play = "default"
			else:
				var anims = sprite_frames.get_animation_names()
				if anims.size() > 0:
					anim_to_play = anims[0]
		
		sprite.play(anim_to_play)
		
		var tex = sprite_frames.get_frame_texture(anim_to_play, 0)
		if tex:
			var s = (container_size.y * 0.8) / float(tex.get_height())
			sprite.scale = Vector2(s, s)
			
		return sprite
	elif monster.icon:
		var sprite = Sprite2D.new()
		sprite.texture = monster.icon
		var s = (container_size.y * 0.8) / float(monster.icon.get_height())
		sprite.scale = Vector2(s, s)
		return sprite
	return null
