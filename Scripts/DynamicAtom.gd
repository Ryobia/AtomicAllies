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

# Standard Bohr Model capacities (K, L, M, N...)
const SHELL_CAPACITIES = [2, 8, 18, 32, 50, 72]

# Internal tracking
var shell_pivots = [] 

func _ready():
	generate_atom()

func generate_atom():
	# 1. CLEANUP: Remove old electrons/orbits if we are regenerating
	for pivot in shell_pivots:
		pivot.queue_free()
	shell_pivots.clear()
	
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
	
	# 3. VISUALS: Trigger the _draw() function to draw the rings
	queue_redraw()

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

func _draw():
	# Draw the static faint lines for the orbits
	# We use the shell_pivots count to know how many rings to draw
	for i in range(shell_pivots.size()):
		var radius = (i + 1) * shell_spacing
		# Draw a circle: Position, Radius, Color, Width
		draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(1, 1, 1, 0.2), 2.0, true)