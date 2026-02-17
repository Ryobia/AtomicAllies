extends CanvasLayer

func _ready():
	# Connect to global signal to update UI automatically
	if PlayerData:
		if not PlayerData.resource_updated.is_connected(_on_resource_updated):
			PlayerData.resource_updated.connect(_on_resource_updated)
	
	# Connect to GlobalManager to hide during battle
	if GlobalManager:
		GlobalManager.scene_changed.connect(_on_scene_changed)
	
	# Initial update
	update_display()

func update_display():
	var xp_lbl = find_child("XPLabel", true, false)
	var dust_lbl = find_child("DustLabel", true, false)
	var gem_lbl = find_child("GemLabel", true, false)
	
	if xp_lbl: xp_lbl.text = "%d" % PlayerData.resources.get("experience", 0)
	if dust_lbl: dust_lbl.text = "%d" % PlayerData.resources.get("neutron_dust", 0)
	if gem_lbl: gem_lbl.text = "%d" % PlayerData.resources.get("gems", 0)

func _on_resource_updated(_type, _amount):
	update_display()

func _on_scene_changed(scene_key: String):
	# Hide header in battle, show everywhere else
	if scene_key == "battle":
		visible = false
	else:
		visible = true
