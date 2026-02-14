extends Node

var active_timers = {}

func start_timer(id: String, duration: int):
	var end_time = Time.get_unix_time_from_system() + duration
	active_timers[id] = end_time

func get_time_left(id: String) -> int:
	if not active_timers.has(id):
		return 0
	var current = Time.get_unix_time_from_system()
	return int(max(0, active_timers[id] - current))

func clear_timer(id: String):
	if active_timers.has(id):
		active_timers.erase(id)