extends SceneTree

var checks: Array[Dictionary] = []
var app: Node2D
var trace: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame

func check(label: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"check": label, "passed": passed, "detail": detail})
	print(label, ": ", passed, " ", detail)

func clear_input() -> void:
	for action in ["move_left", "move_right", "jump", "restart", "pause", "confirm"]:
		Input.action_release(action)

func key_event(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)

func _run() -> void:
	app = load("res://scenes/levels/level_01.tscn").instantiate()
	root.add_child(app)
	await frames(10)
	check("menu_on_launch", app.phase == "menu" and app.ui.overlay.visible)
	app.ui.time_trial_requested.emit()
	await frames(15)
	check("wait_for_first_input", app.phase == "ready" and app.elapsed == 0.0)
	Input.action_press("move_right")
	await frames(30)
	Input.action_release("move_right")
	check("first_input_starts_timer", app.phase == "running" and app.elapsed >= 0.49, app.elapsed)
	var before_pause: float = app.elapsed
	var before_position: Vector2 = app.player.position
	app.ui.resume_requested.emit()
	await frames(45)
	check("pause_freezes_time_and_world", app.phase == "paused" and app.elapsed == before_pause and app.player.position == before_position)
	app.ui.resume_requested.emit()
	await frames(6)
	check("resume", app.phase == "running" and app.elapsed > before_pause)
	# Trigger the real spike Area2D and test the full recovery flow.
	app.player.reset_at(Vector2(622, 433))
	await frames(4)
	var was_recovering: bool = app.phase == "recovering"
	var elapsed_at_death: float = app.elapsed
	await frames(22)
	check("hazard_once_and_recovery", was_recovering and app.phase == "running" and app.deaths == 1 and not app.player.dead)
	check("death_recovery_counted", app.elapsed > elapsed_at_death and app.player.position.x < 110.0)
	# Restart through the same signal as the UI button.
	app.ui.restart_requested.emit()
	await frames(5)
	check("manual_restart_resets_round", app.phase == "ready" and app.elapsed == 0.0 and app.deaths == 0)
	Input.action_press("move_right")
	await frames(2)
	Input.action_release("move_right")
	# Same-frame finish request and death: the deferred finish must lose.
	app._on_goal(app.player)
	app.player.die("spike")
	await frames(2)
	check("death_wins_same_frame", app.phase == "recovering" and app.best_seconds < 0)
	await frames(20)
	app.player.reset_at(Vector2(app.course.finish_x, 430))
	await frames(5)
	check("real_goal_finishes", app.phase == "finished" and app.best_seconds > 0)
	var finished_time: float = app.elapsed
	var best: float = app.best_seconds
	app.course.goal_reached.emit(app.player)
	await frames(20)
	check("finish_once_and_stop_clock", app.phase == "finished" and app.elapsed == finished_time and app.best_seconds == best)
	app.ui.restart_requested.emit()
	await frames(5)
	check("replay_preserves_best", app.phase == "ready" and app.best_seconds == best and app.deaths == 0)
	app.toggle_pause()
	app.ui.menu_requested.emit()
	await frames(5)
	check("menu_from_pause", app.phase == "menu" and not paused and app.ui.overlay.visible)
	app.ui.lab_requested.emit()
	await frames(5)
	check("lab_entry", app.lab_mode and app.course.course_length == 2400.0)
	app.start_challenge(false)
	await frames(5)
	key_event(KEY_D, true)
	await frames(10)
	key_event(KEY_D, false)
	key_event(KEY_ESCAPE, true)
	await frames(2)
	key_event(KEY_ESCAPE, false)
	check("keyboard_escape_pauses", app.phase == "paused")
	key_event(KEY_R, true)
	await frames(2)
	key_event(KEY_R, false)
	check("keyboard_r_restarts_from_pause", app.phase == "ready" and not paused and app.elapsed == 0.0)
	Input.action_press("move_right")
	await frames(2)
	Input.action_release("move_right")
	var stable_recovery := true
	for _i in 20:
		app.player.reset_at(Vector2(622, 433))
		await frames(3)
		await frames(20)
		stable_recovery = stable_recovery and app.phase == "running" and not app.player.dead and app.player.position.x < 110.0
	check("20_integrated_recoveries", stable_recovery and app.deaths == 20, app.deaths)
	clear_input()
	app.start_challenge(false)
	await frames(5)
	# Real no-teleport route traversal driven by ordinary movement/jump input.
	var jump_hold := 0
	var wall_jumps := 0
	var last_x := 0.0
	var stuck_frames := 0
	app.player.action_triggered.connect(func(action):
		if action == "wall_jump":
			trace.append({"event":action,"position":str(app.player.position),"time":app.elapsed}))
	Input.action_press("move_right")
	for step in 7200:
		var p: CharacterBody2D = app.player
		if step % 60 == 0:
			trace.append({"frame":step,"x":p.position.x,"y":p.position.y,"phase":app.phase,"state":p.state})
		if app.phase == "finished" or app.deaths > 0:
			break
		if absf(p.position.x - last_x) < 0.1:
			stuck_frames += 1
		else:
			stuck_frames = 0
		last_x = p.position.x
		if stuck_frames > 240:
			break
		if jump_hold > 0:
			jump_hold -= 1
			if jump_hold == 0:
				Input.action_release("jump")
		var wall_side: float = signf(p.get_wall_normal().x) if p.is_on_wall() else 0.0
		if p.is_on_wall() and not p.is_on_floor() and p._spent_wall_side != wall_side:
			if Input.is_action_pressed("jump"):
				Input.action_release("jump")
				jump_hold = 0
			else:
				Input.action_press("jump")
				jump_hold = 25
				wall_jumps += 1
		elif p.is_on_floor() and not Input.is_action_pressed("jump"):
			var needs_jump := false
			for gap in app.course.gaps:
				if p.position.x >= gap.position.x - 44 and p.position.x < gap.position.x:
					needs_jump = true
			for spike in app.course.spikes:
				if p.position.x >= spike.position.x - 54 and p.position.x < spike.end.x:
					needs_jump = true
			for wall in app.course.walls:
				if p.position.x >= wall.position.x - 76 and p.position.x < wall.position.x:
					needs_jump = true
			if needs_jump:
				Input.action_press("jump")
				jump_hold = 25
		await frames(1)
	clear_input()
	check("full_route_no_teleport", app.phase == "finished" and app.deaths == 0, {"x":app.player.position.x,"phase":app.phase,"deaths":app.deaths,"seconds":app.elapsed})
	check("route_wall_jumps_required", wall_jumps >= 2, wall_jumps)
	check("route_duration_45_90", app.phase == "finished" and app.elapsed >= 45.0 and app.elapsed <= 90.0, app.elapsed)
	var success := checks.all(func(c): return c.passed)
	var report := {"suite":"v0.1-regression-in-v0.2","godot":Engine.get_version_info().string,"checks":checks,"route_trace":trace,"passed":success}
	DirAccess.make_dir_recursive_absolute("res://reports/v0.2")
	var file := FileAccess.open("res://reports/v0.2/time-trial-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	app.queue_free()
	await process_frame
	app = null
	# The fixed-fps suite runs faster than the audio thread. Let pending voice
	# releases finish before shutting down the process and reporting leaks.
	OS.delay_msec(150)
	await process_frame
	quit(0 if success else 1)

