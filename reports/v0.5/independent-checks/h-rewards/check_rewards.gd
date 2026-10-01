extends SceneTree
## H reward confirmation only, preserving original G evidence.
const OUT := "res://reports/v0.5/independent-checks/h-rewards/"
const Record = preload("res://scripts/level/endless_record.gd")
var app: Node2D
var results: Array[Dictionary] = []
var checks: Array[Dictionary] = []
var events: Array[Dictionary] = []
var held := false
var held_frames := 0
var presses := 0
var route_choice := "primary"
var screenshots: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for _i in n:
		await physics_frame
		await process_frame

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func tap(code: Key) -> void:
	key(code,true)
	await frames(2)
	key(code,false)
	await frames(2)

func check(label: String, passed: bool, actual: Variant = "") -> void:
	checks.append({"check":label,"passed":passed,"actual":actual})
	print(label,": ",passed)

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")

func released() -> void:
	key(KEY_SPACE,false)
	held = false
	held_frames = 0

func on_relay(id: String, delay_added: float, count: int) -> void:
	events.append({"id":id,"added_delay":delay_added,"count":count,"time":app.elapsed,"distance":app.run_distance,"position":app.player.position,"health":app.player.health})

func step_input() -> void:
	held_frames += 1
	if held and held_frames > 4 and app.player.velocity.y >= 0:
		released()
	if held or not app.player.is_on_floor() or app.fall_recovery_remaining > 0:
		return
	var wants_jump := false
	for chunk in app.course.chunks:
		var x: float = app.player.position.x-chunk.origin
		if x < 0 or x > chunk.length:
			continue
		var d: Dictionary = chunk.geometry
		var path: Array = d.floors.duplicate()
		if chunk.template_id == "gap" and d.get("vertical",false):
			path = [d.floors[0]] + d.platforms + [d.floors[1]]
		elif route_choice == "upper" and chunk.template_id in ["rhythm_a","relay_a","relay_b"] and d.get("vertical",false):
			path = [Rect2(0,448,288,160)] + d.platforms + [Rect2(976,448,304,160)]
		for i in path.size()-1:
			var current: Rect2 = path[i]
			if absf(app.player.position.y+15-current.position.y) > 4 or x < current.position.x-10 or x > current.end.x+10:
				continue
			var next: Rect2 = path[i+1]
			var rise: bool = next.position.y < current.position.y
			var gap: float = next.position.x-current.end.x
			var required: bool = rise or (gap > 1 and next.position.y <= current.position.y) or gap > 48
			var lead: float = 60 if gap <= 1 and rise else 28
			wants_jump = required and x >= current.end.x-lead
			break
		for spike in d.spikes:
			wants_jump = wants_jump or (x >= spike.position.x-70 and x < spike.end.x+10)
	if wants_jump:
		key(KEY_SPACE,true)
		held = true
		held_frames = 0
		presses += 1

func source_hashes() -> Dictionary:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://reports/v0.5/version-manifest.json"))
	var mismatches: Array[String] = []
	var hashes: Dictionary = {}
	for row in parsed.files:
		var current := FileAccess.get_sha256("res://"+row.path)
		hashes[row.path] = current
		if current != row.sha256:
			mismatches.append(row.path)
	return {"version":parsed.version,"manifest_sha256":parsed.sha256,"files":hashes,"mismatches":mismatches}

func run() -> void:
	print("H_REWARD_PID ",OS.get_process_id())
	var before := source_hashes()
	check("frozen_production_before_matches", before.mismatches.is_empty(),before.version)
	if not before.mismatches.is_empty():
		quit(2)
		return
	var formal_before := FileAccess.get_sha256(Record.DEFAULT_PATH) if FileAccess.file_exists(Record.DEFAULT_PATH) else "missing"
	var legacy_before := FileAccess.get_sha256(Record.LEGACY_PATH) if FileAccess.file_exists(Record.LEGACY_PATH) else "missing"
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(960,540)
	root.size = Vector2i(1280,720)
	app = load("res://scenes/main/main.tscn").instantiate()
	app.record_path = OUT+"isolated-route-record-%d.json" % OS.get_process_id()
	root.add_child(app)
	app.relay_activated.connect(on_relay)
	await frames(4)
	await tap(KEY_ENTER)
	check("actual_Enter_starts_autorun", app.is_endless() and app.player.auto_run and app.phase == "running")
	for seed_value in [404,77,9001]:
		for choice in ["primary","upper"]:
			released()
			events.clear()
			presses = 0
			route_choice = choice
			app.start_endless(seed_value)
			var max_speed := 280.0
			var visited: Dictionary = {}
			for frame in 3000:
				if app.phase not in ["running","recovering"] or app.run_distance >= 11000:
					break
				step_input()
				await frames(1)
				max_speed = maxf(max_speed,app.target_run_speed)
				for chunk in app.course.chunks:
					if app.player.position.x >= chunk.origin and app.player.position.x < chunk.origin+chunk.length:
						visited[chunk.geometry.get("structure",chunk.template_id)] = true
				if seed_value == 77 and events.size() > 0:
					var capture_key: String = choice+str(events.size())
					if not screenshots.has(capture_key):
						await shot("reward-77-"+capture_key)
						screenshots[capture_key] = true
			var high_nodes := events.filter(func(row): return row.id.ends_with(":high") or row.id.ends_with(":crest")).size()
			var low_nodes := events.filter(func(row): return row.id.ends_with(":low")).size()
			var unique_chunks: Dictionary = {}
			var relay_delay_correct := true
			for event in events:
				var parts: PackedStringArray = event.id.split(":")
				var chunk_id: String = parts[0]+":"+parts[1]
				var expected := 0.0 if unique_chunks.has(chunk_id) else .9
				relay_delay_correct = relay_delay_correct and is_equal_approx(event.added_delay,expected)
				unique_chunks[chunk_id] = true
			var result := {"seed":seed_value,"route":choice,"phase":app.phase,"distance":app.run_distance,"health":app.player.health,"hurt_count":app.player.hurt_count,"max_speed":max_speed,"score":app.run_score,"nodes":app.relay_count,"high_nodes":high_nodes,"low_nodes":low_nodes,"presses":presses,"visited":visited.keys(),"events":events.duplicate(true)}
			results.append(result)
			check("seed_%d_%s_actual_key_route" % [seed_value,choice], app.phase == "running" and app.run_distance >= 11000 and presses > 0 and app.player.health == 3, result)
			check("seed_%d_%s_reward_formula_and_delay" % [seed_value,choice], app.run_score == int(floor(app.run_distance/10))+app.relay_count*100 and relay_delay_correct and app.relay_count > 0)
			released()
	for seed_value in [404,77,9001]:
		var pair: Array = results.filter(func(row):return row.seed == seed_value)
		check("seed_%d_upper_extra_nodes" % seed_value,pair[1].high_nodes > pair[0].high_nodes and pair[1].nodes > pair[0].nodes,{"primary":pair[0].nodes,"upper":pair[1].nodes,"high":pair[1].high_nodes})
	var record: String = app.record_path
	# Actual imported Main/module title capture with explicit camera/prefetch fixture.
	app.start_endless(77)
	app.set_physics_process(false)
	app.player.set_physics_process(false)
	app.course.update_stream(65000,-544)
	var candidates: Array = app.course.chunks.filter(func(chunk):return chunk.template_id == "relay_b" and chunk.geometry.get("vertical",false))
	check("actual_stream_contains_v3_relay_b_for_title",not candidates.is_empty())
	var title_fixture := {}
	if not candidates.is_empty():
		var chunk: Dictionary = candidates[0]
		app.player.position = Vector2(chunk.origin+400,430)
		app.camera.position_smoothing_enabled = false
		app.camera.position = Vector2(chunk.origin+620,270)
		app.camera.reset_smoothing()
		app.camera.force_update_scroll()
		await frames(4)
		var module: Node = app.world.get_node("EndlessWorldVisual")._modules[chunk.id]
		check("actual_module_received_vertical_relay_b_metadata",module._vertical and module._template_id == "relay_b")
		await shot("relay-b-title-1280")
		title_fixture = {"chunk":chunk.id,"geometry":chunk.geometry,"camera":app.camera.position,"expected":"高路中继 ↑ 连跳","scope":"Actual Main/module with seeded prefetch and fixed camera/player; screenshot/title evidence only, not route completion."}
	root.remove_child(app)
	app.free()
	app = null
	await frames(8)
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(record+suffix):
			DirAccess.remove_absolute(record+suffix)
	var after := source_hashes()
	var formal_after := FileAccess.get_sha256(Record.DEFAULT_PATH) if FileAccess.file_exists(Record.DEFAULT_PATH) else "missing"
	var legacy_after := FileAccess.get_sha256(Record.LEGACY_PATH) if FileAccess.file_exists(Record.LEGACY_PATH) else "missing"
	check("production_and_real_records_unchanged",before.files == after.files and after.mismatches.is_empty() and formal_before == formal_after and legacy_before == legacy_after)
	var passed: bool = checks.all(func(row):return row.passed)
	var file := FileAccess.open(OUT+"routes-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"runs":results,"title_fixture":title_fixture,"before":before,"after":after,"formal_record_hash":formal_before,"legacy_record_hash":legacy_before,"method":"H reward fix only. Three seeds/upper-primary routes with same synthetic-key strategy, no route position/health/time injection. Separate title fixture uses actual seeded Main/module and fixed camera/player. No tools/life/old77/long suites rerun. Not human keyboard/experience."},"\t"))
	file.close()
	await create_timer(.15).timeout
	quit(0 if passed else 1)
