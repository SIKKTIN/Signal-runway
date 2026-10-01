extends Control
## Read-only snapshot HUD. Only subscribe to Flow, never both Flow and Player.
var _flow: Node
var _player: Node
var _connections: Array[Dictionary] = []
var _snapshot: Dictionary = {}
var _notice := ""
var _notice_remaining := 0.0
var _pulse := 0.0
var _clock := 0.0
var _refill_cues := 0
var _font: Font
var _cue: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "Arial"])
	_font = font
	_cue = AudioStreamPlayer.new()
	_cue.name = "DashRefillCue"
	_cue.volume_db = -15.0
	if AudioServer.get_bus_index("SFX") >= 0:
		_cue.bus = "SFX"
	_cue.stream = load("res://assets/audio/v08/dash_refill.wav")
	add_child(_cue)
	if is_instance_valid(_flow):
		bind_flow(_flow)

func bind_flow(flow: Node) -> void:
	_disconnect()
	_flow = flow
	if not is_node_ready() or not is_instance_valid(flow):
		return
	for pair in [["dash_state_changed", _on_dash], ["run_started", _on_started]]:
		if flow.has_signal(pair[0]):
			flow.connect(pair[0], pair[1])
			_connections.append({"source": flow, "signal": pair[0], "callback": pair[1]})
	_on_started()

func _on_started() -> void:
	_player = _flow.get("player") if is_instance_valid(_flow) else null
	_notice = ""
	_notice_remaining = 0.0
	_pulse = 0.0
	_clock = 0.0
	_refill_cues = 0
	_cue.stop()
	_sync_snapshot()

func _sync_snapshot() -> void:
	_snapshot = _player.dash_snapshot() if is_instance_valid(_player) and _player.has_method("dash_snapshot") else {}
	visible = bool(_snapshot.get("enabled", false)) and is_instance_valid(_flow) and str(_flow.get("phase")) not in ["menu", "failed", "finished", "prototype_done"]
	queue_redraw()

func _on_dash(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	if not is_instance_valid(_flow) or str(_flow.get("phase")) not in ["ready", "running"] or get_tree().paused:
		return
	match str(snapshot.get("reason", "")):
		"started":
			_notice = "向前冲刺"
			_notice_remaining = 0.35
		"empty":
			_notice = "冲刺耗尽 · 接入节点充能"
			_notice_remaining = 0.85
			_pulse = 0.4
		"refilled":
			_notice = "充能完成 · 冲刺 +1"
			_notice_remaining = 0.85
			_pulse = 0.6
			_refill_cues += 1
			_cue.play()
		"hurt", "death", "recovery", "control_disabled":
			_notice = ""
			_notice_remaining = 0.0
			_pulse = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	_cue.stream_paused = get_tree().paused
	_sync_snapshot()
	if not visible:
		_notice = ""
		_notice_remaining = 0.0
		_pulse = 0.0
		_cue.stop()
		return
	if get_tree().paused or str(_flow.get("phase")) == "paused":
		return
	_clock += delta
	_notice_remaining = maxf(0.0, _notice_remaining - delta)
	_pulse = maxf(0.0, _pulse - delta)

func _detail() -> String:
	if _notice_remaining > 0.0:
		return _notice
	if int(_snapshot.get("charges", 0)) >= 2:
		return "储备已满"
	return "充能 %d/2 节点" % int(_snapshot.get("progress", 0))

func _draw() -> void:
	if _font == null:
		return
	var charges: int = clampi(int(_snapshot.get("charges", 0)), 0, 2)
	var progress: int = clampi(int(_snapshot.get("progress", 0)), 0, 1)
	# Compact header strip: no opaque extension into the playable lower area.
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.055, 0.095, 0.14, 0.94)
	panel.border_color = Color("426775")
	panel.border_width_left = 2
	panel.border_width_bottom = 1
	panel.set_corner_radius_all(4)
	draw_style_box(panel, Rect2(Vector2.ZERO, size))
	draw_string(_font, Vector2(10, 17), "Shift  冲刺", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("a8bbc4"))
	for index in 2:
		var at := Vector2(98 + index * 25, 4)
		var tint := Color("45dccb") if index < charges else Color("405b68")
		draw_rect(Rect2(at, Vector2(20, 18)), Color(tint, 0.16))
		draw_rect(Rect2(at, Vector2(20, 18)), tint, false, 1.0)
		draw_polyline(PackedVector2Array([at + Vector2(6, 4), at + Vector2(11, 9), at + Vector2(6, 14)]), tint, 2.0, true)
	draw_string(_font, Vector2(153, 18), "%d/2" % charges, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e6efed"))
	draw_string(_font, Vector2(10, 34), _detail(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffd166") if _notice_remaining > 0.0 else Color("9bb5ba"))
	if charges < 2 and _notice_remaining <= 0.0:
		for index in 2:
			draw_rect(Rect2(203 + index * 13, 29, 9, 6), Color("45dccb") if index < progress else Color("304854"))
	if _pulse > 0.0:
		draw_rect(Rect2(2, 1, size.x - 3, size.y - 2), Color(0.27, 0.86, 0.84, 0.05 + 0.04 * sin(_clock * 12)))

func presentation_state() -> Dictionary:
	return {"snapshot": _snapshot.duplicate(true), "detail": _detail(), "notice_remaining": _notice_remaining,
		"pulse": _pulse, "clock": _clock, "refill_cues": _refill_cues, "visible": visible,
		"canvas_rect": Rect2(global_position, size)}

func _disconnect() -> void:
	for connection in _connections:
		var source: Object = connection.source
		if is_instance_valid(source) and source.is_connected(connection.signal, connection.callback):
			source.disconnect(connection.signal, connection.callback)
	_connections.clear()

func _exit_tree() -> void:
	_disconnect()
	if is_instance_valid(_cue):
		_cue.stop()
		_cue.stream = null
