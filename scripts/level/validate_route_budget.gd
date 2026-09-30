extends SceneTree
var app: Node2D
var routes: Array[Dictionary] = []
func _initialize() -> void:
	call_deferred("_run")
func frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame
func clear_input() -> void:
	for action in ["move_right", "move_left", "jump"]:
		Input.action_release(action)
func traverse(speed: float, stop_x: float = -1.0) -> Dictionary:
	clear_input()
	app.chase_speed = speed
	app.start_challenge(false, "pursuit")
	await frames(5)
	var trace: Array[Dictionary] = []
	var sections: Array[Dictionary] = []
	for i in 4:
		sections.append({"section": i + 1, "entry_gap": -1.0, "exit_gap": -1.0, "min_gap": 1.0e9})
	var jump_hold := 0
	var stopped := false
	var stop_remaining := 0
	var wall_jumps := 0
	var min_active_gap := 1.0e9
	Input.action_press("move_right")
	for step in 7200:
		var p: CharacterBody2D = app.player
		if app.phase in ["finished", "failed"]:
			break
		if app.chase.enabled and app.chase.grace_remaining <= 0.0:
			min_active_gap = minf(min_active_gap, app.chase.gap_px)
			var section: int = app.course.section_at(p.position.x)
			if sections[section].entry_gap < 0.0:
				sections[section].entry_gap = app.chase.gap_px
			sections[section].exit_gap = app.chase.gap_px
			sections[section].min_gap = minf(sections[section].min_gap, app.chase.gap_px)
		if step % 60 == 0:
			trace.append({"frame": step, "x": p.position.x, "gap": app.chase.gap_px, "level": app.chase.warning_level, "seconds": app.elapsed})
		if not stopped and stop_x >= 0.0 and p.position.x >= stop_x and p.is_on_floor():
			stopped = true
			stop_remaining = 120
			Input.action_release("move_right")
			Input.action_release("jump")
			jump_hold = 0
			trace.append({"event": "two_second_stop", "x": p.position.x, "gap": app.chase.gap_px, "seconds": app.elapsed})
		if stop_remaining > 0:
			stop_remaining -= 1
			await frames(1)
			if stop_remaining == 0:
				Input.action_press("move_right")
			continue
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
	var row := {"speed": speed, "stop_x": stop_x, "stopped": stopped, "phase": app.phase, "reason": app.failure_reason, "seconds": app.elapsed, "wall_jumps": wall_jumps, "min_active_gap": min_active_gap, "finish_gap": app.chase.gap_px, "sections": sections, "trace": trace, "passed": app.phase == "finished" and wall_jumps >= 2 and (stop_x < 0.0 or stopped)}
	print("ROUTE ", speed, " stop=", stop_x, " ", app.phase, " time=", app.elapsed, " min_gap=", min_active_gap)
	return row
func _run() -> void:
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await frames(5)
	for speed in [250.0, 260.0, 270.0]:
		routes.append(await traverse(speed))
	for stop_x in [4200.0, 7700.0]:
		routes.append(await traverse(270.0, stop_x))
	var passed := routes.all(func(r): return r.passed)
	var file := FileAccess.open("res://reports/v0.2/route-budget-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"suite": "v0.2-route-budget", "godot": Engine.get_version_info().string, "routes": routes, "passed": passed}, "\t"))
	file.close()
	app.free()
	OS.delay_msec(150)
	await process_frame
	quit(0 if passed else 1)
