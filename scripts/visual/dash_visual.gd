extends Node2D
## Identity world transform. Read-only dash presentation; Flow owns all rules.
const TRAIL_LIFETIME := 0.16
const SAMPLE_INTERVAL := 0.035
var _flow: Node
var _player: Node2D
var _connections: Array[Dictionary] = []
var _traces: Array[Dictionary] = []
var _sample_clock := 0.0
var _start_remaining := 0.0
var _last_remaining := 0.0
var _started_count := 0
var _cue: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = -1
	_cue = AudioStreamPlayer.new()
	_cue.name = "DashStartCue"
	_cue.volume_db = -15.0
	if AudioServer.get_bus_index("SFX") >= 0:
		_cue.bus = "SFX"
	_cue.stream = load("res://assets/audio/v08/dash_start.wav")
	add_child(_cue)
	if is_instance_valid(_flow):
		bind_flow(_flow, null)

func bind_flow(flow: Node, _course: Node) -> void:
	_disconnect()
	_flow = flow
	_clear()
	_started_count = 0
	if not is_node_ready():
		return
	if not is_instance_valid(flow):
		return
	for pair in [["dash_state_changed", _on_dash], ["run_started", _on_started], ["world_shifted", _on_shifted]]:
		if flow.has_signal(pair[0]):
			flow.connect(pair[0], pair[1])
			_connections.append({"source": flow, "signal": pair[0], "callback": pair[1]})
	_on_started()

func _on_started() -> void:
	_clear()
	_player = _flow.get("player") as Node2D if is_instance_valid(_flow) else null

func _clear() -> void:
	_traces.clear()
	_sample_clock = 0.0
	_start_remaining = 0.0
	_last_remaining = 0.0
	if is_instance_valid(_cue):
		_cue.stop()
	queue_redraw()

func _on_dash(snapshot: Dictionary) -> void:
	if not bool(snapshot.get("enabled", false)):
		_clear()
		return
	var reason: String = str(snapshot.get("reason", ""))
	if reason == "started" and _live() and is_instance_valid(_player):
		_start_remaining = float(snapshot.get("remaining", 0.0))
		_sample_clock = SAMPLE_INTERVAL
		_started_count += 1
		_cue.play()
	elif reason in ["hurt", "death", "recovery", "control_disabled"]:
		_clear()

func _live() -> bool:
	return is_instance_valid(_flow) and str(_flow.get("phase")) in ["ready", "running"] and not get_tree().paused

func _on_shifted(distance: float) -> void:
	for trace in _traces:
		trace.position.x -= distance
	queue_redraw()

func _process(delta: float) -> void:
	if is_instance_valid(_cue):
		_cue.stream_paused = get_tree().paused
	if not is_instance_valid(_flow) or not is_instance_valid(_player):
		visible = false
		_clear()
		return
	var phase: String = str(_flow.get("phase"))
	visible = bool(_player.get("dash_enabled")) and phase in ["ready", "running", "paused"]
	if phase not in ["ready", "running", "paused"] or not visible:
		_clear()
		return
	if get_tree().paused or phase == "paused":
		return
	_last_remaining = float(_player.get("dash_remaining"))
	for trace in _traces:
		trace.life = float(trace.life) - delta
	_traces = _traces.filter(func(trace: Dictionary) -> bool: return float(trace.life) > 0.0)
	if bool(_player.get("dash_active")):
		_sample_clock += delta
		if _sample_clock >= SAMPLE_INTERVAL:
			_sample_clock = 0.0
			_traces.append({"position": _player.global_position, "life": TRAIL_LIFETIME})
			while _traces.size() > 4:
				_traces.pop_front()
	queue_redraw()

func _draw() -> void:
	for trace in _traces:
		var at: Vector2 = to_local(trace.position)
		var fade: float = clampf(float(trace.life) / TRAIL_LIFETIME, 0.0, 1.0)
		# Body echoes stay behind the real sprite and the Course's white top.
		draw_style_box(_echo_style(fade), Rect2(at + Vector2(-8, -12), Vector2(11, 17)))
		draw_polyline(PackedVector2Array([at + Vector2(-19, -9), at + Vector2(-13, -4), at + Vector2(-19, 1)]), Color(0.27, 0.86, 0.88, 0.42 * fade), 1.5, true)
	if is_instance_valid(_player) and bool(_player.get("dash_active")):
		var at: Vector2 = to_local(_player.global_position)
		var strength: float = clampf(_last_remaining / maxf(_start_remaining, 0.01), 0.0, 1.0)
		for offset in [0.0, -9.0]:
			draw_polyline(PackedVector2Array([at + Vector2(-24 + offset, -13), at + Vector2(-17 + offset, -6), at + Vector2(-24 + offset, 1)]), Color(0.55, 0.96, 0.95, 0.3 + strength * 0.4), 2.0, true)

func _echo_style(fade: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.27, 0.86, 0.84, 0.13 * fade)
	style.border_color = Color(0.35, 0.93, 0.93, 0.23 * fade)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style

func presentation_state() -> Dictionary:
	return {"trace_count": _traces.size(), "traces": _traces.duplicate(true), "remaining": _last_remaining,
		"started_count": _started_count, "visible": visible, "audio_playing": is_instance_valid(_cue) and _cue.playing}

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
