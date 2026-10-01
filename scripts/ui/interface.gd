extends CanvasLayer

signal start_requested
signal time_trial_requested
signal lab_requested
signal resume_requested
signal restart_requested
signal menu_requested
signal endless_requested
signal new_seed_requested

var root_control: Control
var overlay: ColorRect
var hud: Control
var time_label: Label
var death_label: Label
var best_label: Label
var section_label: Label
var notice: Label
var progress: ColorRect
var progress_fill: ColorRect
var card: PanelContainer
var content: VBoxContainer
var theme_resource: Theme
var current_mode := "pursuit"
var selected_level := "relay_station"
var current_level := "level01"
var relay_counter: Label
var relay_count := 0
var brand_label: Label
var count_title: Label
var best_title: Label
var keys_label: Label
var external_endless_hud := false
var endless_pause: Button
var chase_theme_resource: Theme
var section_names := ["01  安全教学", "02  单项练习", "03  组合挑战", "04  终点冲刺"]

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)
	theme_resource = Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	theme_resource.default_font = font
	theme_resource.default_font_size = 16
	root_control.theme = theme_resource
	var skin_path := "res://scenes/ui/skins/signal_theme.tres"
	if ResourceLoader.exists(skin_path):
		theme_resource = load(skin_path).duplicate()
		theme_resource.default_font = font
		root_control.theme = theme_resource
	if ResourceLoader.exists("res://scenes/ui/skins/chase_theme.tres"):
		chase_theme_resource = load("res://scenes/ui/skins/chase_theme.tres")
	_build_hud()
	endless_pause = Button.new()
	endless_pause.text = "暂停 Esc"
	endless_pause.position = Vector2(832, 30)
	endless_pause.size = Vector2(104, 52)
	endless_pause.pressed.connect(func(): resume_requested.emit())
	root_control.add_child(endless_pause)
	endless_pause.hide()
	overlay = ColorRect.new()
	overlay.color = Color(0.035, 0.06, 0.09, 0.90)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(overlay)
	card = PanelContainer.new()
	card.position = Vector2(252, 20)
	card.size = Vector2(456, 400)
	card.add_theme_stylebox_override("panel", panel_style(Color("182b36"), Color("45dccb")))
	overlay.add_child(card)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	card.add_child(margin)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

func panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.border_width_top = 3
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	return style

func _label(text: String, font_size: int = 16, color: Color = Color("e6efed")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(hud)
	var strip := PanelContainer.new()
	strip.position = Vector2(24, 20)
	strip.size = Vector2(912, 72)
	strip.add_theme_stylebox_override("panel", panel_style(Color(0.08, 0.14, 0.18, 0.93), Color("334554")))
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(strip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	strip.add_child(row)
	var brand := VBoxContainer.new()
	brand.custom_minimum_size.x = 245
	row.add_child(brand)
	brand_label = _label("SIGNAL RUN   /   " + _version(), 12, Color("45dccb"))
	brand.add_child(brand_label)
	section_label = _label("01  安全教学", 21)
	brand.add_child(section_label)
	var clock_box := VBoxContainer.new()
	row.add_child(clock_box)
	clock_box.add_child(_label("本轮用时", 11, Color("607987")))
	time_label = _label("00:00.00", 25)
	clock_box.add_child(time_label)
	var deaths_box := VBoxContainer.new()
	row.add_child(deaths_box)
	count_title = _label("进度", 11, Color("607987"))
	deaths_box.add_child(count_title)
	death_label = _label("00", 25, Color("ff685c"))
	deaths_box.add_child(death_label)
	var best_box := VBoxContainer.new()
	best_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(best_box)
	best_title = _label("会话最佳", 11, Color("607987"))
	best_box.add_child(best_title)
	best_label = _label("—", 25, Color("ffd166"))
	best_box.add_child(best_label)
	var pause_button := Button.new()
	pause_button.text = "暂停  Esc"
	pause_button.custom_minimum_size = Vector2(100, 42)
	pause_button.pressed.connect(func(): resume_requested.emit())
	row.add_child(pause_button)
	progress = ColorRect.new()
	progress.position = Vector2(24, 98)
	progress.size = Vector2(912, 3)
	progress.color = Color("334554")
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress_fill = ColorRect.new()
	progress_fill.color = Color("45dccb")
	progress_fill.size = Vector2(0, 3)
	progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.add_child(progress_fill)
	hud.add_child(progress)
	notice = _label("", 16, Color("45dccb"))
	notice.position = Vector2(24, 112)
	hud.add_child(notice)
	relay_counter = _label("", 14, Color("ffd166"))
	relay_counter.position = Vector2(24, 140)
	hud.add_child(relay_counter)
	keys_label = _label("A/D 移动    SPACE 跳跃    R 新挑战    ESC 暂停    F2 测试房", 12, Color("8ca2ac"))
	keys_label.position = Vector2(24, 510)
	hud.add_child(keys_label)

func _clear_card() -> void:
	endless_pause.hide()
	card.add_theme_stylebox_override("panel", panel_style(Color("182b36"), Color("45dccb")))
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	card.custom_minimum_size = Vector2(456, 0)
	card.size = Vector2(456, 0)
	overlay.show()

func _text(text: String, size: int = 16, color: Color = Color("e6efed")) -> void:
	var label := _label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 392
	content.add_child(label)

func _button(text: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(392, 38)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_stylebox_override("normal", panel_style(Color("45dccb") if primary else Color("213845"), Color("45dccb") if primary else Color("405a65")))
	button.add_theme_color_override("font_color", Color("18212b") if primary else Color("e6efed"))
	button.add_theme_color_override("font_hover_color", Color("18212b"))
	button.add_theme_color_override("font_focus_color", Color("18212b") if primary else Color("e6efed"))
	button.pressed.connect(callback)
	content.add_child(button)
	return button

func show_menu() -> void:
	_clear_card()
	hud.hide()
	_text("SIGNAL RUN  /  " + _version(), 12, Color("45dccb"))
	_text("信号跑道", 38)
	_text("信号正在崩塌，保持前进。", 18, Color("8ca2ac"))
	var selector := OptionButton.new()
	selector.custom_minimum_size = Vector2(392, 36)
	selector.add_item("断线中继站 · 可选中继与分支", 0)
	selector.add_item("原首关 · 四段跑道", 1)
	selector.select(0 if selected_level == "relay_station" else 1)
	selector.item_selected.connect(func(index: int): selected_level = "relay_station" if index == 0 else "level01")
	content.add_child(selector)
	var start := _button("无限挑战   ENTER", func(): endless_requested.emit(), true)
	_button("所选固定关 · 追赶挑战", func(): start_requested.emit())
	_button("计时挑战 · 原规则", func(): time_trial_requested.emit())
	_button("进入控制测试房   F2", func(): lab_requested.emit())
	_text("无限自动跑；固定关A/D移动。Space跳跃，R同图重试。", 12, Color("8ca2ac"))
	start.grab_focus()

func show_playing() -> void:
	overlay.hide()
	hud.visible = not (external_endless_hud and current_level == "endless")
	endless_pause.visible = external_endless_hud and current_level == "endless"
	get_viewport().gui_release_focus()

func show_pause() -> void:
	_clear_card()
	_text("暂停", 38)
	_text("时间已暂停，路线会在原地等你。", 16, Color("8ca2ac"))
	var resume := _button("继续   ESC", func(): resume_requested.emit(), true)
	_button("重新挑战   R", func(): restart_requested.emit())
	_button("返回开始界面", func(): menu_requested.emit())
	resume.grab_focus()

func show_result(seconds: float, count: int, best: float, lab: bool) -> void:
	_clear_card()
	_text("LAB COMPLETE" if lab else "ROUTE COMPLETE", 12, Color("ffd166"))
	_text("测试房通过" if lab else "抵达终点", 38)
	_text(format_time(seconds), 40, Color("45dccb"))
	_text("会话最佳 %s" % (format_time(best) if best >= 0 else "—"), 15)
	_text("已逃离信号崩塌 · 暂停不计时" if current_mode == "pursuit" and not lab else "死亡 %d 次 · 用时包含死亡恢复，暂停不计时。" % count, 12, Color("8ca2ac"))
	if current_level == "relay_station" and not lab:
		_text("中继接入 %d / 2" % relay_count, 14, Color("ffd166"))
	var restart := _button("再次挑战   ENTER", func(): restart_requested.emit(), true)
	_button("返回开始界面", func(): menu_requested.emit())
	restart.grab_focus()

func update_stats(seconds: float, count: int, best: float, fraction: float, section: int, lab: bool) -> void:
	time_label.text = format_time(seconds)
	death_label.text = "%d%%" % int(fraction * 100.0) if current_mode == "pursuit" and not lab else "%02d" % count
	best_label.text = format_time(best) if best >= 0 else "—"
	section_label.text = "控制测试房" if lab else section_names[section]
	progress_fill.size.x = 912 * clampf(fraction, 0.0, 1.0)

func set_notice(text: String, color: Color) -> void:
	notice.text = text
	notice.add_theme_color_override("font_color", color)

func format_time(seconds: float) -> String:
	return "%02d:%05.2f" % [int(seconds) / 60, fmod(seconds, 60.0)]

func set_mode(value: String) -> void:
	current_mode = value
	brand_label.text = ("PURSUIT" if value == "pursuit" else "TIME TRIAL") + "   /   " + _version()
	count_title.text = "进度" if value == "pursuit" else "死亡"

func show_failure(reason: String, seconds: float, fraction: float, best: float) -> void:
	_clear_card()
	var style_type := "ChaseFailure" + reason.capitalize()
	if chase_theme_resource and chase_theme_resource.has_stylebox("panel", style_type):
		card.add_theme_stylebox_override("panel", chase_theme_resource.get_stylebox("panel", style_type))
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	var icon_path := "res://assets/visual/v02/failure_%s.png" % reason
	if ResourceLoader.exists(icon_path):
		var icon := TextureRect.new()
		icon.texture = load(icon_path)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(32, 32)
		header.add_child(icon)
	header.add_child(_label("SIGNAL LOST", 12, Color("ff685c")))
	content.add_child(header)
	_text({"spike": "撞上尖刺", "fall": "坠入空隙", "caught": "被崩塌吞没"}.get(reason, "挑战结束"), 36)
	_text(format_time(seconds), 40, Color("ff685c"))
	_text("最远进度 %d%%   /   最佳通关 %s" % [int(fraction * 100.0), format_time(best) if best >= 0 else "—"], 14)
	_text("重开会重置跑道、追赶与计时。", 13, Color("8ca2ac"))
	if current_level == "relay_station":
		_text("中继接入 %d / 2" % relay_count, 14, Color("ffd166"))
	var restart := _button("再次挑战   ENTER / R", func(): restart_requested.emit(), true)
	_button("返回开始界面", func(): menu_requested.emit())
	restart.grab_focus()

func set_course(value: String, names: Array) -> void:
	current_level = value
	section_names = names.duplicate()
	best_title.text = "本机最高" if value == "endless" else "会话最佳"
	keys_label.text = "自动奔跑    SPACE 跳跃/蹬墙    R 同图重试    ESC 暂停" if value == "endless" else "A/D 移动    SPACE 跳跃    R 新挑战    ESC 暂停    F2 测试房"

func set_relay_count(value: int) -> void:
	relay_count = value
	relay_counter.text = "中继接入 %d / 2" % value if current_level == "relay_station" else ""

func update_endless(seconds: float, score: int, distance: float, count: int, stage: int, best: int) -> void:
	time_label.text = format_time(seconds)
	count_title.text = "分数"
	death_label.text = str(score)
	best_label.text = str(best)
	section_label.text = "无限 / " + ["起步", "推进", "组合", "持续挑战"][stage]
	brand_label.text = "ENDLESS   /   " + _version()
	relay_counter.text = "距离 %d · 中继 %d" % [int(distance), count]
	progress_fill.size.x = 912 * fmod(seconds, 30.0) / 30.0

func show_endless_result(reason: String, seconds: float, score: int, distance: float, count: int, seed_value: int, best: int, record_broken: bool = false, record_status: String = "") -> void:
	_clear_card()
	_text("新纪录 / ENDLESS" if record_broken else "ENDLESS / SIGNAL LOST", 12, Color("ffd166") if record_broken else Color("ff685c"))
	_text(str(score) + " 分", 38, Color("ffd166"))
	_text({"spike": "撞上尖刺", "fall": "坠入空隙", "caught": "被崩塌吞没", "health":"生命耗尽", "unrecoverable":"坠落 · 无安全落脚点"}.get(reason, "挑战结束"), 20)
	_text("距离 %d · 中继 %d · 用时 %s" % [int(distance), count, format_time(seconds)], 14)
	_text("v0.5 本机最高 %d · 地图 %d" % [best, seed_value], 13)
	if record_status == "save_failed":
		_text("本轮已结算，纪录未能保存到本机。", 12, Color("ff685c"))
	var retry := _button("同图再试   ENTER / R", func(): restart_requested.emit(), true)
	_button("换图挑战", func(): new_seed_requested.emit())
	_button("返回开始界面", func(): menu_requested.emit())
	retry.grab_focus()

func _version() -> String:
	return "v" + str(ProjectSettings.get_setting("application/config/version", "0.3.0"))
