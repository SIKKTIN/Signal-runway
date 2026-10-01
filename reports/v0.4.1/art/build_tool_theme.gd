extends SceneTree
const TARGET := "res://scenes/tools/generation_editor_theme.tres"
var theme := Theme.new()
const FG := Color("e6efed")
const MUTED := Color("a8bbc4")
const CYAN := Color("45dccb")
const GOLD := Color("ffd166")
const RED := Color("ff685c")

func box(background: Color, border: Color, width: int = 1, horizontal: float = 10, vertical: float = 7) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(4)
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style

func _initialize() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "Arial"])
	theme.default_font = font
	theme.default_font_size = 15
	var normal := box(Color("20313c"), Color("405a65"))
	var hover := box(Color("2d4652"), CYAN)
	var pressed := box(CYAN, CYAN)
	var disabled := box(Color("182731"), Color("30444f"))
	var focus := box(Color(0,0,0,0), GOLD, 2, 0, 0)
	for type in ["Button", "OptionButton", "MenuButton"]:
		for pair in [["normal",normal],["hover",hover],["pressed",pressed],["disabled",disabled],["focus",focus]]:
			theme.set_stylebox(pair[0], type, pair[1])
		for state in ["font_color", "font_hover_color", "font_focus_color"]:
			theme.set_color(state, type, FG)
		theme.set_color("font_pressed_color", type, Color("18212b"))
		theme.set_color("font_disabled_color", type, Color("829aa5"))
		theme.set_font_size("font_size", type, 15)
	theme.set_type_variation("ToolPrimary", "Button")
	theme.set_stylebox("normal", "ToolPrimary", pressed)
	theme.set_stylebox("hover", "ToolPrimary", box(Color("72e7da"), CYAN))
	theme.set_stylebox("pressed", "ToolPrimary", box(Color("2fae9f"), CYAN))
	for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		theme.set_color(color, "ToolPrimary", Color("18212b"))
	var panel := box(Color("182b36"), Color("304854"), 1, 12, 10)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PanelContainer", panel)
	for pair in [["ToolSelected", CYAN], ["ToolWarning", GOLD], ["ToolError", RED]]:
		theme.set_type_variation(pair[0], "PanelContainer")
		var state := box(Color("182b36"), pair[1], 2 if pair[0] == "ToolSelected" else 1, 12, 10)
		if pair[0] != "ToolSelected":
			state.border_width_left = 4
		theme.set_stylebox("panel", pair[0], state)
	theme.set_color("font_color", "Label", FG)
	for pair in [["ToolTitle", 18, FG], ["ToolMuted",14,MUTED], ["ToolWarningText",15,GOLD], ["ToolErrorText",15,RED]]:
		theme.set_type_variation(pair[0], "Label")
		theme.set_font_size("font_size", pair[0], pair[1])
		theme.set_color("font_color", pair[0], pair[2])
	for type in ["LineEdit", "TextEdit"]:
		theme.set_stylebox("normal", type, box(Color("111f29"), Color("405a65")))
		theme.set_stylebox("read_only", type, box(Color("182731"), Color("30444f")))
		theme.set_stylebox("focus", type, focus)
		theme.set_color("font_color", type, FG)
		theme.set_color("font_uneditable_color", type, MUTED)
		theme.set_color("caret_color", type, CYAN)
		theme.set_color("selection_color", type, Color("2c615c"))
		theme.set_color("font_selected_color", type, FG)
		theme.set_font_size("font_size", type, 15)
	for type in ["CheckBox", "CheckButton"]:
		for state in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
			theme.set_stylebox(state, type, box(Color(0,0,0,0), Color(0,0,0,0), 0, 4, 5))
		theme.set_stylebox("focus", type, focus)
		theme.set_color("font_color", type, FG)
		theme.set_color("font_hover_color", type, FG)
		theme.set_color("font_pressed_color", type, FG)
		theme.set_color("font_disabled_color", type, MUTED)
	theme.set_stylebox("panel", "PopupMenu", box(Color("182b36"), Color("405a65")))
	theme.set_stylebox("hover", "PopupMenu", hover)
	theme.set_color("font_color", "PopupMenu", FG)
	theme.set_color("font_hover_color", "PopupMenu", FG)
	for type in ["ItemList", "Tree"]:
		theme.set_stylebox("panel", type, box(Color("111f29"), Color("304854")))
		for state in ["selected", "selected_focus", "cursor", "cursor_unfocused"]:
			theme.set_stylebox(state, type, box(Color("254d50"), CYAN, 1, 4, 4))
		theme.set_stylebox("focus", type, focus)
		theme.set_color("font_color", type, FG)
		theme.set_color("font_selected_color", type, FG)
	theme.set_color("default_color", "RichTextLabel", FG)
	theme.set_font_size("normal_font_size", "RichTextLabel", 15)
	for type in ["HScrollBar", "VScrollBar"]:
		theme.set_stylebox("scroll", type, box(Color("111f29"), Color("111f29"), 0, 4, 4))
		theme.set_stylebox("grabber", type, box(Color("405a65"), Color("405a65"), 0, 4, 4))
		theme.set_stylebox("grabber_highlight", type, box(CYAN, CYAN, 0, 4, 4))
		theme.set_stylebox("grabber_pressed", type, box(CYAN, CYAN, 0, 4, 4))
	theme.set_constant("separation", "VBoxContainer", 8)
	theme.set_constant("separation", "HBoxContainer", 8)
	theme.set_constant("h_separation", "GridContainer", 8)
	theme.set_constant("v_separation", "GridContainer", 8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/tools"))
	var error := ResourceSaver.save(theme, TARGET)
	print("tool_theme_saved: ", error == OK)
	quit(error)
