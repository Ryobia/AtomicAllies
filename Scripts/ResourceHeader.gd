extends CanvasLayer

var dust_label
var binding_label
var gems_label

func _ready():
	# Find the labels by their new names
	dust_label = find_child("DustLabel", true, false)
	binding_label = find_child("BindingLabel", true, false) # Renamed from XPLabel
	gems_label = find_child("GemLabel", true, false)
	
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

func _on_resource_updated(type: String, amount: float):
	# The amount can come in as a float from JSON, so we cast to int for display.
	var display_amount = str(int(amount))
	
	if type == "neutron_dust" and dust_label:
		dust_label.text = display_amount
	elif type == "binding_energy" and binding_label:
		binding_label.text = display_amount
	elif type == "gems" and gems_label:
		gems_label.text = display_amount

func _on_scene_changed(scene_key: String):
	# Hide header in battle, show everywhere else
	if scene_key == "battle" or scene_key == "battle_prepare" or scene_key == "rest_site":
		visible = false
	else:
		visible = true
