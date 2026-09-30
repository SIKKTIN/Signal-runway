extends SceneTree
var app: Node2D
var routes: Array[Dictionary] = []
func _initialize() -> void:
	call_deferred("run")
func frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame
func traverse(first: bool, second: bool, selected_mode: String = "pursuit") -> Dictionary:
	Input.action_release("jump")
	Input.action_release("move_right")
	app.start_challenge(false, selected_mode, "relay_station")
	await frames(4)
	var held := 0
	var wall_jumps := 0
	var minimum := 1.0e9
	var merges: Array[Dictionary] = []
	var section_min: Array[float] = [1.0e9, 1.0e9, 1.0e9, 1.0e9, 1.0e9]
	Input.action_press("move_right")
	for step in 6000:
		if app.phase in ["failed", "finished"]:
			break
		var p: CharacterBody2D = app.player
		minimum = minf(minimum, app.chase.gap_px)
		var section: int = app.course.section_at(p.position.x)
		section_min[section] = minf(section_min[section], app.chase.gap_px)
		for merge_x in [2940, 8960]:
			if p.position.x >= merge_x and merges.size() < (1 if merge_x == 2940 else 2):
				merges.append({"x": merge_x, "seconds": app.elapsed, "gap": app.chase.gap_px})
		if held > 0:
			held -= 1
			if held == 0:
				Input.action_release("jump")
		var side: float = signf(p.get_wall_normal().x) if p.is_on_wall() else 0.0
		if second and p.is_on_wall() and not p.is_on_floor() and p._spent_wall_side != side:
			if Input.is_action_pressed("jump"):
				Input.action_release("jump")
				held = 0
			else:
				Input.action_press("jump")
				held = 25
				wall_jumps += 1
		elif p.is_on_floor() and not Input.is_action_pressed("jump"):
			var jump := false
			if first:
				jump = (p.position.x >= 2158 and p.position.x < 2204 and p.position.y > 410) or (p.position.x >= 2337 and p.position.x < 2384 and p.position.y < 410)
			if second:
				jump = jump or (p.position.x >= 8185 and p.position.x < 8240 and p.position.y > 410) or (p.position.x >= 8320 and p.position.x < 8360 and p.position.y < 410)
			if p.position.y > 410:
				for gap in app.course.gaps:
					if p.position.x >= gap.position.x - 44 and p.position.x < gap.position.x:
						jump = true
				for spike in app.course.spikes:
					if p.position.x >= spike.position.x - 54 and p.position.x < spike.end.x:
						jump = true
			if jump:
				Input.action_press("jump")
				held = 25
		await frames(1)
	Input.action_release("move_right")
	Input.action_release("jump")
	var expected := int(first) + int(second)
	var row := {"first": first, "second": second, "mode": selected_mode, "phase": app.phase, "reason": app.failure_reason, "seconds": app.elapsed, "relay_count": app.relay_count, "wall_jumps": wall_jumps, "minimum_gap": minimum, "section_minimum": section_min, "merges": merges, "passed": app.phase == "finished" and app.relay_count == expected and (not second or wall_jumps > 0)}
	print("ROUTE ", row)
	return row
func run() -> void:
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await frames(4)
	for first in [false, true]:
		for second in [false, true]:
			routes.append(await traverse(first, second))
	routes.append(await traverse(true, true, "time_trial"))
	var passed := routes.all(func(r): return r.passed)
	var file := FileAccess.open("res://reports/v0.3/route-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "routes": routes, "scope": "Ordinary input, no teleport, no controller freeze or immunity."}, "\t"))
	file.close()
	app.free()
	app = null
	OS.delay_msec(200)
	await frames(2)
	quit(0 if passed else 1)
