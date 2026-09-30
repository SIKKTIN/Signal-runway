extends Node2D

signal state_changed(state: String)
signal action_triggered(action: String)

const VISUAL_PATH := "res://assets/visual/"
const AUDIO_PATH := "res://assets/audio/"

var facing := 1.0
var _visual: Node2D
var _status: Label
var _seconds := 0.0
var _auto_demo := true
var _demo_step := -1


func _ready() -> void:
	var background := Sprite2D.new()
	background.texture = load(VISUAL_PATH + "background_industrial.png")
	background.position = Vector2(480, 270)
	add_child(background)
	for i in range(15):
		add_sprite("terrain_platform.png", Vector2(16 + i * 32, 444))
	for i in range(4):
		add_sprite("terrain_wall_left.png", Vector2(720, 412 - i * 32))
	for i in range(3):
		add_sprite("hazard_spike_up.png", Vector2(528 + i * 32, 420))
	add_sprite("goal_gate.png", Vector2(858, 390))
	_visual = Node2D.new()
	_visual.name = "PlayerVisual"
	_visual.set_script(load("res://scripts/visual/player_visual.gd"))
	_visual.position = Vector2(216, 412)
	add_child(_visual)
	make_ui()
	state_changed.emit("idle")


func add_sprite(file: String, at: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = load(VISUAL_PATH + file)
	sprite.position = at
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sprite)


func make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = load("res://scenes/ui/skins/signal_theme.tres")
	layer.add_child(root)
	var title := Label.new()
	title.text = "信号跑道  /  视觉与音效预览"
	title.position = Vector2(24, 20)
	title.add_theme_font_size_override("font_size", 26)
	root.add_child(title)
	add_ui_icon(root, "ui_clock.png", Vector2(26, 73))
	var timer := Label.new()
	timer.text = "00:42.68"
	timer.position = Vector2(58, 72)
	root.add_child(timer)
	add_ui_icon(root, "ui_deaths.png", Vector2(190, 73))
	var deaths := Label.new()
	deaths.text = "× 02"
	deaths.position = Vector2(221, 72)
	root.add_child(deaths)
	var panel := Panel.new()
	panel.position = Vector2(24, 127)
	panel.size = Vector2(298, 199)
	root.add_child(panel)
	var start := Label.new()
	start.text = "开始 / 暂停 / 结算皮肤"
	start.position = Vector2(40, 142)
	start.add_theme_font_size_override("font_size", 18)
	root.add_child(start)
	var normal := Button.new()
	normal.text = "开始挑战  ↗"
	normal.position = Vector2(42, 177)
	normal.size = Vector2(247, 42)
	root.add_child(normal)
	var retry := Button.new()
	retry.text = "再次挑战"
	retry.position = Vector2(42, 231)
	retry.size = Vector2(247, 42)
	root.add_child(retry)
	var hint := Label.new()
	hint.text = "按 1–5 试听动作 · 左右键切换朝向"
	hint.position = Vector2(28, 497)
	hint.add_theme_font_size_override("font_size", 17)
	root.add_child(hint)
	_status = Label.new()
	_status.text = "自动演示：待机"
	_status.position = Vector2(600, 32)
	_status.add_theme_font_size_override("font_size", 18)
	root.add_child(_status)


func add_ui_icon(root: Control, file: String, at: Vector2) -> void:
	var icon := TextureRect.new()
	icon.texture = load(VISUAL_PATH + file)
	icon.position = at
	icon.size = Vector2(24, 24)
	root.add_child(icon)


func _process(delta: float) -> void:
	if not _auto_demo:
		return
	_seconds += delta
	_visual.position.x = 216.0 + fmod(_seconds * 80.0, 210.0)
	var next_step := int(_seconds / 1.1) % 7
	if next_step == _demo_step:
		return
	_demo_step = next_step
	var states := ["idle", "run", "rise", "fall", "wall_slide", "land", "dead"]
	var actions := ["", "", "jump", "", "wall_jump", "land", "death"]
	state_changed.emit(states[next_step])
	if actions[next_step] != "":
		action_triggered.emit(actions[next_step])
	_status.text = "自动演示：" + states[next_step]


func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_LEFT:
		facing = -1.0
	elif event.keycode == KEY_RIGHT:
		facing = 1.0
	var keys := {KEY_1: "jump", KEY_2: "wall_jump", KEY_3: "land", KEY_4: "death", KEY_5: "finish"}
	if keys.has(event.keycode):
		_auto_demo = false
		var action: String = keys[event.keycode]
		if action == "finish":
			_visual.play_finish()
		else:
			state_changed.emit("dead" if action == "death" else "rise")
			action_triggered.emit(action)
		_status.text = "手动试听：" + action
