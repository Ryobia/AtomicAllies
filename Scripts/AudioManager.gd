extends Node

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Create Music Player
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Master"
	add_child(music_player)
	
	# Create SFX Pool (allows multiple sounds at once)
	for i in range(10):
		var p = AudioStreamPlayer.new()
		p.name = "SFXPlayer_" + str(i)
		p.bus = "Master"
		add_child(p)
		sfx_players.append(p)
		
	# Apply saved volume on startup
	if PlayerData:
		var vol = PlayerData.settings.get("master_volume", 1.0)
		set_master_volume(vol)
		var muted = PlayerData.settings.get("master_muted", false)
		set_master_mute(muted)

func play_music(stream: AudioStream):
	if music_player.stream == stream and music_player.playing:
		return
	music_player.stream = stream
	music_player.play()

func play_sfx(stream: AudioStream, pitch_scale: float = 1.0):
	for p in sfx_players:
		if not p.playing:
			p.stream = stream
			p.pitch_scale = pitch_scale
			p.play()
			return
	
	# Fallback: Interrupt the first player if all are busy
	sfx_players[0].stream = stream
	sfx_players[0].pitch_scale = pitch_scale
	sfx_players[0].play()

func set_master_volume(value: float):
	var idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(idx, linear_to_db(value))
	
	if PlayerData:
		PlayerData.settings["master_volume"] = value
		PlayerData.save_game()

func get_master_volume() -> float:
	if PlayerData and PlayerData.settings.has("master_volume"):
		return PlayerData.settings["master_volume"]
	return 1.0

func set_master_mute(muted: bool):
	var idx = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(idx, muted)
	
	if PlayerData:
		PlayerData.settings["master_muted"] = muted
		PlayerData.save_game()

func is_master_muted() -> bool:
	var idx = AudioServer.get_bus_index("Master")
	return AudioServer.is_bus_mute(idx)
