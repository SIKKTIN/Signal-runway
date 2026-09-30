extends Node2D
## Pure presentation. Install under World with identity transform, z_index=-10.
## Camera motion changes parallax; a private clock drives all ambient motion.

const PARALLAX := [0.14, 0.32, 0.57]
var _flow: Node
var _camera: Camera2D
var _course: Node2D
var _animation_time := 0.0
var _paused := false
var _resolved := false
var _connections: Array[Dictionary] = []
var _phase := "menu"
var _station_enabled := false
var _station_section := 0
var _station_font: Font
var _world_offset := 0.0
const STATION_COLORS := [Color("45dccb"), Color("ffd166"), Color("69bcd1"), Color("ffd166"), Color("ffd166")]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = -10
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	_station_font = font
	if is_instance_valid(_flow):
		bind_flow(_flow, _camera, _course)


func bind_flow(flow: Node, camera: Camera2D, course: Node2D) -> void:
	_disconnect_sources()
	_flow = flow
	_camera = camera
	_course = course
	_animation_time = 0.0
	_world_offset = float(course.get("total_offset")) if flow.has_method("is_endless") and flow.is_endless() else 0.0
	if not is_node_ready():
		return
	_phase = str(flow.get("phase"))
	_paused = get_tree().paused or _phase == "paused"
	_resolved = _phase in ["failed", "finished"]
	_station_enabled = str(course.get("level_id")) == "relay_station" and not bool(course.get("lab_mode"))
	_connect_source("pause_changed", _on_pause_changed)
	_connect_source("run_failed", _on_run_failed)
	_connect_source("run_finished", _on_run_finished)
	_connect_source("mode_changed", _on_mode_changed)
	_connect_source("world_shifted", _on_world_shifted)
	queue_redraw()


func _connect_source(signal_name: String, callback: Callable) -> void:
	if is_instance_valid(_flow) and _flow.has_signal(signal_name):
		_flow.connect(signal_name, callback)
		_connections.append({"source": _flow, "signal": signal_name, "callback": callback})


func _disconnect_sources() -> void:
	for connection in _connections:
		var source: Object = connection.source
		if is_instance_valid(source) and source.is_connected(connection.signal, connection.callback):
			source.disconnect(connection.signal, connection.callback)
	_connections.clear()


func _on_pause_changed(value: bool) -> void:
	_paused = value

func _on_world_shifted(_distance: float) -> void:
	_world_offset = float(_course.get("total_offset"))
	queue_redraw()


func _on_run_failed(_reason: String, _elapsed: float, _ratio: float) -> void:
	_resolved = true


func _on_run_finished(_elapsed: float, _deaths: int, _best: float) -> void:
	_resolved = true


func _on_mode_changed(_mode: String) -> void:
	_phase = str(_flow.get("phase"))
	_resolved = _phase in ["failed", "finished"]
	_paused = get_tree().paused or _phase == "paused"
	if _phase == "ready":
		_animation_time = 0.0


func _process(delta: float) -> void:
	if is_instance_valid(_flow):
		_phase = str(_flow.get("phase"))
		_resolved = _phase in ["failed", "finished"]
	if not _paused and not _resolved and not get_tree().paused:
		_animation_time += delta
	queue_redraw()


func _draw() -> void:
	var inverse := get_global_transform_with_canvas().affine_inverse()
	var top_left := inverse * Vector2.ZERO
	var bottom_right := inverse * get_viewport_rect().size
	var view := Rect2(top_left - Vector2(64, 64), bottom_right - top_left + Vector2(128, 128))
	draw_rect(view, Color("18212b"))
	# Three independently projected industrial layers. World geometry and
	# instructional text remain in Course at their existing z/order.
	var camera_x := top_left.x + _world_offset
	_draw_far_layer(view, camera_x)
	_draw_mid_layer(view, camera_x)
	_draw_near_layer(view, camera_x)
	if _station_enabled:
		_station_section = int(_course.section_at((top_left.x + bottom_right.x) * 0.5))
		_draw_station_architecture(view)
		_draw_route_signs(view)
	_draw_particles(view, camera_x)
	_draw_goal_beacon(view)


func _screen_world_x(index: int, spacing: float, camera_x: float, parallax: float) -> float:
	return float(index) * spacing + camera_x * (1.0 - parallax) - _world_offset


func _draw_far_layer(view: Rect2, camera_x: float) -> void:
	var p: float = PARALLAX[0]
	var first := int(floor(camera_x * p / 220.0)) - 2
	var last := int(ceil((camera_x * p + view.size.x) / 220.0)) + 2
	for index in range(first, last):
		var x := _screen_world_x(index, 220.0, camera_x, p)
		var height := 140.0 + 70.0 * (0.5 + 0.5 * sin(index * 2.43))
		draw_rect(Rect2(x, 422.0 - height, 136.0, height), Color("1b2934"))
		draw_rect(Rect2(x + 8, 422.0 - height - 12.0, 92.0, 12.0), Color("1c2d38"))
		for row in 4:
			var lit := 0.5 + 0.5 * sin(_animation_time * 1.8 - index * 0.8 - row * 0.65)
			draw_rect(Rect2(x + 20, 438.0 - height + row * 22.0, 5, 5), Color(0.21, 0.49, 0.51, 0.12 + lit * 0.16))
	# A wide signal sweep is visible on the distant transmission rail.
	draw_line(Vector2(view.position.x, 230), Vector2(view.end.x, 230), Color("20343e"), 1)
	for index in range(int(floor((camera_x * p - _animation_time * 52.0) / 380.0)) - 1, int(ceil((camera_x * p + view.size.x - _animation_time * 52.0) / 380.0)) + 1):
		var x := _screen_world_x(index, 380.0, camera_x, p) + _animation_time * 52.0
		draw_line(Vector2(x - 32, 230), Vector2(x, 230), Color(0.24, 0.68, 0.65, 0.38), 2)


func _draw_mid_layer(view: Rect2, camera_x: float) -> void:
	var p: float = PARALLAX[1]
	var first := int(floor(camera_x * p / 176.0)) - 2
	var last := int(ceil((camera_x * p + view.size.x) / 176.0)) + 2
	for index in range(first, last):
		var x := _screen_world_x(index, 176.0, camera_x, p)
		draw_line(Vector2(x, 96), Vector2(x, 448), Color("20323e"), 1)
		var y := 292.0 + 24.0 * sin(index * 2.17)
		draw_rect(Rect2(x + 22, y, 94, 128), Color("223440"))
		draw_line(Vector2(x + 32, y + 12), Vector2(x + 106, y + 110), Color("2b414d"), 2)
		draw_line(Vector2(x + 106, y + 12), Vector2(x + 32, y + 110), Color("2b414d"), 2)
		var pulse := 0.5 + 0.5 * sin(_animation_time * 2.0 - index * 1.6)
		var lamp := Vector2(x + 68, y + 23)
		_draw_soft_light(lamp, 12.0 + pulse * 6.0, Color(0.24, 0.68, 0.65, 0.035 + pulse * 0.035))
		draw_rect(Rect2(lamp - Vector2(7, 2), Vector2(14, 4)), Color(0.29, 0.77, 0.72, 0.26 + pulse * 0.30))


func _draw_near_layer(view: Rect2, camera_x: float) -> void:
	var p: float = PARALLAX[2]
	var first := int(floor(camera_x * p / 304.0)) - 2
	var last := int(ceil((camera_x * p + view.size.x) / 304.0)) + 2
	for index in range(first, last):
		var x := _screen_world_x(index, 304.0, camera_x, p)
		var y := 254.0 + 28.0 * sin(index * 1.9)
		draw_line(Vector2(x, y), Vector2(x + 142, y), Color("30444f"), 2)
		draw_line(Vector2(x + 142, y), Vector2(x + 142, y + 58), Color("30444f"), 2)
		var packet_x := x + fposmod(_animation_time * 66.0 + index * 53.0, 138.0)
		draw_line(Vector2(packet_x - 12, y), Vector2(packet_x, y), Color(0.27, 0.72, 0.69, 0.53), 2)
		var pulse := 0.5 + 0.5 * sin(_animation_time * 2.6 + index * 0.7)
		draw_circle(Vector2(x + 142, y + 58), 3.0, Color(0.31, 0.66, 0.67, 0.18 + pulse * 0.32))


func _draw_particles(view: Rect2, camera_x: float) -> void:
	# Deterministic sparse particles stay above the main ground/landing band.
	for index in 22:
		var p := 0.22 + float(index % 3) * 0.12
		var x := camera_x - _world_offset + fposmod(index * 173.31 + _animation_time * (5.0 + index % 5) - camera_x * p, view.size.x)
		var y := 126.0 + fposmod(index * 43.71 - _animation_time * (3.0 + index % 4), 262.0)
		var alpha := 0.10 + 0.10 * (0.5 + 0.5 * sin(_animation_time * 1.6 + index))
		draw_line(Vector2(x - 3, y + 1), Vector2(x, y), Color(0.37, 0.68, 0.68, alpha), 1)


func _draw_soft_light(center: Vector2, radius: float, color: Color) -> void:
	for ring in range(4, 0, -1):
		var tint := color
		tint.a *= float(5 - ring) * 0.25
		draw_circle(center, radius * float(ring) * 0.25, tint)


func _draw_station_architecture(view: Rect2) -> void:
	var starts: Array = _course.get("section_starts")
	for section in starts.size():
		var start := float(starts[section])
		var end := float(starts[section + 1]) if section + 1 < starts.size() else float(_course.get("course_length"))
		if end < view.position.x or start > view.end.x:
			continue
		var tint: Color = STATION_COLORS[mini(section, 4)]
		var muted := tint
		muted.a = 0.09
		var visible_start := maxf(start, view.position.x)
		var visible_end := minf(end, view.end.x)
		# Ambient ceiling circuitry never creates a platform silhouette.
		draw_rect(Rect2(visible_start, 218, visible_end - visible_start, 16), Color(0.06, 0.12, 0.16, 0.34))
		var spacing := 260.0 if section in [0, 4] else 360.0
		for index in range(int(floor((visible_start - start) / spacing)) - 1, int(ceil((visible_end - start) / spacing)) + 1):
			var x := start + 72.0 + float(index) * spacing
			if section == 0:
				# Intake: narrow aerials and short receiver pulses.
				draw_line(Vector2(x + 30, 286), Vector2(x + 30, 413), Color("2c4550"), 3)
				draw_line(Vector2(x + 9, 288), Vector2(x + 51, 288), muted, 2)
				var pulse := 0.5 + 0.5 * sin(_animation_time * 1.6 - index)
				_draw_soft_light(Vector2(x + 30, 288), 11 + pulse * 8, Color(tint.r, tint.g, tint.b, 0.035))
			elif section in [1, 3]:
				# Relay bays: broken/closed socket forms behind the route.
				var height := 152.0 if section == 1 else 184.0
				draw_rect(Rect2(x, 434 - height, 128, height), Color(0.095, 0.15, 0.19, 0.45))
				draw_arc(Vector2(x + 64, 335), 26, 0.25, PI - 0.25, 22, muted, 2, true)
				draw_arc(Vector2(x + 64, 335), 26, PI + 0.25, TAU - 0.25, 22, muted, 2, true)
				draw_line(Vector2(x + 64, 364), Vector2(x + 64, 414), muted, 2)
			elif section == 2:
				# Transmission: parallel moving channels with staggered packets.
				for row in 3:
					var y := 270.0 + row * 44.0
					draw_line(Vector2(x, y), Vector2(x + 276, y), Color("2b424e"), 1)
					var packet := fposmod(_animation_time * 92 + row * 71 + index * 37, 248.0)
					draw_line(Vector2(x + packet, y), Vector2(x + packet + 22, y), Color(tint.r, tint.g, tint.b, 0.30), 2)
			else:
				# Output: tall amplifiers and amber status bars near the finish.
				draw_rect(Rect2(x, 256, 106, 178), Color(0.11, 0.16, 0.19, 0.46))
				for row in 4:
					var power := 0.5 + 0.5 * sin(_animation_time * 1.7 - row * 0.7 - index * 0.3)
					draw_rect(Rect2(x + 18, 276 + row * 23, 14 + power * 45, 3), Color(tint.r, tint.g, tint.b, 0.10 + 0.11 * power))


func _draw_route_signs(view: Rect2) -> void:
	var relays: Array = _course.get("relays")
	for index in relays.size():
		var at: Vector2 = relays[index].position
		if at.x < view.position.x - 500 or at.x > view.end.x + 500:
			continue
		var sign := Vector2(at.x - (450.0 if index == 0 else 490.0), 284 if index == 0 else 224)
		var title := "中继路线  ↑" if index == 0 else "中继路线  ↑  蹬墙"
		draw_string(_station_font, sign, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("d6b665"))
		_draw_route_arrow(sign + Vector2(36, 20), true, Color("d6b665"))
		var low := Vector2(at.x - 410, 423)
		draw_string(_station_font, low, "稳路  →", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("9bb5ba"))
		# Exit labels sit after the upper landing and before the common route.
		var merge := Vector2(at.x + (410.0 if index == 0 else 440.0), 402)
		draw_string(_station_font, merge - Vector2(62, 0), "汇合  →", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("9bb5ba"))
		_draw_route_arrow(merge + Vector2(14, 13), false, Color("9bb5ba"))


func _draw_route_arrow(at: Vector2, up: bool, color: Color) -> void:
	var points := PackedVector2Array([Vector2(-5, 3), Vector2(0, -3), Vector2(5, 3)]) if up else PackedVector2Array([Vector2(-3, -5), Vector2(3, 0), Vector2(-3, 5)])
	for index in points.size():
		points[index] += at
	draw_polyline(points, color, 1.5, true)


func _draw_goal_beacon(view: Rect2) -> void:
	if not is_instance_valid(_course):
		return
	if is_instance_valid(_flow) and _flow.has_method("is_endless") and _flow.is_endless():
		return
	var finish_x := float(_course.get("finish_x"))
	if finish_x < view.position.x - 80 or finish_x > view.end.x + 80:
		return
	var pulse := 0.5 + 0.5 * sin(_animation_time * 2.2)
	_draw_soft_light(Vector2(finish_x, 377), 52.0 + pulse * 8.0, Color(1.0, 0.72, 0.27, 0.035))
	for index in 3:
		var cycle := fposmod(_animation_time * 0.7 + index / 3.0, 1.0)
		var y := 303.0 - cycle * 68.0
		var color := Color(1.0, 0.79, 0.38, 0.38 * (1.0 - cycle))
		draw_polyline(PackedVector2Array([Vector2(finish_x - 9, y + 4), Vector2(finish_x, y), Vector2(finish_x + 9, y + 4)]), color, 2.0, true)


func presentation_state() -> Dictionary:
	return {"animation_time": _animation_time, "paused": _paused, "resolved": _resolved, "phase": _phase,
		"parallax_factors": PARALLAX, "camera_bound": is_instance_valid(_camera), "course_bound": is_instance_valid(_course),
		"station_enabled": _station_enabled, "station_section": _station_section, "world_offset": _world_offset}


func _exit_tree() -> void:
	_disconnect_sources()
