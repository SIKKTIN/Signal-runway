extends SceneTree
var checks: Array[Dictionary] = []
var app: Node2D
var failures := 0
func frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame
func check(label: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"check": label, "passed": passed, "detail": detail})
	print(label, ": ", passed, " ", detail)
func key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	app.run_failed.connect(func(_r, _t, _p): failures += 1)
	await frames(5)
	check("main_defaults_to_pursuit", app.mode == "pursuit" and app.phase == "menu")
	app.ui.start_requested.emit()
	await frames(15)
	check("ready_waits_for_input", app.phase == "ready" and app.elapsed == 0.0 and app.chase.front_x == -544.0)
	key(KEY_D, true)
	await frames(12)
	key(KEY_D, false)
	check("real_input_starts_grace", app.phase == "running" and app.chase.enabled and app.chase.grace_remaining > 1.7 and app.chase.front_x == -544.0)
	key(KEY_ESCAPE, true)
	await frames(2)
	key(KEY_ESCAPE, false)
	var snapshot := [app.elapsed, app.chase.front_x, app.chase.grace_remaining, app.player.position]
	await frames(45)
	check("pause_freezes_grace_and_world", app.phase == "paused" and snapshot == [app.elapsed, app.chase.front_x, app.chase.grace_remaining, app.player.position])
	key(KEY_R, true)
	await frames(2)
	key(KEY_R, false)
	check("real_r_resets_from_pause", app.phase == "ready" and not paused and app.elapsed == 0.0 and app.chase.front_x == -544.0 and app.chase.grace_remaining == 2.0)
	Input.action_press("jump")
	await frames(1)
	Input.action_release("jump")
	await frames(420)
	check("real_standing_run_gets_caught", app.phase == "failed" and app.failure_reason == "caught" and failures == 1, app.elapsed)
	var failure_time: float = app.elapsed
	var failure_front: float = app.chase.front_x
	await frames(30)
	check("failure_stops_clock_and_front", app.elapsed == failure_time and app.chase.front_x == failure_front and not app.player.is_physics_processing())
	app.restart_challenge()
	await frames(5)
	check("failure_replay_is_clean", app.phase == "ready" and app.deaths == 0 and app.failure_reason == "" and app.furthest_ratio == 0.0 and not app.player.dead and app.player.position.x == 96.0)
	var passed := checks.all(func(c): return c.passed)
	var file := FileAccess.open("res://reports/v0.2/prototype-flow-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"suite": "v0.2-real-input-prototype", "checks": checks, "passed": passed}, "\t"))
	file.close()
	app.free()
	OS.delay_msec(150)
	await process_frame
	quit(0 if passed else 1)
