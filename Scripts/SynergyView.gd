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
    # panel.custom_minimum_size = Vector2(0, 180) # Allow auto-sizing
    panel.mouse_filter = Control.MOUSE_FILTER_STOP # Capture clicks
    
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
    name_lbl.add_theme_font_size_override("font_size", 48)
    name_lbl.add_theme_color_override("font_color", style.border_color)
    name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    header.add_child(name_lbl)
    
    var owned = PlayerData.class_resonance.get(group, 0)
    var total = _group_totals.get(group, 0)
    
    if total > 0 and owned >= total:
        var fs_lbl = Label.new()
        fs_lbl.text = "★ FULL SET"
        fs_lbl.add_theme_font_size_override("font_size", 28)
        fs_lbl.add_theme_color_override("font_color", Color("#ffd700"))
        fs_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        header.add_child(fs_lbl)
    
    var count_lbl = Label.new()
    count_lbl.text = "%d / %d Collected" % [owned, total]
    count_lbl.add_theme_font_size_override("font_size", 32)
    count_lbl.add_theme_color_override("font_color", Color("#a0a0a0"))
    count_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
    header.add_child(count_lbl)
    
    var arrow = Label.new()
    arrow.text = " ▼"
    arrow.add_theme_font_size_override("font_size", 40)
    arrow.add_theme_color_override("font_color", Color("#a0a0a0"))
    header.add_child(arrow)
    
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
    desc.add_theme_font_size_override("normal_font_size", 32)
    desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vbox.add_child(desc)
    
    # --- Element List (Expandable) ---
    var separator = HSeparator.new()
    separator.visible = false
    separator.modulate.a = 0.3
    vbox.add_child(separator)
    
    var element_grid = GridContainer.new()
    element_grid.columns = 2
    element_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    element_grid.add_theme_constant_override("h_separation", 20)
    element_grid.visible = false
    vbox.add_child(element_grid)
    
    var group_monsters = []
    if MonsterManifest:
        for m in MonsterManifest.all_monsters:
            if m.group == group:
                group_monsters.append(m)
    
    for m in group_monsters:
        var row = HBoxContainer.new()
        row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        
        var is_owned = PlayerData.is_monster_owned(m.monster_name)
        var color = Color.WHITE if is_owned else Color(0.5, 0.5, 0.5)
        
        var z_lbl = Label.new()
        z_lbl.text = str(m.atomic_number).pad_zeros(3)
        z_lbl.add_theme_font_size_override("font_size", 28)
        z_lbl.add_theme_color_override("font_color", AtomicConfig.GROUP_COLORS.get(group, Color.WHITE))
        z_lbl.custom_minimum_size.x = 50
        row.add_child(z_lbl)
        
        var m_name = Label.new()
        m_name.text = m.monster_name
        m_name.add_theme_font_size_override("font_size", 28)
        m_name.add_theme_color_override("font_color", color)
        row.add_child(m_name)
        
        element_grid.add_child(row)

    # Toggle Logic
    panel.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            var show = !element_grid.visible
            element_grid.visible = show
            separator.visible = show
            arrow.text = " ▲" if show else " ▼"
    )
    
    grid.add_child(panel)

func _get_synergy_text(group: int, count: int) -> String:
    var c_val = "#60fafc" # Cyan for values
    var c_lbl = "#a0a0a0" # Grey for labels
    
    var total = _group_totals.get(group, 0)
    var c_fs = c_lbl
    var fs_lbl_txt = "Full Set"
    
    if total > 0 and count >= total:
        c_fs = "#ffd700"
        fs_lbl_txt = "Full Set (ACTIVE)"
        
    var text = ""
    
    match group:
        AtomicConfig.Group.ALKALI_METAL:
            var val = count * 5
            text = "[color=%s]Synergy:[/color] Ignore [color=%s]%d%%[/color] Defense (5%%/elem).\n[color=%s]Passive:[/color] High Defense Penetration.\n[color=%s]%s:[/color] First attack deals 2x damage." % [c_lbl, c_val, val, c_lbl, c_fs, fs_lbl_txt]
        AtomicConfig.Group.ALKALINE_EARTH:
            var val = count * 5
            text = "[color=%s]Synergy:[/color] [color=%s]+%d%%[/color] Base Defense (5%%/elem).\n[color=%s]Passive:[/color] Gain +5%% Defense every turn.\n[color=%s]%s:[/color] Immune to first instance of damage." % [c_lbl, c_val, val, c_lbl, c_fs, fs_lbl_txt]
        AtomicConfig.Group.TRANSITION_METAL:
            var val = count * 2
            text = "[color=%s]Synergy:[/color] [color=%s]%d%%[/color] Double Hit Chance (2%%/elem).\n[color=%s]Passive:[/color] Consecutive attacks deal +5%% Damage.\n[color=%s]%s:[/color] +15%% Double Hit Chance." % [c_lbl, c_val, val, c_lbl, c_fs, fs_lbl_txt]
        AtomicConfig.Group.HALOGEN:
            var val = count * 1
            text = "[color=%s]Synergy:[/color] [color=%s]+%d%%[/color] Poison Damage (1%%/elem).\n[color=%s]Passive:[/color] Attacks apply Poison (10%% HP/turn).\n[color=%s]%s:[/color] Poison lasts +1 turn." % [c_lbl, c_val, val, c_lbl, c_fs, fs_lbl_txt]
        AtomicConfig.Group.NOBLE_GAS:
            var val = count * 5
            text = "[color=%s]Synergy:[/color] [color=%s]+%d%%[/color] Base HP (5%%/elem).\n[color=%s]Passive:[/color] Restore 5%% HP every turn.\n[color=%s]%s:[/color] Immune to all debuffs." % [c_lbl, c_val, val, c_lbl, c_fs, fs_lbl_txt]
        AtomicConfig.Group.LANTHANIDE:
            var val = count * 1
            text = "[color=%s]Synergy:[/color] [color=%s]+%d%%[/color] All Stats (1%%/elem).\n[color=%s]Passive:[/color] Absorb 10%% of fallen enemy stats.\n[color=%s]%s:[/color] +10%% All Stats to ALL elements." % [c_lbl, c_val, val, c_lbl, c_fs, fs_lbl_txt]
        AtomicConfig.Group.NONMETAL:
            var val = count * 5
            text = "[color=%s]Synergy:[/color] [color=%s]%d%%[/color] Chain Reaction Chance (5%%/elem).\n[color=%s]Passive:[/color] Allies gain +5%% Attack per Nonmetal.\n[color=%s]%s:[/color] Guaranteed Chain Reaction." % [c_lbl, c_val, val, c_lbl, c_fs, fs_lbl_txt]
        AtomicConfig.Group.METALLOID:
            var val = count * 5
            text = "[color=%s]Synergy:[/color] [color=%s]+%d%%[/color] Debuff Effect (5%%/elem).\n[color=%s]Passive:[/color] 10%% Chance to Stun on hit.\n[color=%s]%s:[/color] Debuffs last +1 turn." % [c_lbl, c_val, val, c_lbl, c_fs, fs_lbl_txt]
        AtomicConfig.Group.POST_TRANSITION:
            var val = count * 5
            text = "[color=%s]Synergy:[/color] [color=%s]+%d%%[/color] Buff Effect (5%%/elem).\n[color=%s]Passive:[/color] Gain +1%% All Stats every turn.\n[color=%s]%s:[/color] Buffs last +1 turn." % [c_lbl, c_val, val, c_lbl, c_fs, fs_lbl_txt]
        AtomicConfig.Group.ACTINIDE:
            var val = count * 1
            text = "[color=%s]Synergy:[/color] [color=%s]+%d%%[/color] Base Speed (1%%/elem).\n[color=%s]Passive:[/color] Lose 10%% HP to deal +10%% Max HP Dmg.\n[color=%s]%s:[/color] Gain +3%% Speed every turn." % [c_lbl, c_val, val, c_lbl, c_fs, fs_lbl_txt]
        _:
            text = "Unknown Synergy."
            
    var mastery = AtomicConfig.MASTERY_BONUSES.get(group, "")
    if mastery != "":
        mastery = mastery.replace("Mastery: ", "")
        text += "\n[color=#ffd700]Mastery (100% Stability):[/color] " + mastery
        
    return text

func _on_back_pressed():
    # Return to the Periodic Table since that's likely where we came from
    GlobalManager.switch_scene("periodic_table")
