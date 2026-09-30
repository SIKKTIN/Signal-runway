extends Node2D
## World identity transform; public events and course data only. No collision.
const ACTIVATION_DURATION := 0.42
var _flow: Node
var _course: Node
var _animation_time := 0.0
var _paused := false
var _resolved := false
var _phase := "menu"
var _nodes: Dictionary = {}
var _activated_ids: Dictionary = {}
var _pulses: Dictionary = {}
var _connections: Array[Dictionary] = []
var _textures: Dictionary = {}
var _font: Font
var _sound: AudioStreamPlayer
var _sound_triggers := 0
var _toast_end := -1.0
var _toast: PanelContainer
var _toast_text: Label
var _delay_remaining := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for state in ["available", "activating", "activated"]:
		_textures[state] = load("res://assets/visual/relay/relay_%s.png" % state)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	_font = font
	_sound = AudioStreamPlayer.new()
	_sound.name = "RelayConnect"
	_sound.stream = load("res://assets/audio/relay/relay_connect.wav")
	_sound.volume_db = -5.0
	if AudioServer.get_bus_index("SFX") >= 0:
		_sound.bus = "SFX"
	add_child(_sound)
	_make_toast()
	if is_instance_valid(_flow) and is_instance_valid(_course):
		bind_flow(_flow, _course)

func _make_toast() -> void:
	var layer := CanvasLayer.new()
	layer.name = "RelayToast"
	layer.layer = 3
	add_child(layer)
	var control := Control.new()
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.theme = load("res://scenes/ui/skins/chase_theme.tres")
	layer.add_child(control)
	_toast = PanelContainer.new()
	_toast.anchor_left = 1.0
	_toast.anchor_right = 1.0
	_toast.offset_left = -270
	_toast.offset_right = -24
	_toast.offset_top = 244
	_toast.offset_bottom = 281
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_theme_stylebox_override("panel", control.theme.get_stylebox("panel", "ChaseHUDNear"))
	control.add_child(_toast)
	_toast_text = Label.new()
	_toast_text.add_theme_font_size_override("font_size", 14)
	_toast_text.add_theme_color_override("font_color", Color("ffd166"))
	_toast.add_child(_toast_text)
	_toast.hide()

func bind_flow(flow: Node, course: Node) -> void:
	_disconnect_sources()
	_flow = flow
	_course = course
	_animation_time = 0.0
	_pulses.clear()
	_nodes.clear()
	_activated_ids.clear()
	_toast_end = -1.0
	_delay_remaining = 0.0
	_sound_triggers = 0
	if not is_node_ready():
		return
	_sound.stop()
	_sound.stream_paused = false
	_sync_phase()
	_read_nodes()
	for id in _nodes:
		if _nodes[id].activated:
			_activated_ids[id] = true
	for pair in [["relay_activated", _on_relay_activated], ["relay_delay_changed", _on_delay_changed],
		["pause_changed", _on_pause_changed], ["run_failed", _on_failed], ["run_finished", _on_finished], ["mode_changed", _on_mode_changed]]:
		if flow.has_signal(pair[0]):
			flow.connect(pair[0], pair[1])
			_connections.append({"source": flow, "signal": pair[0], "callback": pair[1]})
	if course.has_signal("chunks_changed"):
		course.connect("chunks_changed", _read_nodes)
		_connections.append({"source": course, "signal": "chunks_changed", "callback": _read_nodes})
	if flow.has_signal("world_shifted"):
		flow.connect("world_shifted", _on_world_shifted)
		_connections.append({"source": flow, "signal": "world_shifted", "callback": _on_world_shifted})
	_refresh_toast()
	queue_redraw()

func _read_nodes() -> void:
	if not is_instance_valid(_course):
		return
	var relays: Variant = _course.get("relays")
	if not relays is Array:
		return
	var active := {}
	for entry in relays:
		var id := str(entry.get("id", ""))
		if id != "":
			active[id] = {"position": entry.get("position", Vector2.ZERO), "activated": bool(entry.get("activated", false)) or _activated_ids.has(id)}
	for id in _activated_ids.keys():
		if not active.has(id):
			_activated_ids.erase(id)
	for id in _pulses.keys():
		if not active.has(id):
			_pulses.erase(id)
	_nodes = active
	queue_redraw()

func _on_world_shifted(_distance: float) -> void:
	_read_nodes()

func _sync_phase() -> void:
	if not is_instance_valid(_flow):
		return
	_phase = str(_flow.get("phase"))
	_paused = _phase == "paused" or get_tree().paused
	_resolved = _phase in ["menu", "failed", "finished"]

func _on_relay_activated(id: String, added_delay: float, count: int) -> void:
	_sync_phase()
	_read_nodes()
	if _resolved or not _nodes.has(id) or _activated_ids.has(id):
		return
	_activated_ids[id] = true
	_nodes[id].activated = true
	_pulses[id] = _animation_time
	_toast_end = _animation_time + 1.1
	_toast_text.text = "中继接入 %d/%d" % [count, _nodes.size()]
	if _flow.has_method("is_endless") and _flow.is_endless():
		_toast_text.text = "中继接入  ·  累计 %d" % count
	if added_delay > 0.0:
		_toast_text.text += "  ·  +%.1f s" % added_delay
	_sound.play()
	_sound.stream_paused = _paused
	_sound_triggers += 1
	_refresh_toast()
	queue_redraw()

func _on_delay_changed(remaining: float) -> void:
	_delay_remaining = maxf(remaining, 0.0)

func _on_pause_changed(value: bool) -> void:
	_paused = value
	if _sound != null:
		_sound.stream_paused = value

func _on_failed(_reason: String, _elapsed: float, _ratio: float) -> void:
	_end_feedback()

func _on_finished(_elapsed: float, _deaths: int, _best: float) -> void:
	_end_feedback()

func _end_feedback() -> void:
	_resolved = true
	_toast_end = -1.0
	_delay_remaining = 0.0
	if _sound != null:
		_sound.stop()
	_refresh_toast()

func _on_mode_changed(_mode: String) -> void:
	_sync_phase()
	if _resolved:
		_end_feedback()
	_refresh_toast()

func _refresh_toast() -> void:
	if _toast == null:
		return
	var pursuit := is_instance_valid(_flow) and str(_flow.get("mode")) == "pursuit"
	_toast.offset_top = 244.0 if pursuit else 142.0
	_toast.offset_bottom = _toast.offset_top + 37.0
	_toast.visible = not _resolved and _animation_time < _toast_end

func _process(delta: float) -> void:
	_sync_phase()
	_read_nodes()
	if not _paused and not _resolved:
		_animation_time += delta
	if _resolved and _sound != null and _sound.playing:
		_sound.stop()
	_refresh_toast()
	queue_redraw()

func _draw() -> void:
	if _textures.is_empty():
		return
	for id in _nodes:
		var entry: Dictionary = _nodes[id]
		var at: Vector2 = entry.position
		var pulse_age := _animation_time - float(_pulses.get(id, -100.0))
		var state := "activating" if pulse_age < ACTIVATION_DURATION else ("activated" if entry.activated else "available")
		draw_texture_rect(_textures[state], Rect2(at - Vector2(24, 24), Vector2(48, 48)), false)
		if state == "available":
			var angle := _animation_time * 0.9
			var alpha := 0.30 + 0.13 * sin(_animation_time * 2.1)
			draw_arc(at, 25, angle, angle + 0.8, 12, Color(1.0, 0.82, 0.40, alpha), 1.5, true)
			_draw_caption(at, "中继", Color("ffd166"))
		elif state == "activating":
			var progress := clampf(pulse_age / ACTIVATION_DURATION, 0.0, 1.0)
			draw_arc(at, 24 + progress * 18, 0, TAU, 48, Color(1.0, 0.87, 0.56, 0.55 * (1.0 - progress)), 2, true)
			_draw_caption(at, "接入", Color("ffecc5"))
		else:
			_draw_caption(at, "已接入", Color("a38d57"))

func _draw_caption(at: Vector2, text: String, color: Color) -> void:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(_font, at + Vector2(-width / 2.0, -31), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)

func presentation_state() -> Dictionary:
	var states := {}
	for id in _nodes:
		var age := _animation_time - float(_pulses.get(id, -100.0))
		states[id] = "activating" if age < ACTIVATION_DURATION else ("activated" if _nodes[id].activated else "available")
	return {"animation_time": _animation_time, "paused": _paused, "resolved": _resolved, "node_states": states,
		"activated_ids": _activated_ids.keys(), "sound_triggers": _sound_triggers, "sound_playing": _sound.playing,
		"sound_paused": _sound.stream_paused, "toast_visible": _toast.visible, "delay_remaining": _delay_remaining,
		"node_count": _nodes.size(), "pulse_count": _pulses.size(), "activated_count": _activated_ids.size()}

func _disconnect_sources() -> void:
	for connection in _connections:
		var source: Object = connection.source
		if is_instance_valid(source) and source.is_connected(connection.signal, connection.callback):
			source.disconnect(connection.signal, connection.callback)
	_connections.clear()

func _exit_tree() -> void:
	_disconnect_sources()
	if _sound != null:
		_sound.stop()
		_sound.stream = null
