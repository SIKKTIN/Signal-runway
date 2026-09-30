extends Node2D

signal mode_changed(mode: String)
signal pause_changed(paused: bool)
signal run_failed(reason: String, elapsed: float, furthest_ratio: float)
signal run_finished(elapsed: float, deaths: int, best: float)

const ChaseVisual := preload("res://scripts/visual/chase_visual.gd")
const ChaseSource := preload("res://scripts/visual/chase_preview_source.gd")
var mode := "pursuit"
var phase := "running"
var chase: Node
var presentation: Node2D
var _skin_root: Control
var _label: Label
var _paused := false


func _ready() -> void:
	add_sprite("res://assets/visual/background_industrial.png", Vector2(480, 270))
	for index in range(30):
		add_sprite("res://assets/visual/terrain_platform.png", Vector2(16 + index * 32, 456))
	add_sprite("res://assets/visual/player_run_0_0.png", Vector2(780, 424))
	add_sprite("res://assets/visual/hazard_spike_up.png", Vector2(850, 424))
	add_sprite("res://assets/visual/goal_gate.png", Vector2(930, 392))
	chase = ChaseSource.new()
	chase.name = "PreviewChase"
	add_child(chase)
	presentation = ChaseVisual.new()
	presentation.name = "ChaseVisual"
	add_child(presentation)
	presentation.bind_flow(self, chase)
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	var root_control := Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.theme = load("res://scenes/ui/skins/chase_theme.tres")
	layer.add_child(root_control)
	var title := Label.new()
	title.text = "信号崩塌  /  v0.2 表现预览"
	title.position = Vector2(24, 20)
	title.add_theme_font_size_override("font_size", 28)
	root_control.add_child(title)
	_label = Label.new()
	_label.position = Vector2(24, 65)
	_label.add_theme_font_size_override("font_size", 17)
	root_control.add_child(_label)
	var instructions := Label.new()
	instructions.text = "1 缓冲  2 安全  3 接近  4 紧急  5 失败皮肤  6 吞没  7 计时模式  P 暂停"
	instructions.position = Vector2(24, 500)
	instructions.add_theme_font_size_override("font_size", 15)
	root_control.add_child(instructions)
	_skin_root = Control.new()
	_skin_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(_skin_root)
	choose_grade("near")


func add_sprite(path: String, at: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = load(path)
	sprite.position = at
	add_child(sprite)


func choose_grade(grade: String) -> void:
	for child in _skin_root.get_children():
		child.queue_free()
	mode = "pursuit"
	phase = "running"
	_paused = false
	var front: float = {"grace": -500.0, "safe": -500.0, "near": 100.0, "urgent": 540.0}.get(grade, 100.0)
	chase.sample(front, 768.0 - front, grade, 2.0 if grade == "grace" else 0.0)
	presentation.bind_flow(self, chase)
	_label.text = "真实前沿锚点 x=%.0f · 危险覆盖始终在边界后方" % front


func show_failure_skins() -> void:
	for child in _skin_root.get_children():
		child.queue_free()
	var index := 0
	var theme := load("res://scenes/ui/skins/chase_theme.tres") as Theme
	for reason in ["spike", "fall", "caught"]:
		var panel := PanelContainer.new()
		panel.position = Vector2(24 + index * 310, 220)
		panel.size = Vector2(290, 174)
		var appearance: Dictionary = ChaseVisual.failure_presentation(reason)
		panel.add_theme_stylebox_override("panel", theme.get_stylebox("panel", appearance.style_type))
		_skin_root.add_child(panel)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 10)
		panel.add_child(column)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		column.add_child(row)
		var icon := TextureRect.new()
		icon.texture = load(appearance.icon_path)
		icon.custom_minimum_size = Vector2(30, 30)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		row.add_child(icon)
		var title := Label.new()
		title.text = appearance.title
		title.add_theme_color_override("font_color", appearance.accent)
		title.add_theme_font_size_override("font_size", 19)
		row.add_child(title)
		var stats := Label.new()
		stats.text = "本轮  00:28.64  ·  最远  62%"
		stats.add_theme_font_size_override("font_size", 15)
		column.add_child(stats)
		var button := Button.new()
		button.text = "立即重开  R"
		column.add_child(button)
		index += 1


func show_caught() -> void:
	phase = "failed"
	chase.sample(768.0, 0.0, "stopped")
	run_failed.emit("caught", 28.64, .62)
	_label.text = "吞没结果：前沿 x=768，画面与音效按结果状态冻结 / 停止"
	show_failure_skins()


func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	var grades := {KEY_1: "grace", KEY_2: "safe", KEY_3: "near", KEY_4: "urgent"}
	if grades.has(event.keycode):
		choose_grade(grades[event.keycode])
	elif event.keycode == KEY_5:
		show_failure_skins()
	elif event.keycode == KEY_6:
		show_caught()
	elif event.keycode == KEY_7:
		mode = "time_trial"
		mode_changed.emit(mode)
	elif event.keycode == KEY_P:
		_paused = not _paused
		pause_changed.emit(_paused)
