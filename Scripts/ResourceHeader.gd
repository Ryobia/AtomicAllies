extends CanvasLayer

var dust_label
var binding_label
var gems_label
var luminous_label

var _prev_dust: int = -1
var _prev_binding: int = -1
var _prev_gems: int = -1
var _prev_luminous: int = -1

func _ready():
	# Find the labels by their new names
	dust_label = find_child("DustLabel", true, false)
	binding_label = find_child("BindingLabel", true, false) # Renamed from XPLabel
	gems_label = find_child("GemLabel", true, false)
	luminous_label = find_child("LuminousLabel", true, false)
	
	if PlayerData:
		# Connect to the global resource signal
		PlayerData.resource_updated.connect(_on_resource_updated)
		_update_display()
	
	if GlobalManager:
		GlobalManager.scene_changed.connect(_on_scene_changed)

func _update_display():
	# This function ensures all labels are populated with the correct initial values
	# by routing through the main update function.
	_on_resource_updated("neutron_dust", PlayerData.resources.get("neutron_dust", 0))
	_on_resource_updated("binding_energy", PlayerData.resources.get("binding_energy", 0))
	_on_resource_updated("gems", PlayerData.resources.get("gems", 0))
	_on_resource_updated("luminous_core", PlayerData.resources.get("luminous_core", 0))

func _on_resource_updated(type: String, amount: float):
	var new_val = int(amount)
	
	if type == "neutron_dust" and dust_label:
		_animate_resource_label(dust_label, _prev_dust, new_val)
		_prev_dust = new_val
	elif type == "binding_energy" and binding_label:
		_animate_resource_label(binding_label, _prev_binding, new_val)
		_prev_binding = new_val
	elif type == "gems" and gems_label:
		_animate_resource_label(gems_label, _prev_gems, new_val)
		_prev_gems = new_val
	elif type == "luminous_core" and luminous_label:
		_animate_resource_label(luminous_label, _prev_luminous, new_val)
		_prev_luminous = new_val

func _animate_resource_label(label: Label, prev_val: int, new_val: int):
	if not is_instance_valid(label): return
	
	if prev_val == -1:
		label.text = str(new_val)
		return
		
	if prev_val != new_val:
		var tween = create_tween()
		tween.tween_method(func(val):
			if is_instance_valid(label):
				label.text = str(int(val))
		, prev_val, new_val, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		var flash_color = Color("#2ecc71") if new_val > prev_val else Color("#ff4d4d")
		
		var color_tween = create_tween()
		color_tween.tween_property(label, "modulate", flash_color, 0.1)
		color_tween.tween_property(label, "modulate", Color.WHITE, 0.5).set_delay(0.3)

func _on_scene_changed(scene_key: String):
	# Hide header in battle, show everywhere else
	if scene_key == "battle" or scene_key == "rest_site":
		visible = false
	else:
		visible = true
