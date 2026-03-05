extends Control

@onready var master_slider = find_child("MasterSlider", true, false)
@onready var fullscreen_check = find_child("FullscreenCheck", true, false)
@onready var close_btn = find_child("CloseButton", true, false)
var mute_btn: Button

func _ready():
	if close_btn:
		close_btn.pressed.connect(func(): visible = false)
	
	if master_slider:
		if AudioManager:
			master_slider.value = AudioManager.get_master_volume()
		master_slider.value_changed.connect(_on_master_volume_changed)
		
		# Dynamically add Mute Button next to slider
		var parent = master_slider.get_parent()
		if parent:
			if not parent is HBoxContainer:
				var hbox = HBoxContainer.new()
				hbox.name = "VolumeRow"
				hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				hbox.add_theme_constant_override("separation", 15)
				
				var grand_parent = parent
				var idx = master_slider.get_index()
				grand_parent.remove_child(master_slider)
				grand_parent.add_child(hbox)
				grand_parent.move_child(hbox, idx)
				
				hbox.add_child(master_slider)
				master_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				parent = hbox
			
			mute_btn = Button.new()
			mute_btn.text = "Mute"
			mute_btn.custom_minimum_size = Vector2(80, 0)
			mute_btn.pressed.connect(_on_mute_toggled)
			parent.add_child(mute_btn)
			_update_mute_visual()

func _on_master_volume_changed(value: float):
	if AudioManager:
		AudioManager.set_master_volume(value)

func _on_mute_toggled():
	if AudioManager:
		var is_muted = AudioManager.is_master_muted()
		AudioManager.set_master_mute(!is_muted)
		_update_mute_visual()

func _update_mute_visual():
	if AudioManager and mute_btn:
		var is_muted = AudioManager.is_master_muted()
		mute_btn.text = "Unmute" if is_muted else "Mute"
		mute_btn.modulate = Color(1, 0.5, 0.5) if is_muted else Color.WHITE
