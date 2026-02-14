extends Control

var status_label
var hatch_btn
var egg_texture
var dissolve_popup
var dissolve_label
var dissolve_ok_btn
var fusion_result_popup

func _ready():
	# Find nodes dynamically
	status_label = find_child("StatusLabel", true, false)
	hatch_btn = find_child("HatchButton", true, false)
	egg_texture = find_child("EggTexture", true, false)
	dissolve_popup = find_child("DissolvePopup", true, false)
	fusion_result_popup = find_child("FusionResultPopup", true, false)
	
	if dissolve_popup:
		dissolve_label = dissolve_popup.find_child("Label", true, false)
		dissolve_ok_btn = dissolve_popup.find_child("OkButton", true, false)
		dissolve_popup.visible = false
		if dissolve_ok_btn:
			dissolve_ok_btn.pressed.connect(_on_dissolve_ok_pressed)

	if fusion_result_popup:
		fusion_result_popup.visible = false

	if hatch_btn:
		hatch_btn.pressed.connect(_on_hatch_pressed)
	
	var back_btn = find_child("BackButton", true, false)
	if back_btn:
		back_btn.z_index = 10 # Force button to render on top of everything else
		back_btn.move_to_front() # Reorder node to be drawn last (on top)
		if not back_btn.pressed.is_connected(_on_back_pressed):
			back_btn.pressed.connect(_on_back_pressed)
	
	update_ui()

func _process(_delta):
	# Update timer UI in real-time
	if PlayerData.pending_egg:
		if TimeManager.get_time_left("breeding") > 0:
			if status_label:
				status_label.text = "Incubating... %ds" % TimeManager.get_time_left("breeding")
			if hatch_btn:
				hatch_btn.disabled = true
		elif hatch_btn and hatch_btn.disabled:
			# Timer just finished
			update_ui()

func update_ui():
	if PlayerData.pending_egg:
		if egg_texture: egg_texture.visible = true
		
		if TimeManager.get_time_left("breeding") > 0:
			if status_label: status_label.text = "Incubating..."
			if hatch_btn: hatch_btn.disabled = true
		else:
			if status_label: status_label.text = "Ready to Hatch!"
			if hatch_btn: hatch_btn.disabled = false
	else:
		if status_label: status_label.text = "No egg in nursery."
		if hatch_btn: hatch_btn.disabled = true
		if egg_texture: egg_texture.visible = false

func _on_hatch_pressed():
	var egg = PlayerData.pending_egg
	if not egg: return
	
	if PlayerData.is_monster_owned(egg.monster_name):
		# --- DISSOLVE LOGIC ---
		var dust_amount = _get_dust_amount(egg.atomic_number)
		PlayerData.add_resource("neutron_dust", dust_amount)
		
		if dissolve_label:
			dissolve_label.text = "Duplicate %s found!\nDissolved into %d Neutron Dust." % [egg.monster_name, dust_amount]
		
		if dissolve_popup: dissolve_popup.visible = true
	else:
		# --- NEW MONSTER LOGIC ---
		PlayerData.owned_monsters.append(egg)
		if status_label: status_label.text = "Hatched a new %s!" % egg.monster_name
		
		if fusion_result_popup:
			fusion_result_popup.setup(egg)
	
	# Clear the egg
	PlayerData.pending_egg = null
	TimeManager.clear_timer("breeding")
	update_ui()

func _on_dissolve_ok_pressed():
	if dissolve_popup: dissolve_popup.visible = false
	update_ui()

func _on_back_pressed():
	GlobalManager.switch_scene("main_menu")

func _get_dust_amount(atomic_number: int) -> int:
	# Heavier elements give more dust. Formula: 5 dust per atomic number.
	return atomic_number * 5

func _on_back_button_pressed():
	GlobalManager.switch_scene("main_menu")
