extends Node2D
## World-space presentation only. Keep this node's transform at identity.
## bind_flow reads initial public properties and then consumes frozen signals.

const VISUAL_DIR := "res://assets/visual/v02/"
const AUDIO_DIR := "res://assets/audio/v02/"
const COLORS := {"grace": Color("45dccb"), "safe": Color("45dccb"), "near": Color("ffd166"), "urgent": Color("ff685c")}

var front_x := 0.0
var gap_px := 0.0
var warning_level := "stopped"
var grace_remaining := 0.0
var _flow: Node
var _chase: Node
var _connections: Array[Dictionary] = []
var _mode := "time_trial"
var _paused := false
var _resolved := false
var _animation_time := 0.0
var _target_volume := -24.0
var _cover: Texture2D
var _theme: Theme
var _loop: AudioStreamPlayer
var _cue: AudioStreamPlayer
var _caught: AudioStreamPlayer
var _cue_streams: Dictionary = {}
var _icons: Dictionary = {}
var _hud_grade := ""
var _last_phase := "ready"
var _hud_layer: CanvasLayer
var _hud_panel: PanelContainer
var _hud_icon: TextureRect
var _hud_title: Label
var _hud_detail: Label
var _hud_delay: Label
var _relay_delay_remaining := 0.0
var _world_offset := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_cover = load(VISUAL_DIR + "collapse_cover.png")
	_theme = load("res://scenes/ui/skins/chase_theme.tres")
	_loop = _make_audio("ThreatLoop")
	var loop_stream := load(AUDIO_DIR + "threat_loop.wav").duplicate() as AudioStreamWAV
	loop_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop_stream.loop_begin = 0
	loop_stream.loop_end = int(loop_stream.get_length() * loop_stream.mix_rate)
	_loop.stream = loop_stream
	_loop.volume_db = -24.0
	_cue = _make_audio("WarningCue")
	_cue.volume_db = -7.0
	_caught = _make_audio("CaughtCue")
	_caught.stream = load(AUDIO_DIR + "caught.wav")
	_caught.volume_db = -4.0
	_cue_streams["near"] = load(AUDIO_DIR + "warning_near.wav")
	_cue_streams["urgent"] = load(AUDIO_DIR + "warning_urgent.wav")
	for grade in ["safe", "near", "urgent"]:
		_icons[grade] = load(VISUAL_DIR + "warning_%s.png" % grade)
	_make_hud()
	if _flow != null and _chase != null:
		bind_flow(_flow, _chase)


func _make_audio(node_name: String) -> AudioStreamPlayer:
	var sound := AudioStreamPlayer.new()
	sound.name = node_name
	if AudioServer.get_bus_index("SFX") >= 0:
		sound.bus = "SFX"
	add_child(sound)
	return sound


func _make_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "ThreatHUD"
	_hud_layer.layer = 3
	add_child(_hud_layer)
	var root_control := Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.theme = _theme
	_hud_layer.add_child(root_control)
	_hud_panel = PanelContainer.new()
	_hud_panel.name = "DistancePanel"
	_hud_panel.anchor_left = 1.0
	_hud_panel.anchor_right = 1.0
	_hud_panel.offset_left = -270
	_hud_panel.offset_right = -24
	_hud_panel.offset_top = 142
	_hud_panel.offset_bottom = 212
	_hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(_hud_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_hud_panel.add_child(row)
	_hud_icon = TextureRect.new()
	_hud_icon.custom_minimum_size = Vector2(28, 28)
	_hud_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hud_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_hud_icon)
	var text_column := VBoxContainer.new()
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.add_theme_constant_override("separation", 3)
	row.add_child(text_column)
	_hud_title = Label.new()
	_hud_title.add_theme_font_size_override("font_size", 18)
	text_column.add_child(_hud_title)
	_hud_detail = Label.new()
	_hud_detail.add_theme_font_size_override("font_size", 15)
	text_column.add_child(_hud_detail)
	_hud_delay = Label.new()
	_hud_delay.add_theme_font_size_override("font_size", 13)
	_hud_delay.add_theme_color_override("font_color", Color("ffd166"))
	text_column.add_child(_hud_delay)
	_hud_delay.hide()
	_hud_panel.visible = false


func bind_flow(flow: Node, chase: Node) -> void:
	_disconnect_sources()
	_flow = flow
	_chase = chase
	if not is_node_ready():
		return
	_stop_all_audio()
	_animation_time = 0.0
	_world_offset = 0.0
	if flow.has_method("is_endless") and flow.is_endless():
		var course: Variant = _property(flow, "course", null)
		_world_offset = float(_property(course, "total_offset", 0.0))
	_relay_delay_remaining = float(_property(chase, "relay_remaining", _property(flow, "relay_delay_remaining", 0.0)))
	_resolved = false
	_mode = str(_property(flow, "mode", "time_trial"))
	var phase := str(_property(flow, "phase", "ready"))
	_paused = get_tree().paused or phase == "paused"
	_last_phase = phase
	_resolved = phase in ["finished", "failed", "menu"]
	_connect_source(flow, "mode_changed", _on_mode_changed)
	_connect_source(flow, "pause_changed", _on_pause_changed)
	_connect_source(flow, "run_failed", _on_run_failed)
	_connect_source(flow, "run_finished", _on_run_finished)
	_connect_source(flow, "relay_delay_changed", _on_relay_delay_changed)
	_connect_source(flow, "world_shifted", _on_world_shifted)
	_connect_source(chase, "threat_updated", _on_threat_updated)
	warning_level = "stopped"
	_on_threat_updated(float(_property(chase, "front_x", 0.0)), float(_property(chase, "gap_px", 0.0)),
		str(_property(chase, "warning_level", "stopped")), float(_property(chase, "grace_remaining", 0.0)))


func _property(source: Object, key: String, fallback: Variant) -> Variant:
	if not is_instance_valid(source):
		return fallback
	for entry in source.get_property_list():
		if str(entry.name) == key:
			return source.get(key)
	return fallback


func _connect_source(source: Node, signal_name: String, callback: Callable) -> void:
	if is_instance_valid(source) and source.has_signal(signal_name):
		if not source.is_connected(signal_name, callback):
			source.connect(signal_name, callback)
		_connections.append({"source": source, "signal": signal_name, "callback": callback})


func _disconnect_sources() -> void:
	for connection in _connections:
		var source: Object = connection.source
		if is_instance_valid(source) and source.is_connected(connection.signal, connection.callback):
			source.disconnect(connection.signal, connection.callback)
	_connections.clear()


func _on_threat_updated(x: float, distance: float, grade: String, grace: float) -> void:
	front_x = x
	gap_px = distance
	grace_remaining = grace
	var changed := warning_level != grade
	warning_level = grade if grade in ["grace", "safe", "near", "urgent", "stopped"] else "stopped"
	_refresh_hud()
	_sync_audio(changed)
	queue_redraw()


func _on_mode_changed(mode: String) -> void:
	_mode = mode
	_last_phase = str(_property(_flow, "phase", "ready"))
	_resolved = _last_phase in ["menu", "failed", "finished"]
	_stop_all_audio()
	if is_instance_valid(_chase):
		_on_threat_updated(float(_property(_chase, "front_x", front_x)), float(_property(_chase, "gap_px", gap_px)),
			str(_property(_chase, "warning_level", "stopped")), float(_property(_chase, "grace_remaining", 0.0)))
	_refresh_hud()
	queue_redraw()


func _on_pause_changed(paused: bool) -> void:
	_paused = paused
	if paused:
		_cue.stop()
		_caught.stop()
	_sync_audio(false)


func _on_relay_delay_changed(remaining: float) -> void:
	_relay_delay_remaining = maxf(remaining, 0.0)
	_refresh_hud()

func _on_world_shifted(distance: float) -> void:
	_world_offset += distance
	queue_redraw()


func _on_run_failed(reason: String, _elapsed: float, _furthest_ratio: float) -> void:
	if _resolved:
		return
	_resolved = true
	_relay_delay_remaining = 0.0
	_stop_all_audio()
	_hud_panel.visible = false
	if _mode == "pursuit" and reason == "caught":
		_caught.play()


func _on_run_finished(_elapsed: float, _deaths: int, _best: float) -> void:
	_resolved = true
	_relay_delay_remaining = 0.0
	_stop_all_audio()
	_hud_panel.visible = false


func _sync_audio(play_transition: bool) -> void:
	if _loop == null:
		return
	var live := _mode == "pursuit" and not _resolved and warning_level in ["safe", "near", "urgent"]
	if not live:
		_stop_loop()
		_cue.stop()
		return
	if _paused:
		_loop.stream_paused = true
		return
	_loop.stream_paused = false
	if not _loop.playing:
		_loop.play()
	_target_volume = -23.0 if warning_level == "safe" else (-17.0 if warning_level == "near" else -12.0)
	if play_transition and _cue_streams.has(warning_level):
		_cue.stop()
		_cue.stream = _cue_streams[warning_level]
		_cue.play()


func _stop_loop() -> void:
	if _loop != null:
		_loop.stop()
		_loop.stream_paused = false


func _stop_all_audio() -> void:
	_stop_loop()
	if _cue != null:
		_cue.stop()
	if _caught != null:
		_caught.stop()


func _refresh_hud() -> void:
	if _hud_panel == null:
		return
	_hud_panel.visible = _mode == "pursuit" and not _resolved and warning_level != "stopped"
	if not _hud_panel.visible:
		return
	var grade := warning_level
	var title := {"grace": "启动缓冲", "safe": "距离安全", "near": "崩塌接近", "urgent": "前沿紧逼"}
	_hud_title.text = str(title.get(grade, "追赶停止"))
	var speed := maxf(1.0, float(_property(_chase, "speed", 1.0)))
	_hud_detail.text = "%.1f s 后启动" % maxf(0.0, grace_remaining) if grade == "grace" else "原地余量约 %.1f 秒" % (maxf(0.0, gap_px) / speed)
	var catchup := float(_property(_flow, "catchup_bonus", 0.0)) > 0.5
	_hud_detail.add_theme_font_size_override("font_size", 13 if catchup else 15)
	if catchup and grade != "grace":
		_hud_title.text = "远距追速"
		_hud_detail.text = "追速 %.0f/s · 余量 %.1fs" % [speed, maxf(0.0, gap_px) / speed]
	_hud_delay.visible = _relay_delay_remaining > 0.0
	_hud_delay.text = "中继延迟  %.1f 秒" % _relay_delay_remaining
	_hud_panel.offset_bottom = 236.0 if _hud_delay.visible else 212.0
	if _hud_grade != grade:
		_hud_grade = grade
		_hud_title.add_theme_color_override("font_color", COLORS.get(grade, Color.WHITE))
		_hud_icon.texture = _icons["safe" if grade == "grace" else grade]
		var style_type := "ChaseHUD" + grade.capitalize()
		if _theme.has_stylebox("panel", style_type):
			_hud_panel.add_theme_stylebox_override("panel", _theme.get_stylebox("panel", style_type))


func _process(delta: float) -> void:
	if is_instance_valid(_flow):
		var current_phase := str(_flow.get("phase"))
		if current_phase != _last_phase:
			_last_phase = current_phase
			if current_phase == "ready":
				_resolved = false
				_paused = get_tree().paused
				_sync_audio(false)
			elif current_phase == "menu":
				_resolved = true
				_stop_all_audio()
			elif current_phase in ["failed", "finished"] and not _resolved:
				_resolved = true
				_stop_all_audio()
			_refresh_hud()
	if not _paused and not _resolved:
		_animation_time += delta
	if _loop != null and _loop.playing and not _paused:
		_loop.volume_db = lerpf(_loop.volume_db, _target_volume, minf(1.0, delta * 4.0))
	queue_redraw()


func _draw() -> void:
	if _mode != "pursuit" or _cover == null or _last_phase == "menu" or (warning_level == "stopped" and not _resolved):
		return
	var inverse := get_global_transform_with_canvas().affine_inverse()
	var top_left := inverse * Vector2.ZERO
	var bottom_right := inverse * get_viewport_rect().size
	var local_front := to_local(Vector2(front_x, 0.0)).x
	var left := top_left.x - 32.0
	var top := top_left.y - 128.0
	var height := bottom_right.y - top_left.y + 256.0
	if local_front <= left:
		return
	var right := minf(local_front, bottom_right.x + 48.0)
	if local_front > bottom_right.x + 64.0:
		draw_rect(Rect2(left, top, right - left, height), Color(0.055, 0.095, 0.14, 0.80))
		draw_texture_rect(_cover, Rect2(left, top, right - left, height), true, Color(1, 1, 1, 0.40))
		_draw_signal_flow(left, right, top, height)
		return
	# The wave rolls *behind* the exact lethal boundary. Neither its fill nor
	# the antialiased strokes can create a dangerous-looking area ahead of it.
	var wave := PackedVector2Array()
	var echo := PackedVector2Array()
	var ribbon := PackedVector2Array()
	var coverage := PackedVector2Array([Vector2(left - 80.0, top)])
	var y := top
	while y <= top + height + 8.0:
		var inset := _wave_inset(y)
		wave.append(Vector2(local_front - inset, y))
		echo.append(Vector2(local_front - inset - 32.0 - 7.0 * sin(y * 0.028 + _animation_time * 2.0), y))
		ribbon.append(Vector2(local_front - inset - 12.0, y))
		coverage.append(Vector2(local_front - inset, y))
		y += 6.0
	coverage.append(Vector2(left - 80.0, wave[wave.size() - 1].y))
	draw_colored_polygon(coverage, Color(0.055, 0.095, 0.14, 0.80))
	var uv := PackedVector2Array()
	for point in coverage:
		uv.append((point + Vector2(_world_offset, 0)) / 128.0)
	draw_polygon(coverage, PackedColorArray([Color(1, 1, 1, 0.40)]), uv, _cover)
	_draw_signal_flow(left, right, top, height)
	for index in range(wave.size() - 1, -1, -1):
		ribbon.append(wave[index])
	draw_colored_polygon(ribbon, Color(1.0, 0.31, 0.26, 0.11))
	draw_polyline(echo, Color(0.27, 0.86, 0.80, 0.32), 2.0, true)
	draw_polyline(wave, Color(1.0, 0.35, 0.29, 0.10), 12.0, true)
	draw_polyline(wave, Color(1.0, 0.40, 0.35, 0.86), 2.5, true)
	for index in range(int(floor(top / 104.0)) - 1, int(ceil((top + height) / 104.0)) + 1):
		var packet_y := float(index) * 104.0 + fposmod(_animation_time * 86.0, 104.0)
		var packet_inset := _wave_inset(packet_y) + 5.0
		draw_rect(Rect2(local_front - packet_inset - 8.0, packet_y, 8.0, 3.0), Color(1.0, 0.75, 0.61, 0.72))


func _wave_inset(y: float) -> float:
	return 38.0 + 20.0 * sin(y * 0.035 - _animation_time * 4.2) + 5.0 * sin(y * 0.072 - _animation_time * 2.7)


func _draw_signal_flow(left: float, right: float, top: float, height: float) -> void:
	var offset := fposmod(_animation_time * 44.0, 76.0)
	for band in range(int(floor(top / 76.0)) - 2, int(ceil((top + height) / 76.0)) + 2):
		var path := PackedVector2Array()
		var x := left
		while x < right - 3.0:
			var y := float(band) * 76.0 + offset + sin((x - front_x) * 0.015 + _animation_time * 2.3 + band * 0.4) * 12.0
			if x >= front_x - _wave_inset(y) - 3.0:
				break
			path.append(Vector2(x, y))
			x += 16.0
		if path.size() >= 2:
			draw_polyline(path, Color(0.28, 0.70, 0.72, 0.13), 1.0, true)
	var first := int(floor((left + _world_offset + _animation_time * 118.0) / 96.0))
	var last := int(ceil((right + _world_offset + _animation_time * 118.0) / 96.0))
	for index in range(first, last + 1):
		var x := float(index) * 96.0 - _animation_time * 118.0 - _world_offset
		var width := minf(28.0, right - x - 2.0)
		if x < left or width <= 0.0:
			continue
		for row in range(int(floor(top / 142.0)) - 1, int(ceil((top + height) / 142.0)) + 1):
			var y := row * 142.0 + 24.0 * sin(index * 2.1 + row * 0.8) + fposmod(_animation_time * 19.0, 142.0)
			var curved_width := minf(width, front_x - _wave_inset(y) - x - 3.0)
			if curved_width > 0.0:
				draw_rect(Rect2(x, y, curved_width, 2.0), Color(0.96, 0.37, 0.31, 0.22))


func presentation_state() -> Dictionary:
	return {"front_x": front_x, "gap_px": gap_px, "warning_level": warning_level, "mode": _mode,
		"paused": _paused, "resolved": _resolved, "hud_visible": _hud_panel.visible,
		"loop_playing": _loop.playing, "loop_paused": _loop.stream_paused,
		"loop_position": _loop.get_playback_position(), "animation_time": _animation_time,
		"caught_playing": _caught.playing, "caught_position": _caught.get_playback_position(),
		"coverage_max_x": front_x, "wave_center_offset_min": 13.0, "wave_center_offset_max": 63.0,
		"wave_stroke_max_x": front_x - 7.0, "wave_travel_speed": 120.0,
		"relay_delay_remaining": _relay_delay_remaining, "relay_delay_visible": _hud_delay.visible and _hud_panel.visible,
		"world_offset": _world_offset}


static func failure_presentation(reason: String) -> Dictionary:
	var titles := {"spike": "撞上尖刺", "fall": "坠入空隙", "caught": "被信号崩塌吞没"}
	return {"title": titles.get(reason, "挑战结束"), "icon_path": VISUAL_DIR + "failure_%s.png" % reason,
		"style_type": "ChaseFailure" + reason.capitalize(), "accent": Color("ff685c")}


func _exit_tree() -> void:
	_disconnect_sources()
	_stop_all_audio()
	for sound in [_loop, _cue, _caught]:
		if is_instance_valid(sound):
			sound.stream = null
