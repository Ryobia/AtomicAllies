extends Control

@export var icon_discovery: Texture2D
@export var icon_fusion: Texture2D

@onready var title_label = find_child("TitleLabel", true, false)
@onready var desc_label = find_child("DescriptionLabel", true, false)
@onready var reward_label = find_child("RewardLabel", true, false)
@onready var claim_btn = find_child("ClaimButton", true, false)
@onready var close_btn = find_child("CloseButton", true, false)
@onready var goto_btn = find_child("GoToButton", true, false)
@onready var icon_rect = find_child("QuestIcon", true, false)

func _ready():
    if close_btn:
        close_btn.pressed.connect(func(): visible = false)
    if claim_btn:
        claim_btn.pressed.connect(_on_claim_pressed)
    if goto_btn:
        goto_btn.pressed.connect(_on_goto_pressed)
    
    # Update whenever shown
    visibility_changed.connect(func():
        if visible: update_ui()
    )

func update_ui():
    if not PlayerData: return
    
    var z = int(PlayerData.quest_data.get("z", 3))
    var stage = int(PlayerData.quest_data.get("stage", 0))
    
    if z > 118:
        _show_complete()
        return
        
    var monster = MonsterManifest.get_monster(z)
    var m_name = monster.monster_name if monster else "Element #%d" % z
    
    var is_complete = false
    var reward_text = ""
    
    if stage == 0:
        # Quest: Discovery Run
        title_label.text = "Current Objective: Discovery"
        desc_label.text = "Complete the Discovery Run for %s (Z-%d)." % [m_name, z]
        
        var energy_reward = AtomicConfig.calculate_fusion_cost(z)
        reward_text = "Reward: %d Binding Energy" % energy_reward
        
        # Check completion: Do we have the blueprint?
        if z in PlayerData.unlocked_blueprints:
            is_complete = true
            
    elif stage == 1:
        # Quest: Fusion
        title_label.text = "Current Objective: Synthesis"
        desc_label.text = "Synthesize a new %s in the Nursery." % m_name
        
        reward_text = "Reward: 100 Neutron Dust"
        
        # Check completion: Do we own the monster?
        if PlayerData.is_monster_owned(m_name):
            is_complete = true
    
    reward_label.text = reward_text
    
    if is_complete:
        claim_btn.text = "CLAIM REWARD"
        claim_btn.disabled = false
        claim_btn.modulate = Color("#ffd700") # Gold
        if goto_btn: goto_btn.visible = false
    else:
        claim_btn.text = "IN PROGRESS"
        claim_btn.disabled = true
        claim_btn.modulate = Color(0.5, 0.5, 0.5)
        if goto_btn:
            goto_btn.visible = true
            if stage == 0:
                goto_btn.text = "GO TO COLLECTION"
            elif stage == 1:
                goto_btn.text = "GO TO NEXUS"
        
    if icon_rect:
        if stage == 0 and icon_discovery:
            icon_rect.texture = icon_discovery
        elif stage == 1 and icon_fusion:
            icon_rect.texture = icon_fusion
        elif monster:
            icon_rect.texture = monster.icon

func _on_claim_pressed():
    var z = int(PlayerData.quest_data.get("z", 3))
    var stage = int(PlayerData.quest_data.get("stage", 0))
    
    # Grant Reward
    if stage == 0:
        var energy = AtomicConfig.calculate_fusion_cost(z)
        PlayerData.add_resource("binding_energy", energy)
        # Advance to Fusion stage
        PlayerData.quest_data["stage"] = 1
    elif stage == 1:
        PlayerData.add_resource("neutron_dust", 100)
        # Advance to next Element Run
        PlayerData.quest_data["z"] = z + 1
        PlayerData.quest_data["stage"] = 0
        
    PlayerData.save_game()
    update_ui()
    
    # Visual feedback
    var tween = create_tween()
    tween.tween_property(self, "scale", Vector2(1.05, 1.05), 0.1)
    tween.tween_property(self, "scale", Vector2.ONE, 0.1)

func _on_goto_pressed():
    var stage = int(PlayerData.quest_data.get("stage", 0))
    if stage == 0:
        GlobalManager.switch_scene("periodic_table")
    elif stage == 1:
        GlobalManager.switch_scene("nexus")
    visible = false

func _show_complete():
    title_label.text = "All Quests Complete!"
    desc_label.text = "You have synthesized all known elements."
    reward_label.text = ""
    claim_btn.visible = false
    if goto_btn: goto_btn.visible = false
