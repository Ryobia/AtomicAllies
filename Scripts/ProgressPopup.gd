extends Control

@onready var close_btn = find_child("CloseButton", true, false)
@onready var stats_container = find_child("StatsContainer", true, false)
@onready var synergy_grid = find_child("SynergyGrid", true, false)

func _ready():
    if close_btn:
        close_btn.pressed.connect(func(): visible = false)
    
    visibility_changed.connect(func():
        if visible: update_progress()
    )

func update_progress():
    if not PlayerData: return
    
    # 1. Calculate Main Stats
    var total_elements = 118
    var blueprints = PlayerData.unlocked_blueprints.size()
    
    var unique_collected = {}
    var unique_mastered = {}
    
    for m in PlayerData.owned_monsters:
        unique_collected[m.atomic_number] = true
        if m.stability >= 100:
            unique_mastered[m.atomic_number] = true
            
    var collected_count = unique_collected.size()
    var mastered_count = unique_mastered.size()
    
    # Update Labels
    var runs_lbl = stats_container.find_child("RunsLabel", true, false)
    if runs_lbl: runs_lbl.text = "Discovery Runs: %d / %d" % [blueprints, total_elements]
    
    var col_lbl = stats_container.find_child("CollectedLabel", true, false)
    if col_lbl: col_lbl.text = "Elements Collected: %d / %d" % [collected_count, total_elements]
    
    var mast_lbl = stats_container.find_child("MasteredLabel", true, false)
    if mast_lbl: mast_lbl.text = "Mastered (100%%): %d / %d" % [mastered_count, total_elements]

    # 2. Synergies
    if synergy_grid:
        for child in synergy_grid.get_children():
            child.queue_free()
            
        # Calculate totals per group
        var group_totals = {}
        if MonsterManifest:
            for m in MonsterManifest.all_monsters:
                if not group_totals.has(m.group): group_totals[m.group] = 0
                group_totals[m.group] += 1
        
        for group in AtomicConfig.GROUP_COLORS:
            if group >= AtomicConfig.Group.UNKNOWN: continue
            
            var owned = PlayerData.class_resonance.get(group, 0)
            var total = group_totals.get(group, 0)
            
            # Skip if no monsters of this group exist in manifest (e.g. not implemented yet)
            if total == 0: continue
            
            var row = HBoxContainer.new()
            synergy_grid.add_child(row)
            
            var color = AtomicConfig.GROUP_COLORS[group]
            
            var name_lbl = Label.new()
            name_lbl.text = AtomicConfig.Group.find_key(group).replace("_", " ").capitalize()
            name_lbl.add_theme_color_override("font_color", color)
            name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            name_lbl.add_theme_font_size_override("font_size", 32)
            row.add_child(name_lbl)
            
            var count_lbl = Label.new()
            count_lbl.text = "%d / %d" % [owned, total]
            count_lbl.add_theme_color_override("font_color", Color.WHITE)
            count_lbl.add_theme_font_size_override("font_size", 32)
            row.add_child(count_lbl)
