extends PanelContainer

func setup(reward: int):
    var reward_lbl = find_child("RewardLabel", true, false)
    var ok_btn = find_child("OkButton", true, false)
    var icon = find_child("IconTexture", true, false)
    
    if reward_lbl:
        reward_lbl.text = "Recovered %d Neutron Dust" % reward
    
    # Simple pulse animation for the dust icon
    if icon:
        icon.pivot_offset = icon.size / 2
        var tween = create_tween()
        tween.tween_property(icon, "scale", Vector2(1.2, 1.2), 0.2).set_trans(Tween.TRANS_BOUNCE)
        tween.tween_property(icon, "scale", Vector2(1.0, 1.0), 0.2)
    
    if ok_btn:
        if not ok_btn.pressed.is_connected(_on_close):
            ok_btn.pressed.connect(_on_close)
    
    visible = true
    z_index = 30 # Ensure it sits on top of everything
    move_to_front()

func _on_close():
    visible = false
