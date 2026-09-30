extends Node2D

signal goal_reached(player: Node2D)

var lab_mode := false
var course_length := 13600.0
var spawn_position := Vector2(96, 430)
var finish_x := 13440.0
var floors: Array[Rect2] = []
var gaps: Array[Rect2] = []
var spikes: Array[Rect2] = []
var walls: Array[Rect2] = []
var section_names := ["01 / 安全教学", "02 / 单项练习", "03 / 组合挑战", "04 / 终点冲刺"]
var _textures: Dictionary = {}
var _world_font: SystemFont

func _ready() -> void:
	_world_font = SystemFont.new()
	_world_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_build_layout()
	for rect in floors + walls:
		_add_solid(rect)
	for rect in spikes:
		_add_spikes(rect)
	var goal := Area2D.new()
	goal.name = "Goal"
	goal.position = Vector2(finish_x, 400)
	goal.collision_layer = 8
	goal.collision_mask = 2
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(36, 96)
	collider.shape = shape
	goal.add_child(collider)
	goal.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player"):
			goal_reached.emit(body))
	add_child(goal)
	for key in ["terrain_platform", "terrain_solid", "terrain_wall_left", "hazard_spike_up", "goal_gate", "background_industrial"]:
		var resource_path: String = "res://assets/visual/" + key + ".png"
		if ResourceLoader.exists(resource_path):
			_textures[key] = load(resource_path)
	queue_redraw()

func _build_layout() -> void:
	if lab_mode:
		course_length = 2400.0
		finish_x = 2240.0
		gaps = [Rect2(920, 448, 96, 92)]
		spikes = [Rect2(544, 424, 32, 24), Rect2(1680, 424, 64, 24)]
		walls = [Rect2(1280, 320, 64, 128)]
	else:
		var positions := [960, 1712, 2672, 3584, 3968, 5408, 6144, 7056, 7520, 8768, 9536, 10288, 11200, 12288]
		var widths := [80, 96, 112, 80, 96, 112, 96, 128, 96, 112, 128, 96, 112, 96]
		for i in positions.size():
			gaps.append(Rect2(positions[i], 448, widths[i], 92))
		for x in [608, 1376, 2288, 3040, 4880, 5792, 6512, 7984, 9184, 9920, 10720, 11712, 12720]:
			spikes.append(Rect2(x, 424, 32 if x < 6800 else 64, 24))
		walls = [Rect2(4608, 320, 64, 128), Rect2(8304, 320, 64, 128)]
	var cursor := 0.0
	for gap in gaps:
		floors.append(Rect2(cursor, 448, gap.position.x - cursor, 160))
		cursor = gap.end.x
	floors.append(Rect2(cursor, 448, course_length - cursor, 160))

func _add_solid(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	body.collision_layer = 1
	body.collision_mask = 2
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
	body.add_child(collider)
	add_child(body)

func _add_spikes(rect: Rect2) -> void:
	var area := Area2D.new()
	area.position = rect.position
	area.collision_layer = 4
	area.collision_mask = 2
	for offset in range(0, int(rect.size.x), 32):
		# The delivered 32px tile has three teeth at x=0/10/20 and a 5px base.
		# Its rendered origin is 8px above the logical hazard rectangle.
		for tooth in [0, 10, 20]:
			var collider := CollisionPolygon2D.new()
			collider.polygon = PackedVector2Array([Vector2(offset + tooth, 19), Vector2(offset + tooth + 5, -5), Vector2(offset + tooth + 10, 19)])
			area.add_child(collider)
		var base := CollisionShape2D.new()
		var base_shape := RectangleShape2D.new()
		base_shape.size = Vector2(32, 5)
		base.shape = base_shape
		base.position = Vector2(offset + 16, 21.5)
		area.add_child(base)
	area.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player"):
			body.die("spike"))
	add_child(area)

func section_at(x: float) -> int:
	return clampi(int(x / 3400.0), 0, 3)

func _draw() -> void:
	draw_rect(Rect2(-1000, -1000, course_length + 2000, 2000), Color("18212b"))
	if _textures.has("background_industrial"):
		for x in range(0, int(course_length), 960):
			draw_texture_rect(_textures.background_industrial, Rect2(x, 0, 960, 540), false)
	for x in range(0, int(course_length), 128):
		draw_line(Vector2(x, 96), Vector2(x, 540), Color("20303b"), 1)
		draw_line(Vector2(x, 272), Vector2(x + 64, 272), Color("273b47"), 1)
		if x % 512 == 0:
			draw_rect(Rect2(x, 200, 80, 96), Color("1d2934"))
	for i in 4:
		var x := float(i * 3400 + 260)
		draw_string(_font(), Vector2(x, 176), "%02d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 100, Color("263947"))
		draw_string(_font(), Vector2(x, 205), section_names[i] if not lab_mode else "MOVEMENT LAB / 控制测试房", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("607987"))
	for rect in floors + walls:
		draw_rect(rect, Color("334554"))
		if _textures.has("terrain_solid"):
			draw_texture_rect(_textures.terrain_solid, rect, true)
		if _textures.has("terrain_platform"):
			draw_texture_rect(_textures.terrain_platform, Rect2(rect.position, Vector2(rect.size.x, 32)), true)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4)), Color("e6efed"))
		for x in range(int(rect.position.x) + 16, int(rect.end.x), 64):
			draw_line(Vector2(x, rect.position.y + 20), Vector2(x + 18, rect.position.y + 38), Color("405a65"), 2)
	for wall in walls:
		if _textures.has("terrain_wall_left"):
			draw_texture_rect(_textures.terrain_wall_left, Rect2(wall.position, Vector2(32, wall.size.y)), true)
		draw_rect(Rect2(wall.position, Vector2(4, wall.size.y)), Color("45dccb"))
		draw_string(_font(), Vector2(wall.position.x - 168, 288), "蹬墙：跳跃 → 再次跳跃", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("45dccb"))
	for rect in spikes:
		for x in range(int(rect.position.x), int(rect.end.x), 32):
			if _textures.has("hazard_spike_up"):
				draw_texture_rect(_textures.hazard_spike_up, Rect2(x, 416, 32, 32), false)
			else:
				draw_colored_polygon(PackedVector2Array([Vector2(x, 448), Vector2(x + 16, 424), Vector2(x + 32, 448)]), Color("ff685c"))
	for gap in gaps:
		draw_line(Vector2(gap.position.x, 466), Vector2(gap.end.x, 466), Color("ff685c"), 1)
		draw_string(_font(), Vector2(gap.position.x + 4, 494), "VOID", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("8d5550"))
	draw_string(_font(), Vector2(96, 382), "A / D 移动     SPACE 跳跃", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("e6efed"))
	draw_string(_font(), Vector2(96, 410), "短按低跳 · 长按高跳 · R 重开", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("607987"))
	if _textures.has("goal_gate"):
		draw_texture_rect(_textures.goal_gate, Rect2(finish_x - 24, 352, 48, 96), false)
	else:
		draw_rect(Rect2(finish_x - 24, 352, 48, 96), Color("ffd166"), false, 4)
		draw_rect(Rect2(finish_x - 14, 362, 28, 86), Color("ffd166"), false, 2)
	draw_string(_font(), Vector2(finish_x - 86, 330), "FINISH / 终点", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("ffd166"))

func _font() -> Font:
	return _world_font
