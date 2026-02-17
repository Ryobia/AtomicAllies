extends PanelContainer

func setup(z: int, monster: MonsterData = null):
	var title_lbl = find_child("TitleLabel", true, false)
	var hint_lbl = find_child("HintLabel", true, false)
	var close_btn = find_child("CloseButton", true, false)
	
	if title_lbl:
		if monster:
			title_lbl.text = "Research Notes: %s" % monster.monster_name
		else:
			title_lbl.text = "Research Notes: Element #%d" % z
			
	if hint_lbl:
		hint_lbl.text = _generate_hint(z)
		
	if close_btn:
		if not close_btn.pressed.is_connected(_on_close):
			close_btn.pressed.connect(_on_close)
			
	visible = true
	z_index = 20
	move_to_front()

func _generate_hint(z: int) -> String:
	var hint = "Target Atomic Number: %d\n\n" % z
	hint += "Synthesis Hypothesis:\n"
	hint += "Combine two elements where Z1 + Z2 = %d.\n\n" % z
	
	 # Specific hints for early game logic
	if z <= 10:
		hint += "Don't be afraid of failure"
		

	else:
		hint += "Requires high-energy fusion of lighter elements."
		
	return hint

func _on_close():
	visible = false
