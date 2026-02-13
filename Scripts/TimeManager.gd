extends Node

# Dictionary to store active timers.
# Format: { "timer_id": unix_timestamp_when_finished }
var active_timers = {}

const SAVE_PATH = "user://timers.save"

func _ready():
	load_timers()

# Start a new timer with a unique ID and duration in seconds
func start_timer(id: String, duration_seconds: int):
	var end_time = Time.get_unix_time_from_system() + duration_seconds
	active_timers[id] = end_time
	save_timers()
	print("TimeManager: Started timer '%s' for %d seconds." % [id, duration_seconds])

# Returns the remaining time in seconds. Returns 0 if finished or doesn't exist.
func get_time_left(id: String) -> int:
	if not active_timers.has(id):
		return 0
	
	var current_time = Time.get_unix_time_from_system()
	var time_left = active_timers[id] - current_time
	
	return int(max(0, time_left))

# Checks if a specific timer has completed
func is_timer_finished(id: String) -> bool:
	if active_timers.has(id):
		return get_time_left(id) <= 0
	return false

# Removes a timer (e.g. after collecting the egg)
func clear_timer(id: String):
	if active_timers.has(id):
		active_timers.erase(id)
		save_timers()

# --- Persistence ---
func save_timers():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_var(active_timers)

func load_timers():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		active_timers = file.get_var()