# c:\Users\ryobi\Projects\nexus\Scripts\LegendItem.gd
extends PanelContainer

@onready var color_rect = $MarginContainer/HBoxContainer/ColorRect
@onready var title_label = $MarginContainer/HBoxContainer/VBoxContainer/TitleLabel
@onready var desc_label = $MarginContainer/HBoxContainer/VBoxContainer/DescLabel

const VIE_DESCRIPTIONS = {
	AtomicConfig.Group.ALKALI_METAL: "Primers. Fast attackers that apply massive amounts of Reduced [R] stacks.",
	AtomicConfig.Group.ALKALINE_EARTH: "Vanguards. Sturdy tanks that punish attackers with [R] stacks.",
	AtomicConfig.Group.TRANSITION_METAL: "Catalysts. Bruisers that manipulate cooldowns and action gauges.",
	AtomicConfig.Group.POST_TRANSITION: "Utility. Supports the team with heals, shields, and cleanses.",
	AtomicConfig.Group.METALLOID: "Semiconductors. Manipulate the battlefield and amplify Oxidation Bursts.",
	AtomicConfig.Group.NONMETAL: "Detonators. Consume Reduced [R] stacks to trigger massive Oxidation Bursts.",
	AtomicConfig.Group.HALOGEN: "Reactive Detonators. High-speed oxidizers that thrive on continuous reactions.",
	AtomicConfig.Group.NOBLE_GAS: "Stabilizers. Inert walls that protect the team and manage Entropy.",
	AtomicConfig.Group.ACTINIDE: "Fission Nukes. Slow, unstable heavy-hitters with exponential damage scaling.",
	AtomicConfig.Group.LANTHANIDE: "Magnetic Amplifiers. Condense debuffs onto targets to set up massive combos."
}

func setup(group: int, description: String):
	# Set the color based on the Atomic Group
	var color = AtomicConfig.GROUP_COLORS.get(group, Color.WHITE)
	if color_rect:
		color_rect.color = color
	
	# Set the Title
	var group_name = AtomicConfig.Group.find_key(group).replace("_", " ").capitalize()
	if title_label:
		title_label.text = group_name
		title_label.add_theme_color_override("font_color", color)
		title_label.add_theme_color_override("font_outline_color", color.darkened(0.5))
	
	# Set the Description
	if desc_label:
		desc_label.text = VIE_DESCRIPTIONS.get(group, description)
