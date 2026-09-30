extends SceneTree


func _initialize() -> void:
	var theme := load("res://scenes/ui/skins/signal_theme.tres").duplicate(true) as Theme
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Arial"])
	theme.default_font = font
	for grade in ["grace", "safe", "near", "urgent"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.07, 0.12, 0.16, 0.96)
		box.border_color = Color("ff685c") if grade == "urgent" else (Color("ffd166") if grade == "near" else Color("45dccb"))
		box.set_border_width_all(1)
		box.border_width_left = 4
		box.set_corner_radius_all(6)
		box.content_margin_left = 12
		box.content_margin_right = 12
		box.content_margin_top = 9
		box.content_margin_bottom = 9
		theme.set_stylebox("panel", "ChaseHUD" + grade.capitalize(), box)
	for reason in ["spike", "fall", "caught"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("18212b")
		box.border_color = Color("ff685c")
		box.set_border_width_all(1)
		box.border_width_top = 4
		box.set_corner_radius_all(8)
		box.set_content_margin_all(14)
		theme.set_stylebox("panel", "ChaseFailure" + reason.capitalize(), box)
	var error := ResourceSaver.save(theme, "res://scenes/ui/skins/chase_theme.tres")
	if error != OK:
		push_error("Cannot save chase theme: %s" % error)
	quit(error)
