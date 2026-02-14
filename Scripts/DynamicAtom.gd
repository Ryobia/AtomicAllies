extends Node2D

# -- CONFIGURATION --
@export var atomic_number: int = 1:
	set(value):
		atomic_number = value
		if is_inside_tree(): # Update in real-time if we change it in editor
			generate_atom()

@export var electron_texture: Texture2D # Drag your 'ElectronGlow.tres' here!
@export var rotation_speed: float = 30.0 # Degrees per second
@export var shell_spacing: float = 60.0 # Distance between rings

@export var nucleus_color: Color = Color(0.4, 0.8, 1.0, 0.9) # Cyan glow
@export var pulse_speed: float = 4.0
@export var pulse_strength: float = 0.1

# Standard Bohr Model capacities (K, L, M, N...)
const SHELL_CAPACITIES = [2, 8, 18, 32, 50, 72]

# Internal tracking
var shell_pivots = [] 
var nucleus_glow: Sprite2D
var trails = []

func _ready():
	generate_atom()
	
	# Auto-center if placed inside a UI element (Control node)
	var parent = get_parent()
	if parent is Control:
		_on_parent_resized()
		call_deferred("_on_parent_resized") # Wait for layout system to calculate size
		if not parent.resized.is_connected(_on_parent_resized):
			parent.resized.connect(_on_parent_resized)

func generate_atom():
	# 1. CLEANUP: Remove old electrons/orbits if we are regenerating
	for pivot in shell_pivots:
		pivot.queue_free()
	shell_pivots.clear()
	
	for t in trails:
		if is_instance_valid(t.line):
			t.line.queue_free()
	trails.clear()
	
	# 1.5 SETUP NUCLEUS GLOW
	if not nucleus_glow and electron_texture:
		nucleus_glow = Sprite2D.new()
		nucleus_glow.texture = electron_texture
		nucleus_glow.modulate = nucleus_color
		
		# Additive blending makes it look like light
		var mat = CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		nucleus_glow.material = mat
		
		add_child(nucleus_glow)
	
	# 2. CALCULATION: Figure out where electrons go
	var remaining_electrons = atomic_number
	var current_shell_index = 0
	
	while remaining_electrons > 0:
		# How many fit in this shell?
		var capacity = SHELL_CAPACITIES[current_shell_index]
		var count = min(remaining_electrons, capacity)
		
		# Build the shell
		create_shell(current_shell_index, count)
		
		remaining_electrons -= count
		current_shell_index += 1
	
	# 2.5 SETUP TRAILS for Outer Shell
	if shell_pivots.size() > 0:
		var outer_pivot = shell_pivots.back()
		for electron in outer_pivot.get_children():
			create_trail(electron)
	
	# 3. VISUALS: Trigger the _draw() function to draw the rings
	queue_redraw()

func create_trail(target: Node2D):
	var trail = Line2D.new()
	trail.width = 3.0
	trail.default_color = nucleus_color
	
	var gradient = Gradient.new()
	gradient.set_color(0, nucleus_color)
	gradient.set_color(1, Color(nucleus_color.r, nucleus_color.g, nucleus_color.b, 0.0))
	trail.gradient = gradient
	
	# Add trail to root so it doesn't rotate with the pivot
	add_child(trail)
	move_child(trail, 0) 
	
	trails.append({"line": trail, "target": target})

func create_shell(index: int, electron_count: int):
	var radius = (index + 1) * shell_spacing
	
	# Create a "Pivot" node. This invisible node will sit at (0,0) and SPIN.
	# The electrons will be children of this pivot.
	var pivot = Node2D.new()
	pivot.name = "Shell_" + str(index)
	add_child(pivot)
	shell_pivots.append(pivot)
	
	# Place Electrons evenly around the circle
	var angle_step = TAU / electron_count # TAU is 2*PI (360 degrees)
	
	for i in range(electron_count):
		var electron = Sprite2D.new()
		electron.texture = electron_texture
		
		# Math: Polar to Cartesian coordinates
		var angle = i * angle_step
		var x = cos(angle) * radius
		var y = sin(angle) * radius
		
		electron.position = Vector2(x, y)
		electron.scale = Vector2(0.5, 0.5) # Adjust size if needed
		
		# Add electron to the SPINNING pivot, not the static root
		pivot.add_child(electron)

func _process(delta):
	# Animate the shells
	for i in range(shell_pivots.size()):
		var pivot = shell_pivots[i]
		
		# Visual Polish:
		# 1. Alternate direction (Even shells spin Right, Odd spin Left)
		var direction = 1 if i % 2 == 0 else -1
		
		# 2. Parallax: Outer shells spin slightly slower
		var speed_mod = 1.0 - (i * 0.15)
		
		pivot.rotation_degrees += (rotation_speed * direction * speed_mod) * delta
		
	# Animate Nucleus Pulse
	if nucleus_glow:
		var time = Time.get_ticks_msec() / 1000.0
		var pulse = 1.0 + (sin(time * pulse_speed) * pulse_strength)
		nucleus_glow.scale = Vector2(3.0, 3.0) * pulse # Base scale 3.0 for a nice halo
		
	# Update Trails
	for t in trails:
		var line = t.line
		var target = t.target
		if is_instance_valid(target):
			line.add_point(to_local(target.global_position))
			if line.get_point_count() > 15:
				line.remove_point(0)

func _draw():
	# Draw the static faint lines for the orbits
	# We use the shell_pivots count to know how many rings to draw
	for i in range(shell_pivots.size()):
		# Skip the outer shell path
		if i == shell_pivots.size() - 1:
			continue
			
		var radius = (i + 1) * shell_spacing
		# Draw a circle: Position, Radius, Color, Width
		draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(1, 1, 1, 0.2), 2.0, true)

func _on_parent_resized():
	var parent = get_parent()
	if parent is Control:
		position = parent.size / 2.0
