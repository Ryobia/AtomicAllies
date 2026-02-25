# c:\Users\ryobi\Projects\nexus\Scripts\StatPopup.gd
extends PanelContainer

func setup(unit: BattleMonster):
    # --- Header ---
    # Try to find NameLabel if it exists (useful for context)
    var name_lbl = find_child("NameLabel", true, false)
    if name_lbl:
        name_lbl.text = "%s (Lv. %d)" % [unit.data.monster_name, unit.data.level]
        # Color code based on team
        name_lbl.modulate = Color("#60fafc") if unit.is_player else Color("#ff4d4d")

    # --- Stats ---
    # Populate the specific labels you created
    var hp_lbl = find_child("HPLabel", true, false)
    if hp_lbl:
        hp_lbl.text = "HP: %d / %d" % [unit.current_hp, unit.max_hp]
        
    var atk_lbl = find_child("AttackLabel", true, false)
    if atk_lbl:
        atk_lbl.text = "Attack: %d" % unit.stats.get("attack", 0)
        
    var def_lbl = find_child("DefenseLabel", true, false)
    if def_lbl:
        def_lbl.text = "Defense: %d" % unit.stats.get("defense", 0)
        
    var spd_lbl = find_child("SpeedLabel", true, false)
    if spd_lbl:
        spd_lbl.text = "Speed: %d" % unit.stats.get("speed", 0)

    # --- Active Effects ---
    # If you decide to add an EffectsContainer later, this will handle it.
    # If not, find_child returns null and this block is skipped safely.
    var effects_container = find_child("EffectsContainer", true, false)
    if effects_container:
        for child in effects_container.get_children():
            child.queue_free()
            
        if unit.active_effects.is_empty():
            var lbl = Label.new()
            lbl.text = "No active effects."
            lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
            effects_container.add_child(lbl)
        else:
            for effect in unit.active_effects:
                var lbl = Label.new()
                var duration = effect.get("duration", 0)
                var text = ""
                
                if effect.type == "stat_mod":
                    var sign_str = "+" if effect.amount > 0 else ""
                    text = "%s%d %s (%d turns)" % [sign_str, effect.amount, effect.stat.capitalize(), duration]
                    lbl.modulate = Color.GREEN if effect.amount > 0 else Color.RED
                elif effect.type == "status":
                    text = "%s (%d turns)" % [effect.name.capitalize(), duration]
                    lbl.modulate = Color.YELLOW
                
                lbl.text = text
                effects_container.add_child(lbl)

    # --- Close Button ---
    var close_btn = find_child("CloseButton", true, false)
    if close_btn:
        if not close_btn.pressed.is_connected(queue_free):
            close_btn.pressed.connect(queue_free)
