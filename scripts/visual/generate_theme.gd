extends SceneTree


func _initialize() -> void:
	var theme := Theme.new()
	theme.set_color("font_color", "Label", Color("f8fbfa"))
	theme.set_color("font_color", "Button", Color("18212b"))
	theme.set_color("font_hover_color", "Button", Color("18212b"))
	theme.set_color("font_pressed_color", "Button", Color("f8fbfa"))
	theme.set_color("font_disabled_color", "Button", Color("71818a"))
	theme.set_font_size("font_size", "Label", 20)
	theme.set_font_size("font_size", "Button", 20)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("e6efed") if state == "normal" else Color("ffd166")
		if state == "pressed":
			box.bg_color = Color("334554")
		elif state == "focus":
			box.bg_color = Color(0, 0, 0, 0)
		elif state == "disabled":
			box.bg_color = Color("667984")
		box.border_color = Color("ffd166") if state == "focus" else Color("18212b")
		box.set_border_width_all(2)
		box.set_corner_radius_all(5)
		box.content_margin_left = 14
		box.content_margin_right = 14
		box.content_margin_top = 7
		box.content_margin_bottom = 7
		theme.set_stylebox(state, "Button", box)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.094, 0.129, 0.169, 0.95)
	panel.border_color = Color("456070")
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(8)
	panel.set_content_margin_all(12)
	theme.set_stylebox("panel", "Panel", panel)
	var path := "res://scenes/ui/skins/signal_theme.tres"
	var error := ResourceSaver.save(theme, path)
	if error != OK:
		push_error("Failed to save theme: %s" % error)
	quit(error)
