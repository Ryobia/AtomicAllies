extends Node

# Emitted when the user successfully finishes watching a rewarded ad
signal reward_earned(reward_type, amount)

# Note: The exact class names (MobileAds, RewardedAd) depend on the Poing Studios AdMob plugin.
# Ensure the plugin is installed and activated.
var rewarded_ad
var _auto_play_requested: bool = false

func _ready() -> void:
	# Initialize the AdMob SDK if the plugin is present
	if Engine.has_singleton("MobileAds"):
		MobileAds.initialize()
		_load_rewarded_ad()
	else:
		push_warning("AdMob plugin not found. Ads will not load.")

func _load_rewarded_ad() -> void:
	# This is Google's official Test ID for Rewarded Ads.
	# Replace with your actual Ad Unit ID before publishing to the App Store/Google Play!
	var unit_id = "ca-app-pub-3940256099942544/5224354917"
	var ad_request = AdRequest.new()
	
	# Poing Studios v4+ uses Callbacks instead of direct instantiation
	var load_callback = RewardedAdLoadCallback.new()
	load_callback.on_ad_loaded = _on_rewarded_ad_loaded
	load_callback.on_ad_failed_to_load = _on_rewarded_ad_failed_to_load
	
	# Use the RewardedAdLoader to fetch the ad
	RewardedAdLoader.new().load(unit_id, ad_request, load_callback)

func _on_rewarded_ad_loaded(ad) -> void:
	rewarded_ad = ad
	
	var full_screen_callback = FullScreenContentCallback.new()
	full_screen_callback.on_ad_dismissed_full_screen_content = _on_ad_dismissed
	full_screen_callback.on_ad_failed_to_show_full_screen_content = _on_ad_failed_to_show
	rewarded_ad.full_screen_content_callback = full_screen_callback
	
	# If the user pressed the button while we were waiting, show it immediately now that it's ready
	if _auto_play_requested:
		_auto_play_requested = false
		show_rewarded_ad()

func _on_rewarded_ad_failed_to_load(error) -> void:
	print("Ad failed to load: ", error.message)
	if _auto_play_requested:
		show_toast("Transmission failed to load.")
	_auto_play_requested = false # Reset so it doesn't get stuck if it fails

func show_rewarded_ad() -> void:
	if rewarded_ad:
		var reward_listener = OnUserEarnedRewardListener.new()
		reward_listener.on_user_earned_reward = _on_user_earned_reward
		rewarded_ad.show(reward_listener)
	else:
		_auto_play_requested = true
		show_toast("Transmission loading... Please wait.")
		_load_rewarded_ad() # Attempt to load one for next time

func show_toast(message: String) -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 100 # Put it on top of everything
	get_tree().root.add_child(canvas)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	center.position.y = 50
	canvas.add_child(center)
	
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.8)
	style.border_color = Color("#ffd700")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)
	
	var label = Label.new()
	label.text = message
	label.add_theme_font_size_override("font_size", 46)
	label.add_theme_color_override("font_color", Color("#ffd700"))
	margin.add_child(label)
	
	# Animate the toast popping down and fading in
	center.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(center, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(center, "position:y", 100.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(2.0)
	tween.tween_property(center, "modulate:a", 0.0, 0.3)
	tween.tween_callback(canvas.queue_free)

func _on_user_earned_reward(reward_item) -> void:
	# The user watched the whole ad! Emit a signal so your game logic can give the reward.
	print("Ad complete! Reward earned.")
	reward_earned.emit(reward_item.type, reward_item.amount)

func _on_ad_dismissed() -> void:
	rewarded_ad = null
	_load_rewarded_ad()

func _on_ad_failed_to_show(error) -> void:
	print("Ad failed to show: ", error.message)
	rewarded_ad = null
	_load_rewarded_ad()
