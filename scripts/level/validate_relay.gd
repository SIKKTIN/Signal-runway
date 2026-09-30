extends SceneTree
var app: Node2D
var checks: Array[Dictionary] = []
var routes: Array[Dictionary] = []
func _initialize() -> void:
	call_deferred("run")
func frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame
func check(label: String, passed: bool) -> void:
	checks.append({"check": label, "passed": passed})
	print(label, ": ", passed)
func route(risk: bool) -> Dictionary:
	Input.action_release("jump")
	Input.action_release("move_right")
	app.start_challenge(false, "pursuit", "relay_station")
	await frames(4)
	var held := 0
	var merge_time := -1.0
	var merge_gap := 0.0
	var jumps := 0
	Input.action_press("move_right")
	for step in 1400:
		if app.phase in ["failed", "finished"]:
			break
		var p: CharacterBody2D = app.player
		if p.position.x >= 1280 and merge_time < 0.0:
			merge_time = app.elapsed
			merge_gap = app.chase.gap_px
		if held > 0:
			held -= 1
			if held == 0:
				Input.action_release("jump")
		if p.is_on_floor() and not Input.is_action_pressed("jump"):
			var jump := false
			if risk:
				jump = (p.position.x >= 498 and p.position.x < 544 and p.position.y > 410) or (p.position.x >= 677 and p.position.x < 724 and p.position.y < 410)
			for gap in app.course.gaps:
				if p.position.x >= gap.position.x - 44 and p.position.x < gap.position.x and p.position.y > 410:
					jump = true
			if jump:
				Input.action_press("jump")
				held = 25
				jumps += 1
		await frames(1)
	Input.action_release("move_right")
	Input.action_release("jump")
	return {"risk": risk, "phase": app.phase, "seconds": app.elapsed, "count": app.relay_count, "merge_seconds": merge_time, "merge_gap": merge_gap, "jumps": jumps}
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/v0.3"))
	var chase: Node = load("res://scripts/level/chase_controller.gd").new()
	root.add_child(chase)
	chase.reset(96)
	chase.set_enabled(true)
	chase.add_relay_delay(0.9)
	chase.advance(2.5, 1000)
	check("grace_before_relay", is_equal_approx(chase.front_x, -544) and is_equal_approx(chase.relay_remaining, 0.4))
	chase.advance(0.7, 1000)
	check("large_delta_segmented", is_equal_approx(chase.front_x, -463) and is_zero_approx(chase.relay_remaining))
	chase.add_relay_delay(0.9)
	chase.add_relay_delay(0.9)
	check("distinct_nodes_accumulate", is_equal_approx(chase.relay_remaining, 1.8))
	chase.reset(96)
	check("reset_clears_delay", chase.relay_remaining == 0)
	chase.free()
	app = load("res://scenes/main/main.tscn").instantiate()
	app.relay_prototype = true
	root.add_child(app)
	await frames(4)
	routes.append(await route(false))
	routes.append(await route(true))
	for r in routes:
		print("ROUTE ", r)
	check("safe_route_no_relay_completes", routes[0].phase == "finished" and routes[0].count == 0)
	check("risk_route_collects_and_completes", routes[1].phase == "finished" and routes[1].count == 1)
	check("relay_net_gain", routes[1].merge_gap > routes[0].merge_gap + 100 and routes[1].merge_seconds - routes[0].merge_seconds < 0.9)
	app.start_challenge(false, "pursuit", "relay_station")
	app._queue_relay("relay_one")
	app._queue_relay("relay_one")
	await frames(1)
	check("duplicate_contact_once", app.relay_count == 1 and app.chase.relay_remaining > 0.89)
	app.toggle_pause()
	var remaining: float = app.chase.relay_remaining
	await frames(15)
	check("pause_freezes_delay", app.chase.relay_remaining == remaining)
	app.restart_challenge()
	check("restart_resets_node_and_delay", app.relay_count == 0 and app.chase.relay_remaining == 0 and not app.course.relays[0].activated)
	app._queue_relay("relay_one")
	app.player.die("spike")
	await frames(2)
	check("failure_beats_relay", app.phase == "failed" and app.relay_count == 0)
	app.start_challenge(false, "time_trial", "relay_station")
	app._queue_relay("relay_one")
	await frames(1)
	check("trial_records_without_delay", app.relay_count == 1 and app.chase.relay_remaining == 0)
	app.player.die("spike")
	await frames(20)
	app._queue_relay("relay_one")
	await frames(1)
	check("trial_recovery_does_not_repeat", app.relay_count == 1)
	var passed := checks.all(func(c): return c.passed)
	var file := FileAccess.open("res://reports/v0.3/prototype-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "routes": routes, "scope": "Two routes use direction/jump input; state edge checks use fixtures."}, "\t"))
	file.close()
	app.free()
	app = null
	OS.delay_msec(200)
	await frames(2)
	quit(0 if passed else 1)
