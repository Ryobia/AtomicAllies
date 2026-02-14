extends PanelContainer

func _ready():
    var close_btn = find_child("CloseButton", true, false)
    if close_btn:
        close_btn.pressed.connect(func(): visible = false)
    
    print("FusionCheatSheet: Initializing...")
    call_deferred("_populate_recipes")
    
    # Optional: Force UI to update layout and re-center
    visibility_changed.connect(func():
        if visible:
            reset_size() # Shrinks to min_size or content size
            set_anchors_preset(Control.PRESET_CENTER))

func _populate_recipes():
    var list = find_child("RecipeList", true, false)
    if not list:
        push_error("FusionCheatSheet Error: Could not find node named 'RecipeList'. Please check Scene Tree.")
        return
    
    print("FusionCheatSheet: Found list at ", list.get_path())
    # Clear placeholders
    for child in list.get_children():
        child.queue_free()
    
    # The "First 10" Cheat Sheet
    var recipes = [
        { "result": "Helium (2)", "formula": "H (1) + H (1)" },
        { "result": "Lithium (3)", "formula": "He (2) + H (1)" },
        { "result": "Beryllium (4)", "formula": "He (2) + He (2)" },
        { "result": "Boron (5)", "formula": "Be (4) + H (1)" },
        { "result": "Carbon (6)", "formula": "Be (4) + He (2)" },
        { "result": "Nitrogen (7)", "formula": "C (6) + H (1)" },
        { "result": "Oxygen (8)", "formula": "C (6) + He (2)" },
        { "result": "Fluorine (9)", "formula": "O (8) + H (1)" },
        { "result": "Neon (10)", "formula": "O (8) + He (2)" },
    ]
    
    for r in recipes:
        var row = HBoxContainer.new()
        row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        
        var lbl_res = Label.new()
        lbl_res.text = r.result
        lbl_res.custom_minimum_size.x = 140
        lbl_res.modulate = Color(1, 0.8, 0.2) # Gold
        
        var lbl_form = Label.new()
        lbl_form.text = "=  " + r.formula
        
        row.add_child(lbl_res)
        row.add_child(lbl_form)
        
        list.add_child(row)

    print("FusionCheatSheet: Populated ", recipes.size(), " recipes.")