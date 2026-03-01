extends Control

@onready var grid = find_child("SynergyGrid", true, false)
@onready var back_btn = find_child("BackButton", true, false)

# Cache for total counts per group (Total elements in game vs Owned)
var _group_totals = {}

func _ready():
    if back_btn:
        if not back_btn.pressed.is_connected(_on_back_pressed):
            back_btn.pressed.connect(_on_back_pressed)
    
    if PlayerData.has_method("recalculate_class_resonance"):
        PlayerData.recalculate_class_resonance()
    
    _calculate_group_totals()
    _populate_grid()

func _calculate_group_totals():
    _group_totals.clear()
    # Initialize known groups
    for group in AtomicConfig.GROUP_COLORS:
        if group >= AtomicConfig.Group.UNKNOWN: continue
        _group_totals[group] = 0
        
    # Count totals from the Manifest
    for monster in MonsterManifest.all_monsters:
        if monster.group in _group_totals:
            _group_totals[monster.group] += 1

func _populate_grid():
    if not grid: 
        print("SynergyView: No SynergyGrid found.")
        return
    
    for child in grid.get_children():
        child.queue_free()
        
    # Sort groups by ID (Periodic Table order)
    var groups = _group_totals.keys()
    groups.sort()
    
    for group in groups:
        _create_synergy_card(group)

func _create_synergy_card(group: int):
    var panel = PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel.custom_minimum_size = Vector2(0, 160)
    panel.mouse_filter = Control.MOUSE_FILTER_PASS
    
    # Style: Dark background with colored left border matching the group
    var style = StyleBoxFlat.new()
    style.bg_color = Color("#010813")
    style.border_width_left = 6
    style.border_color = AtomicConfig.GROUP_COLORS.get(group, Color.WHITE)
    style.set_corner_radius_all(8)
    style.content_margin_left = 20
    style.content_margin_right = 20
    style.content_margin_top = 15
    style.content_margin_bottom = 15
    panel.add_theme_stylebox_override("panel", style)
    
    var vbox = VBoxContainer.new()
    vbox.add_theme_constant_override("separation", 8)
    vbox.mouse_filter = Control.MOUSE_FILTER_PASS
    panel.add_child(vbox)
    
    # --- Header Row (Name + Count) ---
    var header = HBoxContainer.new()
    vbox.add_child(header)
    
    var name_lbl = Label.new()
    var group_name = AtomicConfig.Group.find_key(group).replace("_", " ").capitalize()
    name_lbl.text = group_name
    name_lbl.add_theme_font_size_override("font_size", 36)
    name_lbl.add_theme_color_override("font_color", style.border_color)
    name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    header.add_child(name_lbl)
    
    var owned = PlayerData.class_resonance.get(group, 0)
    var total = _group_totals.get(group, 0)
    
    var count_lbl = Label.new()
    count_lbl.text = "%d / %d Collected" % [owned, total]
    count_lbl.add_theme_font_size_override("font_size", 24)
    count_lbl.add_theme_color_override("font_color", Color("#a0a0a0"))
    count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    header.add_child(count_lbl)
    
    # --- Progress Bar ---
    var bar = ProgressBar.new()
    bar.max_value = total
    bar.value = owned
    bar.show_percentage = false
    bar.custom_minimum_size.y = 8
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    
    var fill = StyleBoxFlat.new()
    fill.bg_color = style.border_color
    fill.set_corner_radius_all(4)
    bar.add_theme_stylebox_override("fill", fill)
    
    var bg = StyleBoxFlat.new()
    bg.bg_color = Color(0.1, 0.1, 0.1)
    bg.set_corner_radius_all(4)
    bar.add_theme_stylebox_override("background", bg)
    
    vbox.add_child(bar)
    
    # --- Description ---
    var desc = RichTextLabel.new()
    desc.bbcode_enabled = true
    desc.text = _get_synergy_text(group, owned)
    desc.fit_content = true
    desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
    desc.add_theme_font_size_override("normal_font_size", 24)
    desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vbox.add_child(desc)
    
    grid.add_child(panel)

func _get_synergy_text(group: int, count: int) -> String:
    var c_val = "#60fafc" # Cyan for values
    var c_lbl = "#a0a0a0" # Grey for labels
    
    match group:
        AtomicConfig.Group.ALKALI_METAL:
            var val = count * 5
            return "[color=%s]Synergy:[/color] Ignore [color=%s]%d%%[/color] Defense (5%%/elem).\n[color=%s]Passive:[/color] High Defense Penetration." % [c_lbl, c_val, val, c_lbl]
        AtomicConfig.Group.ALKALINE_EARTH:
            var val = count * 5
            return "[color=%s]Synergy:[/color] [color=%s]+%d%%[/color] Base Defense (5%%/elem).\n[color=%s]Passive:[/color] Gain +5%% Defense every turn." % [c_lbl, c_val, val, c_lbl]
        AtomicConfig.Group.TRANSITION_METAL:
            var val = count * 2
            return "[color=%s]Synergy:[/color] [color=%s]%d%%[/color] Double Hit Chance (2%%/elem).\n[color=%s]Passive:[/color] Consecutive attacks deal +5%% Damage." % [c_lbl, c_val, val, c_lbl]
        AtomicConfig.Group.HALOGEN:
            var val = count * 1
            return "[color=%s]Synergy:[/color] [color=%s]+%d%%[/color] Poison Damage (1%%/elem).\n[color=%s]Passive:[/color] Attacks apply Poison (10%% HP/turn)." % [c_lbl, c_val, val, c_lbl]
        AtomicConfig.Group.NOBLE_GAS:
            var val = count * 5
            return "[color=%s]Synergy:[/color] [color=%s]+%d%%[/color] Base HP (5%%/elem).\n[color=%s]Passive:[/color] Restore 5%% HP every turn." % [c_lbl, c_val, val, c_lbl]
        AtomicConfig.Group.LANTHANIDE:
            var val = count * 1
            return "[color=%s]Synergy:[/color] [color=%s]+%d%%[/color] All Stats (1%%/elem).\n[color=%s]Passive:[/color] Absorb 10%% of fallen enemy stats." % [c_lbl, c_val, val, c_lbl]
        AtomicConfig.Group.NONMETAL:
            var val = count * 5
            return "[color=%s]Synergy:[/color] [color=%s]%d%%[/color] Chain Reaction Chance (5%%/elem).\n[color=%s]Passive:[/color] Allies gain +5%% Attack per Nonmetal." % [c_lbl, c_val, val, c_lbl]
        AtomicConfig.Group.METALLOID:
            var val = count * 5
            return "[color=%s]Synergy:[/color] [color=%s]+%d%%[/color] Debuff Effect (5%%/elem).\n[color=%s]Passive:[/color] 10%% Chance to Stun on hit." % [c_lbl, c_val, val, c_lbl]
        AtomicConfig.Group.POST_TRANSITION:
            var val = count * 5
            return "[color=%s]Synergy:[/color] [color=%s]+%d%%[/color] Buff Effect (5%%/elem).\n[color=%s]Passive:[/color] Gain +1%% All Stats every turn." % [c_lbl, c_val, val, c_lbl]
        AtomicConfig.Group.ACTINIDE:
            var val = count * 1
            return "[color=%s]Synergy:[/color] [color=%s]+%d%%[/color] Base Speed (1%%/elem).\n[color=%s]Passive:[/color] Lose 10%% HP to deal +10%% Max HP Dmg." % [c_lbl, c_val, val, c_lbl]
    return "Unknown Synergy."

func _on_back_pressed():
    # Return to the Periodic Table since that's likely where we came from
    GlobalManager.switch_scene("periodic_table")
