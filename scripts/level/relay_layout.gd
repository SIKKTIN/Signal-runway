extends RefCounted
## Producer-owned geometry. Grid design is translated into measured world space.
static func build(course: Node2D, prototype: bool) -> void:
	if not prototype:
		_build_station(course)
		return
	course.course_length = 2600.0
	course.finish_x = 2440.0
	course.section_starts.assign([0.0])
	course.section_names = ["01 / 中继分流原型"]
	course.gaps.assign([Rect2(1072, 448, 112, 92)])
	course.floors.assign([Rect2(0, 448, 1072, 160), Rect2(1184, 448, 1416, 160), Rect2(544, 400, 180, 16), Rect2(792, 352, 160, 16)])
	course.relays.assign([{"id": "relay_one", "position": Vector2(870, 314), "activated": false}])

static func _build_station(course: Node2D) -> void:
	course.course_length = 14500.0
	course.finish_x = 14340.0
	course.section_starts.assign([0.0, 2100.0, 4400.0, 7200.0, 11200.0])
	course.section_names = ["01 / 接入区", "02 / 第一处分流", "03 / 连续传输", "04 / 第二处分流", "05 / 输出区"]
	var positions := [960, 1712, 2732, 3584, 5008, 6144, 6800, 7680, 8760, 9600, 10400, 11600, 12640, 13520]
	for i in positions.size():
		course.gaps.append(Rect2(positions[i], 448, 80 if i < 2 else 112, 92))
	var cursor := 0.0
	for gap in course.gaps:
		course.floors.append(Rect2(cursor, 448, gap.position.x - cursor, 160))
		cursor = gap.end.x
	course.floors.append(Rect2(cursor, 448, course.course_length - cursor, 160))
	for x in [608, 1376, 3040, 3968, 5520, 6512, 7008, 7480, 9184, 9920, 10720, 11920, 13040, 13920]:
		course.spikes.append(Rect2(x, 424, 32 if x < 7200 else 64, 24))
	course.floors.append(Rect2(2204, 400, 180, 16))
	course.floors.append(Rect2(2452, 352, 160, 16))
	course.floors.append(Rect2(8240, 384, 120, 16))
	course.walls.append(Rect2(8400, 248, 32, 136))
	course.floors.append(Rect2(8464, 296, 160, 16))
	course.relays.assign([{"id": "relay_one", "position": Vector2(2530, 314), "activated": false}, {"id": "relay_two", "position": Vector2(8520, 258), "activated": false}])
