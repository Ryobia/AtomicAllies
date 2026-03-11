# c:\Users\ryobi\Projects\nexus\Scripts\StatPopup.gd
extends PanelContainer

const STATUS_DESCRIPTIONS = {
	"taunt": "Forced to attack the taunter.",
	"stun": "Cannot act this turn.",
	"silence_special": "Cannot use Special moves.",
	"marked_covalent": "Next cross-element hit deals 1.2x damage.",
	"guarded": "Blocks the next instance of damage.",
	"unstable": "Takes 1.2x damage from next attack.",
	"poison": "Taking damage over time based on Max HP.",
	"vulnerable": "Takes increased damage.",
	"corrosion": "Taking damage over time (ignores DEF).",
	"invulnerable": "Immune to all damage and status.",
	"reactive_vapor": "Takes damage when attacking enemies.",
	"radiation": "Taking increasing damage each turn.",
	"refracted": "Accuracy reduced by 20%.",
	"insanity": "Accuracy reduced by 20%.",
	"static_reflection": "Reflects 30% of incoming damage.",
	"physical_resist": "Reduces incoming Physical damage."
}

func setup(unit: BattleMonster):
    # --- Header ---
    # Try to find NameLabel if it exists (useful for context)
    var name_lbl = find_child("NameLabel", true, false)
    if name_lbl:
        name_lbl.text = "%s" % [unit.data.monster_name]
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
            # Group permanent stat mods
            var base_stats = unit.data.get_current_stats()
            var display_effects = []
            var perm_stat_mods = {} # stat -> amount
            
            # Assumes effects_container is a GridContainer with 3 columns
            for effect in unit.active_effects:
                var e_type = effect.get("type", "")
                var duration = effect.get("duration", 0)
                
                if e_type == "stat_mod" and duration > 50: # Threshold for "Permanent"
                    var stat = effect.get("stat")
                    if not perm_stat_mods.has(stat): perm_stat_mods[stat] = 0
                    perm_stat_mods[stat] += effect.get("amount", 0)
                else:
                    display_effects.append(effect)
            
            # Add grouped permanent mods to display list
            for stat in perm_stat_mods:
                display_effects.append({ "type": "stat_mod", "stat": stat, "amount": perm_stat_mods[stat], "duration": 99, "is_perm": true })

            for effect in display_effects:
                var card = PanelContainer.new()
                card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                
                var style = StyleBoxFlat.new()
                style.set_corner_radius_all(8)
                style.content_margin_left = 10
                style.content_margin_right = 10
                style.content_margin_top = 10
                style.content_margin_bottom = 10
                card.add_theme_stylebox_override("panel", style)

                var vbox = VBoxContainer.new()
                vbox.add_theme_constant_override("separation", 5)
                card.add_child(vbox)

                var title_lbl = Label.new()
                title_lbl.add_theme_font_size_override("font_size", 28)
                title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
                vbox.add_child(title_lbl)

                var desc_lbl = Label.new()
                desc_lbl.add_theme_font_size_override("font_size", 22)
                desc_lbl.add_theme_color_override("font_color", Color(1,1,1,0.7))
                desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
                vbox.add_child(desc_lbl)

                var duration = effect.get("duration", 0)
                var title_text = ""
                var desc_text = ""
                
                var e_type = effect.get("type", "")
                
                if e_type == "stat_mod":
                    style.bg_color = Color("#010813").lightened(0.1)
                    var stat = effect.get("stat", "stat")
                    var amount = effect.get("amount", 0)
                    
                    # Calculate Percentage
                    var base_val = float(base_stats.get(stat, 1))
                    if base_val <= 0: base_val = 1.0
                    var pct = (float(amount) / base_val) * 100.0
                    var pct_str = "%.1f" % pct
                    if pct_str.ends_with(".0"): pct_str = pct_str.trim_suffix(".0")
                    
                    var sign_str = "+" if pct >= 0 else ""
                    var dur_str = "(%d turns)" % duration
                    if effect.get("is_perm", false) or duration > 50: dur_str = "(Passive)"
                    
                    title_text = "%s%s%% %s %s" % [sign_str, pct_str, stat.capitalize(), dur_str]
                    title_lbl.add_theme_color_override("font_color", Color.GREEN if amount > 0 else Color.RED)
                    desc_text = "Flat Change: %s%d" % [sign_str, amount]
                elif e_type == "status":
                    style.bg_color = Color("#010813").lightened(0.1)
                    var s_name = effect.get("status", "Unknown")
                    var status_key = str(s_name).to_lower()
                    title_text = "%s (%d turns)" % [s_name.capitalize(), duration]
                    if effect.has("damage_multiplier"):
                        var mult = float(effect.get("damage_multiplier", 1.0))
                        desc_text = "Takes %.2fx damage from next attack." % mult
                    elif status_key == "static_reflection":
                        var pct = int(float(effect.get("damage_percent", 0.3)) * 100)
                        desc_text = "Reflects %d%% of incoming damage." % pct
                    elif status_key == "physical_resist":
                        var pct = int(float(effect.get("reduction_amount", 0.2)) * 100)
                        desc_text = "Reduces incoming Physical damage by %d%%." % pct
                    elif STATUS_DESCRIPTIONS.has(status_key): desc_text = STATUS_DESCRIPTIONS[status_key]
                    title_lbl.add_theme_color_override("font_color", Color.YELLOW if status_key in ["invulnerable", "taunt"] else Color.ORANGE_RED)
                
                title_lbl.text = title_text
                desc_lbl.text = desc_text
                desc_lbl.visible = (desc_text != "")
                
                effects_container.add_child(card)

    # --- Close Button ---
    var close_btn = find_child("CloseButton", true, false)
    if close_btn:
        if not close_btn.pressed.is_connected(queue_free):
            close_btn.pressed.connect(queue_free)
