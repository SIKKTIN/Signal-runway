extends SceneTree
var app: Node2D
var checks: Array[Dictionary] = []
var route: Dictionary = {}
func _initialize() -> void:
	call_deferred("run")
func frames(n: int) -> void:
	for _i in n:
		await physics_frame
		await process_frame
func check(name: String, passed: bool) -> void:
	checks.append({"check": name, "passed": passed})
	print(name, ": ", passed)
func run() -> void:
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	app.endless_prototype = true
	await frames(4)
	app.start_endless(404)
	await frames(5)
	check("auto_start_without_direction", app.is_endless() and app.phase == "running" and app.player.position.x > 96 and app.player.auto_run)
	check("no_goal_area", not app.course.has_node("Goal"))
	app._on_goal(app.player)
	await frames(2)
	check("goal_ignored_in_endless", app.phase == "running")
	var held := 0
	var wall_jumps := 0
	for _i in 700:
		if app.phase == "failed" or app.player.position.x > 2100:
			break
		var p: CharacterBody2D = app.player
		if held > 0:
			held -= 1
			if held == 0:
				Input.action_release("jump")
		if p.is_on_wall() and not p.is_on_floor() and p._spent_wall_side != signf(p.get_wall_normal().x):
			if Input.is_action_pressed("jump"):
				Input.action_release("jump")
				held = 0
			else:
				Input.action_press("jump")
				held = 25
				wall_jumps += 1
		elif p.is_on_floor() and p.position.x >= 1144 and p.position.x < 1200 and not Input.is_action_pressed("jump"):
			Input.action_press("jump")
			held = 25
		await frames(1)
	Input.action_release("jump")
	route = {"phase": app.phase, "x": app.player.position.x, "seconds": app.elapsed, "wall_jumps": wall_jumps, "gap": app.chase.gap_px, "method": "jump-only ordinary input, automatic run, no teleport/controller freeze"}
	check("ordinary_jump_wall_jump_auto_resume", app.phase == "running" and app.player.position.x > 2100 and wall_jumps == 1)
	app.toggle_pause()
	var before: Array = [app.elapsed, app.player.position, app.chase.front_x, app.relay_delay_remaining]
	await frames(20)
	check("pause_freezes_auto_run_and_threat", before == [app.elapsed, app.player.position, app.chase.front_x, app.relay_delay_remaining])
	app.restart_challenge()
	await frames(3)
	check("paused_r_same_seed_clean_round", app.run_seed == 404 and app.phase == "running" and not paused and app.player.position.x < 120 and app.run_score < 4)
	app.elapsed = 90
	await frames(2)
	check("stage_speed_cap_282", app.difficulty_stage == 3 and app.chase.speed == 282)
	app.player.die("spike")
	await frames(2)
	check("endless_death_single_result", app.phase == "failed" and app.failure_reason == "spike" and app.deaths == 1)
	app._queue_relay("late")
	await frames(2)
	check("failed_rejects_reward", app.relay_count == 0)
	app.start_challenge(false, "pursuit", "relay_station")
	await frames(3)
	check("fixed_station_manual_idle_compatible", app.phase == "ready" and not app.player.auto_run and app.course.has_node("Goal") and app.chase.speed == 270)
	var passed := checks.all(func(c): return c.passed)
	var f := FileAccess.open("res://reports/v0.4/prototype-results.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "route": route, "passed": passed, "scope": "A greybox; stage/death checks are explicit state fixtures; no final random route/score persistence claims"}, "\t"))
	f.close()
	app.free()
	OS.delay_msec(200)
	await frames(2)
	quit(0 if passed else 1)
