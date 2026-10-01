extends CanvasLayer
## Independent read-only HUD draft. Producer owns mode entry and result actions.
var show_controls := true
var _flow: Node
var _connections: Array[Dictionary] = []
var _animation_time := 0.0
var _paused := false
var _resolved := false
var _last_score := 0
var _best_score := 0
var _last_count := 0
var _record_announced := false
var _pulse_until := -1.0
var _record_until := -1.0
var _score: Label
var _distance: Label
var _relay: Label
var _record: Label
var _meta: Label
var _gain: Label
var _banner: Label
var _root: Control
var _instructions: Label
var _stage := 0

func _ready() -> void:
	layer = 3
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = load("res://scenes/ui/skins/chase_theme.tres")
	add_child(_root)
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 20)
	panel.size = Vector2(784, 76)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _root.theme.get_stylebox("panel", "ChaseHUDSafe"))
	_root.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	_score = _column(row, "总分", "0", 30, Color("e6efed"), 120)
	_distance = _column(row, "最远距离", "0", 25, Color("45dccb"), 160)
	_relay = _column(row, "中继", "0", 25, Color("ffd166"), 96)
	_record = _column(row, "本机最高", "0", 25, Color("ffd166"), 140)
	_gain = Label.new()
	_gain.add_theme_font_size_override("font_size", 18)
	_gain.add_theme_color_override("font_color", Color("ffd166"))
	row.add_child(_gain)
	_meta = Label.new()
	_meta.position = Vector2(24, 106)
	_meta.add_theme_font_size_override("font_size", 14)
	_meta.add_theme_color_override("font_color", Color("8ca2ac"))
	_root.add_child(_meta)
	_banner = Label.new()
	_banner.position = Vector2(690, 112)
	_banner.add_theme_font_size_override("font_size", 16)
	_banner.add_theme_color_override("font_color", Color("ffd166"))
	_root.add_child(_banner)
	_instructions = Label.new()
	_instructions.position = Vector2(24, 519)
	_instructions.add_theme_font_size_override("font_size", 14)
	_instructions.add_theme_color_override("font_color", Color("9bb5ba"))
	_instructions.text = "自动奔跑    SPACE / W / ↑ 跳跃、蹬墙    R 同图重试    ESC 暂停"
	_root.add_child(_instructions)
	if is_instance_valid(_flow):
		bind_flow(_flow)

func _column(row: HBoxContainer, title: String, initial: String, size: int, color: Color, width: float) -> Label:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = width
	row.add_child(column)
	var caption := Label.new()
	caption.text = title
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", Color("8ca2ac"))
	column.add_child(caption)
	var value := Label.new()
	value.text = initial
	value.add_theme_font_size_override("font_size", size)
	value.add_theme_color_override("font_color", color)
	column.add_child(value)
	return value

func bind_flow(flow: Node) -> void:
	_disconnect_sources()
	_flow = flow
	if is_instance_valid(_record):
		var caption: Label = _record.get_parent().get_child(0)
		caption.text = "v0.%d 本机最高" % int(flow.endless_record.expected_rules_revision)
	_animation_time = 0
	_pulse_until = -1
	_record_until = -1
	_record_announced = false
	if not is_node_ready():
		return
	_last_score = int(flow.get("run_score"))
	_best_score = int(flow.get("best_score"))
	_last_count = int(flow.get("relay_count"))
	_paused = str(flow.get("phase")) == "paused"
	_resolved = str(flow.get("phase")) in ["menu", "failed", "finished"]
	for pair in [["endless_stats_changed", _on_stats], ["pause_changed", _on_pause], ["run_failed", _on_failed], ["mode_changed", _on_mode_changed]]:
		if flow.has_signal(pair[0]):
			flow.connect(pair[0], pair[1])
			_connections.append({"source": flow, "signal": pair[0], "callback": pair[1]})
	_on_stats(_last_score, float(flow.get("run_distance")), int(flow.get("relay_count")), int(flow.get("difficulty_stage")))
	_sync_phase()

func _on_stats(score: int, distance: float, count: int, stage: int) -> void:
	if count > _last_count and score > _last_score and not _resolved:
		_gain.text = "+%d" % (score - _last_score)
		_pulse_until = _animation_time + 0.45
	if score > _best_score and not _record_announced and not _resolved:
		_record_until = _animation_time + 1.0
		_record_announced = true
	_last_score = score
	_last_count = count
	_score.text = str(score)
	_score.add_theme_font_size_override("font_size", 30 if str(score).length() <= 6 else 22)
	_distance.text = "%.0f 单位" % distance
	_relay.text = str(count)
	_record.text = str(maxi(_best_score, int(_flow.get("best_score"))))
	_record.add_theme_font_size_override("font_size", 25 if _record.text.length() <= 7 else 20)
	_stage = stage
	_refresh_meta()
	_banner.text = "新纪录"

func _on_pause(value: bool) -> void:
	_paused = value
	_sync_phase()

func _refresh_meta() -> void:
	var elapsed := 0.0
	for entry in _flow.get_property_list():
		if str(entry.name) == "elapsed":
			elapsed = float(_flow.get("elapsed"))
			break
	_meta.text = "无限信号跑道  ·  生存 %02d:%05.2f  ·  阶段 %d  ·  地图种子 %s" % [int(elapsed / 60), fmod(elapsed, 60), _stage + 1, str(_flow.get("run_seed"))]

func _on_mode_changed(_mode: String) -> void:
	_sync_phase()

func _sync_phase() -> void:
	if not is_instance_valid(_flow):
		return
	var phase := str(_flow.get("phase"))
	_paused = phase == "paused" or get_tree().paused
	_resolved = phase in ["menu", "failed", "finished"]
	_root.visible = _flow.has_method("is_endless") and _flow.is_endless() and phase != "menu"
	_instructions.visible = show_controls and phase in ["ready", "running", "paused"]

func _on_failed(_reason: String, _elapsed: float, _ratio: float) -> void:
	_resolved = true
	_gain.hide()
	_banner.hide()

func _process(delta: float) -> void:
	_sync_phase()
	if is_instance_valid(_flow):
		_refresh_meta()
	if not _paused and not _resolved:
		_animation_time += delta
	_gain.visible = not _resolved and _animation_time < _pulse_until
	_banner.visible = not _resolved and _animation_time < _record_until

func presentation_state() -> Dictionary:
	return {"animation_time": _animation_time, "paused": _paused, "resolved": _resolved,
		"score": _last_score, "gain_visible": _gain.visible, "record_visible": _banner.visible,
		"record_announced": _record_announced, "relay_count": _last_count, "hud_visible": _root.visible}

func _disconnect_sources() -> void:
	for connection in _connections:
		var source: Object = connection.source
		if is_instance_valid(source) and source.is_connected(connection.signal, connection.callback):
			source.disconnect(connection.signal, connection.callback)
	_connections.clear()

func _exit_tree() -> void:
	_disconnect_sources()
