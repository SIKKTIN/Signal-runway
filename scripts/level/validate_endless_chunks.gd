extends SceneTree
var app: Node2D
var routes: Array[Dictionary] = []
const Library = preload("res://scripts/level/endless_library.gd")
func _initialize() -> void:
	call_deferred("run")
func frames(n: int) -> void:
	for _i in n:
		await physics_frame
		await process_frame
func traverse(first: String, second: String, risk: bool) -> Dictionary:
	app.endless_prototype = false
	app.endless_test_sequence.assign(["safe_a", first, second, "safe_a"])
	app.start_endless(404)
	var held := 0
	var walls := 0
	var seam_states: Array = []
	for _i in 1400:
		if app.phase == "failed" or app.player.position.x > 4352:
			break
		var p: CharacterBody2D = app.player
		if seam_states.size() < 2 and p.position.x >= (2560 if seam_states.is_empty() else 3840):
			seam_states.append({"x": p.position.x, "y": p.position.y, "vx": p.velocity.x, "grounded": p.is_on_floor()})
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
				walls += 1
		elif p.is_on_floor() and not Input.is_action_pressed("jump"):
			var jump := false
			if risk:
				for chunk in app.course.chunks:
					if chunk.category == "relay":
						var x: float = p.position.x - chunk.origin
						if chunk.template_id == "relay_b":
							jump = jump or (x >= 185 and x < 240 and p.position.y > 410) or (x >= 320 and x < 360 and p.position.y < 410)
						else:
							jump = jump or (x >= 274 and x < 320 and p.position.y > 410) or (x >= 453 and x < 500 and p.position.y < 410)
			if p.position.y > 410:
				for gap in app.course.gaps:
					jump = jump or (p.position.x >= gap.position.x - 44 and p.position.x < gap.position.x)
				for spike in app.course.spikes:
					jump = jump or (p.position.x >= spike.position.x - 54 and p.position.x < spike.end.x)
				for wall in app.course.walls:
					jump = jump or (wall.end.y >= 430 and p.position.x >= wall.position.x - 56 and p.position.x < wall.position.x)
			if jump:
				Input.action_press("jump")
				held = 25
		await frames(1)
	Input.action_release("jump")
	var expected := (int(Library.definition(first).category == "relay") + int(Library.definition(second).category == "relay")) if risk else 0
	var r := {"first": first, "second": second, "risk": risk, "phase": app.phase, "x": app.player.position.x, "y": app.player.position.y, "seconds": app.elapsed, "nodes": app.relay_count, "wall_jumps": walls, "seams": seam_states, "passed": app.phase == "running" and app.player.position.x > 4352 and app.relay_count == expected and seam_states.size() == 2 and seam_states.all(func(a): return a.grounded and absf(a.y - 433) < 1)}
	if not r.passed:
		print("FAILED CHUNKS ", r)
	return r
func run() -> void:
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await frames(3)
	var full := OS.get_cmdline_user_args().has("--full")
	var templates: Array[String] = Library.ids() if full else Library.ids().slice(0, 6)
	for a in templates:
		for b in templates:
			routes.append(await traverse(a, b, true))
	routes.append(await traverse("relay_a", "relay_a", false))
	if full:
		for pair in [["relay_a", "relay_b"], ["relay_b", "relay_a"], ["relay_b", "relay_b"]]:
			routes.append(await traverse(pair[0], pair[1], false))
	var passed := routes.all(func(r): return r.passed)
	var f := FileAccess.open("res://reports/v0.4/" + ("full-chunk-results.json" if full else "chunk-results.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed": passed, "templates": templates.size(), "routes": routes, "scope": "All ordered neutral-seam combinations; ordinary jump-only auto-run, plus low relay routes; no teleport or disabled collision"}, "\t"))
	print("CHUNK SUMMARY ", templates.size(), " templates / ", routes.size(), " routes: ", passed)
	f.close()
	app.free()
	OS.delay_msec(200)
	await frames(2)
	quit(0 if passed else 1)
