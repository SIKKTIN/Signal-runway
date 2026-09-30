extends SceneTree
## Independent main-scene inspection. Inject key events, never bypass jumps.
const OUT := "res://reports/v0.4/independent-checks/"
var app: Node2D
var checks: Array[Dictionary] = []
var _score_before := 0
var _count_before := 0
var _gain_delta := -1
var _relay_event := {}
var _hold := 0
var _jump_presses := 0

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame

func check(name: String, passed: bool, actual: Variant = "") -> void:
	checks.append({"check": name, "passed": passed, "actual": actual})
	print(name, ": ", passed, " ", actual)

func key_event(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func tap(code: Key) -> void:
	key_event(code, true)
	await frames(2)
	key_event(code, false)
	await frames(2)

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")

func visual(name: String) -> Node:
	return app.world.get_node(name)

func clocks() -> Array:
	var result: Array = []
	for name in ["EnvironmentVisual", "ChaseVisual", "RelayVisual", "EndlessWorldVisual", "EndlessHUDVisual"]:
		result.append(visual(name).presentation_state().animation_time)
	return result

func on_stats(score: int, _distance: float, count: int, _stage: int) -> void:
	if count > _count_before:
		_gain_delta = score - _score_before
	_score_before = score
	_count_before = count

func on_relay(id: String, added: float, count: int) -> void:
	_relay_event = {"id": id, "delay_added": added, "count": count, "immediate_score": app.run_score,
		"distance": app.run_distance, "delay_remaining": app.relay_delay_remaining,
		"gain": visual("EndlessHUDVisual")._gain.text}

func ordinary_jump_step() -> void:
	if _hold > 0:
		_hold -= 1
		if _hold == 0:
			key_event(KEY_SPACE, false)
	if _hold > 0 or not app.player.is_on_floor():
		return
	var x: float = app.player.position.x
	var bottom: float = app.player.position.y
	var jump := false
	if bottom > 410:
		for gap in app.course.gaps:
			jump = jump or (x >= gap.position.x - 50 and x < gap.position.x)
		for spike in app.course.spikes:
			jump = jump or (x >= spike.position.x - 60 and x < spike.position.x)
		for wall in app.course.walls:
			jump = jump or (wall.end.y >= 430 and x >= wall.position.x - 60 and x < wall.position.x)
	for relay in app.course.relays:
		# The first relay on seed404 is the two-step branch (relay_a).
		var ahead: float = relay.position.x - x
		jump = jump or (bottom > 410 and ahead <= 372 and ahead > 326) or (bottom < 410 and ahead <= 193 and ahead > 147)
	if jump:
		key_event(KEY_SPACE, true)
		_hold = 25
		_jump_presses += 1

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "frames"))
	app = load("res://scenes/main/main.tscn").instantiate()
	app.record_path = OUT + "isolated-record-%d.json" % OS.get_process_id()
	root.add_child(app)
	app.endless_stats_changed.connect(on_stats)
	app.relay_activated.connect(on_relay)
	await frames(5)
	await shot("menu")
	await tap(KEY_ENTER)
	check("enter_autoruns_default_infinite", app.is_endless() and app.phase == "running" and app.player.auto_run and app.player.position.x > 96)
	check("single_hud_pause_button_and_no_goal", not app.ui.hud.visible and app.ui.endless_pause.visible and not app.course.has_node("Goal"))
	await tap(KEY_ESCAPE)
	var paused_snapshot: Array = [app.elapsed, app.run_score, app.player.position, app.chase.front_x, app.course.generator.index, clocks()]
	await shot("pause-a")
	await frames(20)
	await shot("pause-b")
	check("escape_freezes_logic_and_visuals", paused_snapshot == [app.elapsed, app.run_score, app.player.position, app.chase.front_x, app.course.generator.index, clocks()])
	var initial_seed: int = app.run_seed
	await tap(KEY_R)
	check("paused_r_same_seed_clean_round", app.run_seed == initial_seed and app.phase == "running" and not paused and app.relay_count == 0 and app.course.total_offset == 0)
	app.start_endless(404)
	for _i in 1700:
		if app.phase != "running" or app.relay_count == 1:
			break
		ordinary_jump_step()
		await frames(1)
	check("ordinary_space_events_collect_first_relay", app.relay_count == 1 and app.phase == "running", {"distance": app.run_distance, "presses": _jump_presses})
	check("relay_immediate_exact_100_and_point9", _gain_delta == 100 and _relay_event.get("delay_added", 0) == 0.9 and _relay_event.get("delay_remaining", 0) == 0.9 and _relay_event.get("immediate_score", -1) == int(floor(float(_relay_event.get("distance", 0)) / 10)) + 100, _relay_event)
	check("relay_visual_gain_and_one_audio_trigger", visual("EndlessHUDVisual")._gain.text == "+100" and visual("RelayVisual").presentation_state().sound_triggers == 1)
	await shot("relay")
	await tap(KEY_ESCAPE)
	var delay_snapshot: Array = [app.relay_delay_remaining, app.run_score, clocks()]
	await frames(15)
	check("pause_preserves_active_relay_delay", delay_snapshot == [app.relay_delay_remaining, app.run_score, clocks()] and app.relay_delay_remaining > 0)
	await tap(KEY_ESCAPE)
	var front: float = app.chase.front_x
	var time: float = app.elapsed
	await frames(8)
	check("unpaused_delay_stops_front_not_elapsed", app.chase.front_x == front and app.elapsed > time and app.relay_delay_remaining > 0)
	key_event(KEY_SPACE, false)
	_hold = 0
	# Let the real auto-run reach its next hazard without supplying more jumps.
	for _i in 1800:
		if app.phase == "failed":
			break
		await frames(1)
	check("natural_failure_saves_isolated_best", app.phase == "failed" and app.best_score == app.run_score and app.best_score > 0 and app.endless_record.status == "saved")
	var labels := ""
	for label in app.ui.content.find_children("*", "Label", true, false):
		labels += label.text + "\n"
	check("result_shows_score_best_seed_and_relay", labels.contains(str(app.run_score) + " 分") and labels.contains("本机最高") and labels.contains(str(app.run_seed)) and labels.contains("中继 1"))
	await shot("result")
	var old_best: int = app.best_score
	await tap(KEY_ENTER)
	check("result_enter_retry_loads_isolated_best", app.phase == "running" and app.run_seed == 404 and app.best_score == old_best and visual("EndlessHUDVisual")._record.text == str(old_best))
	# Only this next result is a state fixture; test the actual focused button.
	app.player.die("caught")
	await frames(3)
	await tap(KEY_DOWN)
	var focused: Control = root.gui_get_focus_owner()
	check("down_selects_new_map_button", focused is Button and focused.text == "换图挑战")
	await tap(KEY_ENTER)
	check("keyboard_new_map_changes_seed", app.phase == "running" and app.run_seed != 404)
	# Explicit coordinate/pressure fixtures. No route or balance claims.
	app.set_physics_process(false)
	app.player.set_physics_process(false)
	app.camera.position_smoothing_enabled = false
	app.course.update_stream(33500, 32820)
	app.player.position = Vector2(33500, 430)
	app.camera.position = Vector2(33500, 270)
	app.camera.reset_smoothing()
	app.chase.front_x = 32820
	app.chase.advance(0, 33490)
	await frames(3)
	await tap(KEY_ESCAPE)
	app.ui.overlay.hide()
	await frames(2)
	var before_clocks := clocks()
	var ids: Array = app.course.relays.map(func(entry): return entry.id)
	var origins := {}
	for id in visual("EndlessWorldVisual")._modules:
		var module: Node2D = visual("EndlessWorldVisual")._modules[id]
		origins[id] = module.get_global_transform_with_canvas() * Vector2.ZERO
	await shot("rebase-before")
	app._shift_endless_world(25600)
	await frames(3)
	await shot("rebase-after")
	var stable: bool = clocks() == before_clocks and ids == app.course.relays.map(func(entry): return entry.id)
	for id in origins:
		var module: Node2D = visual("EndlessWorldVisual")._modules[id]
		stable = stable and origins[id].distance_to(module.get_global_transform_with_canvas() * Vector2.ZERO) < 0.01
	check("rebase_preserves_ids_clocks_and_screen_anchors", stable)
	app.ui.overlay.show()
	await tap(KEY_ESCAPE)
	var bounded := true
	var max_chunks := 0
	var max_nodes := 0
	for _i in 24:
		app.player.position.x += 1280
		app.chase.front_x = app.player.position.x - 600
		app.chase.advance(0, app.player.position.x - 10)
		app.course.update_stream(app.player.position.x, app.chase.front_x)
		var rs: Dictionary = visual("RelayVisual").presentation_state()
		max_chunks = maxi(max_chunks, app.course.chunks.size())
		max_nodes = maxi(max_nodes, rs.node_count)
		bounded = bounded and visual("EndlessWorldVisual").presentation_state().module_count == app.course.chunks.size() and rs.node_count == app.course.relays.size() and rs.activated_count <= rs.node_count and rs.pulse_count <= rs.node_count
	check("24_snapshot_cache_retirement", bounded, {"max_chunks": max_chunks, "max_nodes": max_nodes})
	app.camera.position = Vector2(app.player.position.x, 270)
	app.camera.reset_smoothing()
	app.catchup_bonus = 14
	app.chase.speed = 296
	app.chase.front_x = app.player.position.x - 300
	app.chase.grace_remaining = 0
	app.chase.advance(0, app.player.position.x - 10)
	app.elapsed = 180
	app.chase.add_relay_delay(0.9)
	app._update_ui()
	for index in 8:
		await frames(4)
		await shot("frames/motion-%02d" % index)
	check("catchup_speed_and_elapsed_readable_fields", visual("ChaseVisual")._hud_title.text == "远距追速" and visual("ChaseVisual")._hud_detail.text.contains("296") and visual("EndlessHUDVisual")._meta.text.contains("03:00.00"))
	await shot("catchup-delay")
	await tap(KEY_F2)
	app.set_physics_process(true)
	check("f2_manual_lab_has_goal_and_no_endless_hud", app.lab_mode and not app.player.auto_run and app.course.has_node("Goal") and app.ui.hud.visible and not app.world.has_node("EndlessHUDVisual"))
	app.return_to_menu()
	await frames(3)
	await tap(KEY_DOWN)
	await tap(KEY_ENTER)
	check("keyboard_fixed_entry_keeps_manual_start", not app.is_endless() and not app.lab_mode and not app.player.auto_run and app.phase == "ready" and app.course.has_node("Goal"))
	await shot("fixed-entry")
	key_event(KEY_D, true)
	await frames(8)
	key_event(KEY_D, false)
	check("fixed_d_starts_original_challenge", app.phase == "running" and app.player.position.x > 96)
	var passed := checks.all(func(row): return row.passed)
	var record_file: String = app.record_path
	root.remove_child(app)
	app.free()
	await frames(8)
	await create_timer(0.15).timeout
	var file := FileAccess.open(OUT + "runtime.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "engine": Engine.get_version_info().string,
		"renderer": RenderingServer.get_video_adapter_name(), "record_file": record_file,
		"keyboard_method": "Input.parse_input_event keycode/physical_keycode through actual main GUI and unhandled-input routing; not physical human keypresses.",
		"normal_route": "Seed404 first relay using Space key events, real player physics and natural failure; no teleport/freeze during this segment.",
		"fixture_scope": "Explicit caught result for button selection, manual coordinates/catchup and stream snapshots after the normal segment."}, "\t"))
	file.close()
	quit(0 if passed else 1)
