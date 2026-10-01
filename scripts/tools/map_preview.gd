extends Control
signal selected(index: int)
const Library = preload("res://scripts/level/endless_library.gd")
var rows: Array[Dictionary] = []
var focus_index := 0
var single := false
var zoom := 0.5
var pan := Vector2.ZERO
var _drag := false
var _drag_distance := 0.0
var _font: SystemFont
func _ready() -> void:
	clip_contents = true
	mouse_default_cursor_shape = Control.CURSOR_MOVE
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
func set_rows(value: Array[Dictionary]) -> void:
	rows = value
	focus_index = clampi(focus_index, 0, rows.size() - 1)
	queue_redraw()
func fit_all() -> void:
	zoom = clampf(size.x / (Library.LENGTH * (1 if single else maxi(1, rows.size()))), 0.003, 1.8)
	pan = Vector2.ZERO
	queue_redraw()
func focus_on(index: int) -> void:
	focus_index = index
	pan.x = size.x / 2 - ((index + 0.5) * Library.LENGTH if not single else Library.LENGTH / 2) * zoom
	queue_redraw()
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			var old := zoom
			zoom = clampf(zoom * (1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2), 0.003, 1.8)
			pan.x = event.position.x - (event.position.x - pan.x) * zoom / old
			queue_redraw()
			accept_event()
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE]:
			if not event.pressed and _drag_distance < 4 and event.button_index == MOUSE_BUTTON_LEFT and not single:
				focus_index = clampi(int((event.position.x - pan.x) / zoom / Library.LENGTH), 0, rows.size() - 1)
				selected.emit(focus_index)
			_drag = event.pressed
			if _drag:
				_drag_distance = 0
			queue_redraw()
			accept_event()
	elif event is InputEventMouseMotion and _drag:
		pan += event.relative
		_drag_distance += event.relative.length()
		queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101c25"))
	if _font == null:
		return
	var base_y := size.y * 0.64 + pan.y
	for i in rows.size():
		if single and i != focus_index:
			continue
		var origin := 0.0 if single else i * Library.LENGTH
		var x := origin * zoom + pan.x
		if x + Library.LENGTH * zoom < 0 or x > size.x:
			continue
		var d := Library.definition(rows[i].template_id)
		var accent := Color("48d7ce") if d.category == "safe" else (Color("ffc95c") if d.category == "relay" else Color("8295ae"))
		draw_rect(Rect2(x, 0, Library.LENGTH * zoom, size.y), Color(accent, 0.06))
		draw_line(Vector2(x, 0), Vector2(x, size.y), accent, 2 if i == focus_index else 1)
		draw_set_transform(Vector2(x, base_y - 448 * zoom), 0, Vector2.ONE * zoom)
		for rect in d.floors + d.platforms + d.walls:
			draw_rect(rect, Color("405966"))
			draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color("d5eef0"), 3)
		for rect in d.gaps:
			draw_rect(rect, Color("351c28"))
			draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), Color("ff796c"), 2)
		for rect in d.spikes:
			draw_colored_polygon(PackedVector2Array([rect.position + Vector2(0, rect.size.y), rect.position + Vector2(rect.size.x / 2, 0), rect.end]), Color("ff796c"))
			draw_rect(rect, Color("ff796c"), false, 1.5)
		for relay in d.relays:
			draw_circle(relay.position, 16, Color("ffc95c"), false, 3)
			draw_line(relay.position - Vector2(7, 0), relay.position + Vector2(7, 0), Color("ffc95c"), 2)
		draw_set_transform(Vector2.ZERO)
		if Library.LENGTH * zoom > 95:
			draw_string(_font, Vector2(x + 6, 22), "%02d %s" % [i, rows[i].template_id], HORIZONTAL_ALIGNMENT_LEFT, Library.LENGTH * zoom - 10, 14, accent)
			draw_string(_font, Vector2(x + 6, 42), "阶段%d / 难度%d" % [rows[i].stage + 1, d.difficulty], HORIZONTAL_ALIGNMENT_LEFT, Library.LENGTH * zoom - 10, 13, Color("a0b4be"))
		if i == focus_index:
			draw_rect(Rect2(x, 1, Library.LENGTH * zoom, size.y - 2), Color("ffc95c"), false, 2)
	draw_string(_font, Vector2(12, size.y - 12), "滚轮缩放 · 左/中键拖动 · 点击选段 · 黄色中继 / 红色危险", HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 14, Color("b0c4ca"))
