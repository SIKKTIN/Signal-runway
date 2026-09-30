extends SceneTree
const Generator = preload("res://scripts/level/endless_generator.gd")
const Driver = preload("res://reports/v0.4/input_driver.gd")
var app: Node2D
var checks: Array[Dictionary] = []
var route: Dictionary = {}
func _initialize() -> void:
	call_deferred("run")
func frames(n: int) -> void:
	for _i in n:
		await physics_frame
		await process_frame
func check(label: String, passed: bool) -> void:
	checks.append({"check": label, "passed": passed})
	print(label, ": ", passed)
func run() -> void:
	var structural := true
	var replay := true
	var diversity: Dictionary = {}
	for seed_value in range(1, 101):
		var a := Generator.new()
		var b := Generator.new()
		a.reset(seed_value)
		b.reset(seed_value)
		var last := ""
		var previous_relay := -1
		for index in 200:
			var e: Dictionary = a.next()
			replay = replay and e == b.next()
			structural = structural and e.template_id != last and e.length == 1280 and e.difficulty <= maxi(1, e.stage)
			if e.category == "relay":
				structural = structural and (previous_relay < 0 or index - previous_relay in [5, 6])
				previous_relay = index
			last = e.template_id
			diversity[last] = true
	check("100_seeds_200_chunks_structure", structural)
	check("same_seed_prefix_reproducible", replay)
	check("six_templates_selected", diversity.size() == 6)
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await frames(3)
	app.start_endless(404)
	var driver := Driver.new()
	var maximum := 0
	var rebase_gap := 0.0
	var previous_offset := 0.0
	var previous_gap: float = app.chase.gap_px
	for _i in 10000:
		if app.phase == "failed" or app.run_distance >= 40000:
			break
		driver.step(app)
		await frames(1)
		maximum = maxi(maximum, app.course.chunks.size())
		if app.course.total_offset != previous_offset:
			rebase_gap = maxf(rebase_gap, absf(app.chase.gap_px - previous_gap))
			previous_offset = app.course.total_offset
		previous_gap = app.chase.gap_px
	route = {"seed": 404, "phase": app.phase, "distance": app.run_distance, "seconds": app.elapsed, "nodes": app.relay_count, "wall_jumps": driver.wall_jumps, "gap": app.chase.gap_px, "active_max": maximum, "rebase_gap_delta": rebase_gap, "lifecycle": app.course.lifecycle_state(), "method": "ordinary jump actions, no teleport/controller freeze/immunity"}
	check("ordinary_40k_streaming_route", app.phase == "running" and app.run_distance >= 40000)
	check("recycle_and_rebase_preserve_gap", app.course.total_offset >= 25600 and rebase_gap < 10 and maximum < 12 and app.course.generator.index > 30)
	check("active_holders_match_chunks", app.course.lifecycle_state().holders == app.course.chunks.size())
	app.toggle_pause()
	var before: Array = [app.elapsed, app.player.position, app.course.generator.index, app.course.chunks.size(), app.chase.front_x]
	await frames(12)
	check("pause_stops_streaming", before == [app.elapsed, app.player.position, app.course.generator.index, app.course.chunks.size(), app.chase.front_x])
	app.restart_challenge()
	await frames(2)
	check("same_seed_restart_clears_stream_offset", app.run_seed == 404 and app.course.total_offset == 0 and app.course.generator.index == 3 and app.course.chunks[0].template_id == "safe_a" and app.relay_count == 0)
	Input.action_release("jump")
	var passed := checks.all(func(c): return c.passed)
	var f := FileAccess.open("res://reports/v0.4/stream-results.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed": passed, "checks": checks, "route": route, "scope": "D six-template production stream; 100-seed structure plus actual 40k route, not full final library/long-duration evidence"}, "\t"))
	f.close()
	app.free()
	OS.delay_msec(200)
	await frames(2)
	quit(0 if passed else 1)
