extends Node2D
## One recyclable decoration per active chunk. No geometry, RNG or flow writes.
var _chunk_id := ""
var _template_id := ""
var _category := "safe"
var _vertical := false
var _role := ""
var _has_challenge := false
var _has_station := false
var _length := 960.0
var _total_offset := 0.0
var _animation_time := 0.0
var _phase_offset := 0.0
var _font: Font

func _ready() -> void:
	z_index = -8
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	_font = font
	set_process(false)

func configure(chunk: Dictionary, total_offset: float = 0.0) -> void:
	_chunk_id = str(chunk.get("id", ""))
	_template_id = str(chunk.get("template_id", ""))
	_category = str(chunk.get("category", "safe"))
	_vertical = chunk.get("geometry",{}).get("vertical",false)
	_role = str(chunk.get("geometry",{}).get("segment_role",""))
	_has_challenge = chunk.get("geometry",{}).has("challenge")
	_has_station = chunk.get("geometry",{}).has("station")
	_length = maxf(float(chunk.get("length", 960.0)), 1.0)
	_phase_offset = float(absi(_chunk_id.hash()) % 127) * 0.17
	set_world_offset(float(chunk.get("origin", 0.0)), total_offset)

func set_world_offset(origin: float, total_offset: float) -> void:
	position.x = origin
	_total_offset = total_offset
	queue_redraw()

func set_clock(seconds: float) -> void:
	_animation_time = maxf(0.0, seconds)
	queue_redraw()

func _draw() -> void:
	if _font == null:
		return
	var inverse := get_global_transform_with_canvas().affine_inverse()
	var left := maxf(0.0, (inverse * Vector2.ZERO).x - 96.0)
	var right := minf(_length, (inverse * get_viewport_rect().size).x + 96.0)
	var gold := _category in ["relay", "relay_branch"]
	var tower := _category in ["wall", "wall_combo"]
	var accent := Color("b99752") if gold else Color("426975")
	for index in range(int(floor(left / 256.0)), int(ceil(right / 256.0))):
		var x := index * 256.0 + 36.0
		var height := 194.0 if tower else (150.0 if gold else 130.0)
		draw_rect(Rect2(x, 434 - height, 154, height), Color(0.095, 0.15, 0.19, 0.55))
		draw_line(Vector2(x + 14, 432 - height), Vector2(x + 140, 422), Color("293e49"), 2)
		draw_line(Vector2(x + 140, 432 - height), Vector2(x + 14, 422), Color("293e49"), 2)
		var center := Vector2(x + 77, 332)
		var pulse := 0.5 + 0.5 * sin(_animation_time * 1.8 + _phase_offset + index * 0.8)
		if gold:
			draw_arc(center, 22, 0.2, PI - 0.2, 20, Color(accent.r, accent.g, accent.b, 0.20), 2, true)
			draw_arc(center, 22, PI + 0.2, TAU - 0.2, 20, Color(accent.r, accent.g, accent.b, 0.20), 2, true)
		elif tower:
			for row in 5:
				draw_rect(Rect2(x + 56, 273 + row * 23, 42, 3), Color(0.28, 0.48, 0.53, 0.12 + pulse * 0.15))
		elif _category == "rhythm":
			for row in 3:
				var signal_x := x + fposmod(_animation_time * 58 + row * 37 + _phase_offset * 19, 136.0)
				draw_line(Vector2(x, 300 + row * 24), Vector2(x + 146, 300 + row * 24), Color("243641"), 1)
				draw_line(Vector2(signal_x, 300 + row * 24), Vector2(signal_x + 10, 300 + row * 24), Color(0.24, 0.43, 0.48, 0.30), 2)
		else:
			draw_rect(Rect2(center - Vector2(8, 2), Vector2(16, 4)), Color(0.27, 0.66, 0.64, 0.24 + pulse * 0.25))
		var packet := fposmod(_animation_time * 58 + _phase_offset * 19, 136.0)
		draw_line(Vector2(x, 255), Vector2(x + 146, 255), Color("2b424e"), 1)
		draw_line(Vector2(x + packet, 255), Vector2(x + packet + 10, 255), Color(accent.r, accent.g, accent.b, 0.40), 2)
	# Seam marker is a dim vertical conduit, not a floor or obstacle.
	draw_line(Vector2(0, 239), Vector2(0, 430), Color("243641"), 1)
	if _has_station:
		# The dedicated route visual owns the two choices and their advance sign.
		pass
	elif _has_challenge:
		draw_string(_font, Vector2(40,220), "分路 · 稳路 / 连段", HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("d6b665"))
	elif gold:
		var title := "高路中继  ↑  连跳" if _vertical else ("中继路线  ↑  蹬墙" if _template_id == "relay_b" else "中继路线  ↑")
		draw_string(_font, Vector2(288, 220), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("d6b665"))
		draw_string(_font, Vector2(288, 423), "稳路  →", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("9bb5ba"))
	elif tower:
		draw_string(_font, Vector2(440, 220), "蹬墙  ↑  向前", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("77aaa9"))
	elif not _role.is_empty():
		draw_string(_font,Vector2(40,220),_role+"段",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("77aaa9"))

func presentation_state() -> Dictionary:
	return {"id": _chunk_id, "template_id": _template_id, "category": _category, "origin": position.x,
		"length": _length, "pattern_offset": position.x + _total_offset, "phase_offset": _phase_offset, "animation_time": _animation_time}
