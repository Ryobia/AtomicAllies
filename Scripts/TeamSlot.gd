# c:\Users\ryobi\Projects\nexus\Scripts\TeamSlot.gd
extends Button

@onready var labels_container = $LabelsContainer
@onready var role_label = $LabelsContainer/RoleLabel
@onready var name_label = $LabelsContainer/NameLabel
@onready var sprite_center = $SpriteCenter
@onready var empty_label = $EmptyLabel

func setup(monster: MonsterData, team_idx: int, is_selection_mode: bool, anim_frames: SpriteFrames = null):
	# Clear previous sprite
	for child in sprite_center.get_children():
		child.queue_free()
	
	# Always setup role label so it's visible even when empty
	_setup_role_label(team_idx)
	
	if monster:
		# --- Monster State ---
		flat = false
		empty_label.visible = false
		labels_container.visible = true
		
		# Background Style based on Group
		var bg_color = Color(0.1, 0.1, 0.1, 1)
		if "group" in monster:
			bg_color = AtomicConfig.GROUP_COLORS.get(monster.group, bg_color)
		
		var gradient = Gradient.new()
		gradient.set_color(0, bg_color)
		gradient.set_color(1, bg_color.darkened(0.5))
		
		var grad_tex = GradientTexture2D.new()
		grad_tex.gradient = gradient
		grad_tex.fill_from = Vector2(0, 0)
		grad_tex.fill_to = Vector2(0, 1)
		
		var style = StyleBoxTexture.new()
		style.texture = grad_tex
		
		add_theme_stylebox_override("normal", style)
		add_theme_stylebox_override("hover", style)
		add_theme_stylebox_override("pressed", style)
		
		# Name Label
		name_label.text = "%s" % [monster.monster_name]
		name_label.add_theme_color_override("font_outline_color", Color.BLACK)
		name_label.add_theme_constant_override("outline_size", 6)
		
		# Sprite / Animation
		if anim_frames:
			var sprite = AnimatedSprite2D.new()
			sprite.sprite_frames = anim_frames
			var anim_to_play = "idle"
			if not anim_frames.has_animation(anim_to_play): anim_to_play = "default"
			if anim_frames.has_animation(anim_to_play): sprite.play(anim_to_play)
			
			var tex = anim_frames.get_frame_texture(anim_to_play, 0)
			if tex:
				var s = 180.0 / float(tex.get_height())
				sprite.scale = Vector2(s, s)
			sprite_center.add_child(sprite)
		elif monster.icon:
			# Fallback to icon if no animation
			var icon_rect = TextureRect.new()
			icon_rect.texture = monster.icon
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.custom_minimum_size = Vector2(150, 150)
			icon_rect.position = -icon_rect.custom_minimum_size / 2 # Center it
			sprite_center.add_child(icon_rect)
			
	else:
		# --- Empty State ---
		flat = true
		remove_theme_stylebox_override("normal")
		remove_theme_stylebox_override("hover")
		remove_theme_stylebox_override("pressed")
		
		labels_container.visible = true
		name_label.text = "" # Hide name, keep role
		empty_label.visible = true
		empty_label.text = "Tap to Select"
		empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		
func _setup_role_label(team_idx: int):
	var role_style = StyleBoxFlat.new()
	role_style.bg_color = Color(0, 0, 0, 0.5)
	role_label.add_theme_stylebox_override("normal", role_style)
	role_label.add_theme_color_override("font_outline_color", Color.BLACK)
	role_label.add_theme_constant_override("outline_size", 4)
	
	if team_idx == 0: 
		role_label.text = "VANGUARD"
		role_label.add_theme_color_override("font_color", Color("#ffd700"))
	elif team_idx < 3: 
		role_label.text = "FLANK"
		role_label.add_theme_color_override("font_color", Color("#60fafc"))
	else: 
		role_label.text = "BENCH"
		role_label.add_theme_color_override("font_color", Color("#a0a0a0"))
