extends "res://scripts/level/course.gd"
## Producer-owned infinite course. Public geometry and chunks are read-only to art.
signal chunks_changed
signal chunk_added(chunk: Dictionary)
signal chunk_removed(chunk_id: String)
var run_seed := 1
var generation_profile: Dictionary = {}
var prototype := true
var chunks: Array[Dictionary] = []
var total_offset := 0.0
var test_sequence: Array[String] = []
const Library = preload("res://scripts/level/endless_library.gd")
const Generator = preload("res://scripts/level/endless_generator.gd")
const AHEAD := 3200.0
const RETAIN := 960.0
const REBASE_AT := 32768.0
const REBASE_BY := 25600.0
var streaming := false
var generator := Generator.new()
var _holders: Dictionary = {}
var _generated_end := 0.0

func _ready() -> void:
	if prototype or not test_sequence.is_empty():
		super._ready()
		return
	streaming = true
	level_id = "endless"
	finish_x = 1.0e9
	section_starts.assign([0.0])
	section_names = ["无限信号跑道"]
	_world_font = SystemFont.new()
	_world_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	for key in ["terrain_platform", "terrain_solid", "terrain_wall_left", "hazard_spike_up"]:
		_textures[key] = load("res://assets/visual/" + key + ".png")
	for pair in [["terrain_platform","platform_cap"],["terrain_solid","ground_side"]]:
		var path: String = "res://assets/visual/v05/"+pair[1]+".svg"
		if ResourceLoader.exists(path):
			_textures[pair[0]] = load(path)
	if ResourceLoader.exists("res://assets/visual/v05/route_upper.svg"):
		_textures["upper_route"] = load("res://assets/visual/v05/route_upper.svg")
	generator.reset(run_seed, generation_profile)
	update_stream(spawn_position.x, -544)

func update_stream(player_x: float, front_x: float) -> void:
	if not streaming:
		return
	var changed := false
	while _generated_end < player_x + AHEAD:
		_append_chunk(generator.next())
		changed = true
	var retire_before := minf(player_x - RETAIN, front_x - RETAIN)
	while not chunks.is_empty() and chunks[0].origin + chunks[0].length < retire_before:
		var retired: Dictionary = chunks.pop_front()
		var holder: Node = _holders[retired.id]
		remove_child(holder)
		holder.queue_free()
		_holders.erase(retired.id)
		chunk_removed.emit(retired.id)
		changed = true
	if changed:
		_sync_geometry()
		chunks_changed.emit()
		queue_redraw()

func _append_chunk(entry: Dictionary) -> void:
	var d: Dictionary = entry.get("geometry", Library.definition(entry.template_id))
	var id := "%d:%d" % [run_seed, entry.index]
	var origin := _generated_end
	var chunk := {"id": id, "index": entry.index, "template_id": entry.template_id, "origin": origin, "length": d.length, "difficulty": d.difficulty, "category": d.category, "relays": []}
	chunk.geometry = d.duplicate(true)
	chunk.segment_role = entry.get("segment_role","")
	chunk.stage = entry.stage
	var holder := Node2D.new()
	holder.name = "Chunk_%d" % entry.index
	holder.position.x = origin
	add_child(holder)
	_holders[id] = holder
	for rect in d.floors + d.walls:
		_add_solid(rect, holder)
	for rect in d.platforms:
		_add_solid(rect,holder,d.get("vertical",false))
	for rect in d.spikes:
		_add_spikes(rect, holder)
	for relay in d.relays:
		chunk.relays.append({"id": id + ":" + relay.local_id, "position": relay.position + Vector2(origin, 0), "local_position": relay.position, "activated": false})
	chunks.append(chunk)
	_generated_end += d.length
	course_length = _generated_end
	chunk_added.emit(chunk)

func _sync_geometry() -> void:
	floors.clear()
	walls.clear()
	gaps.clear()
	spikes.clear()
	relays.clear()
	for chunk in chunks:
		var d: Dictionary = chunk.get("geometry", Library.definition(chunk.template_id))
		for pair in [["floors", floors], ["platforms", floors], ["walls", walls], ["gaps", gaps], ["spikes", spikes]]:
			for rect in d[pair[0]]:
				pair[1].append(Rect2(rect.position + Vector2(chunk.origin, 0), rect.size))
		for relay in chunk.relays:
			relay.position = relay.local_position + Vector2(chunk.origin, 0)
			relays.append(relay)

func shift_world(distance: float) -> void:
	if not streaming:
		return
	total_offset += distance
	_generated_end -= distance
	course_length -= distance
	for chunk in chunks:
		chunk.origin -= distance
		_holders[chunk.id].position.x -= distance
	_sync_geometry()
	chunks_changed.emit()
	queue_redraw()

func lifecycle_state() -> Dictionary:
	return {"chunks": chunks.size(), "holders": _holders.size(), "relays": relays.size(), "bodies": get_child_count(), "offset": total_offset, "generated": generator.index}

func _build_layout() -> void:
	level_id = "endless"
	course_length = 20000.0
	finish_x = 1.0e9
	section_starts.assign([0.0])
	section_names = ["无限信号跑道"]
	if not prototype:
		var sequence: Array[String] = test_sequence if not test_sequence.is_empty() else ["safe_a", "gap", "spike", "relay_a", "wall_a", "safe_b"]
		floors.clear()
		walls.clear()
		for index in sequence.size():
			_add_layout(sequence[index], index, index * 1280.0)
		course_length = sequence.size() * 1280.0
		return
	floors.assign([Rect2(-960, 448, 21920, 160)])
	walls.assign([Rect2(1200, 320, 32, 128)])
	chunks.assign([{"id": "%d:0" % run_seed, "template_id": "prototype", "origin": 0.0, "length": 20000.0, "difficulty": 0, "category": "prototype"}])

func _add_layout(template_id: String, index: int, origin: float) -> void:
	var d := preload("res://scripts/level/endless_library.gd").definition(template_id)
	chunks.append({"id": "%d:%d" % [run_seed, index], "template_id": template_id, "origin": origin, "length": d.length, "difficulty": d.difficulty, "category": d.category})
	for pair in [["floors", floors], ["platforms", floors], ["walls", walls], ["gaps", gaps], ["spikes", spikes]]:
		for rect in d[pair[0]]:
			pair[1].append(Rect2(rect.position + Vector2(origin, 0), rect.size))
	for relay in d.relays:
		relays.append({"id": "%d:%d:%s" % [run_seed, index, relay.local_id], "position": relay.position + Vector2(origin, 0), "activated": false})

func safe_surface(point: Vector2) -> Dictionary:
	for chunk in chunks:
		var d: Dictionary = chunk.get("geometry", Library.definition(chunk.template_id))
		for rect in d.floors + d.platforms + d.walls:
			var x: float = point.x - chunk.origin
			if x < rect.position.x + 14 or x > rect.end.x - 14 or absf(point.y + 15 - rect.position.y) > 5:
				continue
			var unsafe := false
			for spike in d.spikes:
				unsafe = unsafe or (x > spike.position.x - 20 and x < spike.end.x + 20 and absf(rect.position.y - spike.end.y) < 32)
			if not unsafe:
				return {"chunk_id":chunk.id,"global_point":Vector2(point.x + total_offset,rect.position.y - 16)}
	return {}

func safe_point_exists(saved: Dictionary) -> bool:
	for chunk in chunks:
		if chunk.id == saved.get("chunk_id", ""):
			return true
	return false

func _draw() -> void:
	super._draw()
	if not _textures.has("upper_route"):
		return
	for chunk in chunks:
		var d: Dictionary = chunk.get("geometry",{})
		if not d.get("vertical",false) or d.relays.is_empty() or d.platforms.is_empty():
			continue
		var rect: Rect2 = d.platforms[0]
		draw_texture_rect(_textures.upper_route,Rect2(chunk.origin+rect.position.x,rect.position.y-58,80,28),false)
