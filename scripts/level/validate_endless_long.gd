extends SceneTree
const Driver = preload("res://reports/v0.4/input_driver.gd")
var app: Node2D
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var seconds := 600
	var take_nodes := true
	var seed_value := 404
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("seconds="):
			seconds = int(arg.trim_prefix("seconds="))
		if arg.begins_with("seed="):
			seed_value = int(arg.trim_prefix("seed="))
		if arg == "skip":
			take_nodes = false
	app = load("res://scenes/main/main.tscn").instantiate()
	app.record_path = "user://codex_v04_long_%d.json" % OS.get_process_id()
	root.add_child(app)
	await process_frame
	app.start_endless(seed_value)
	var driver := Driver.new()
	driver.take_relays = take_nodes
	var samples: Array[Dictionary] = []
	var max_chunks := 0
	for step in seconds * 60:
		if app.phase == "failed":
			break
		driver.step(app)
		await physics_frame
		await process_frame
		max_chunks = maxi(max_chunks, app.course.chunks.size())
		if step % 1800 == 0:
			var sample := {"seconds": app.elapsed, "distance": app.run_distance, "gap": app.chase.gap_px, "speed": app.chase.speed, "score": app.run_score, "nodes": app.relay_count, "memory": Performance.get_monitor(Performance.MEMORY_STATIC), "objects": Performance.get_monitor(Performance.OBJECT_COUNT), "chunks": app.course.chunks.size(), "offset": app.course.total_offset}
			samples.append(sample)
			print("LONG ", JSON.stringify(sample))
	var result := {"seed": seed_value, "take_relays": take_nodes, "target_seconds": seconds, "seconds": app.elapsed, "phase": app.phase, "failure": app.failure_reason, "distance": app.run_distance, "score": app.run_score, "nodes": app.relay_count, "gap": app.chase.gap_px, "wall_jumps": driver.wall_jumps, "max_chunks": max_chunks, "lifecycle": app.course.lifecycle_state(), "samples": samples, "passed": (app.phase == "running" and app.elapsed >= seconds - 0.1) if take_nodes else (app.phase == "failed" and app.failure_reason == "caught"), "scope": "ordinary jump-only automatic-run route; no invulnerability, teleport, controller freeze or special RNG"}
	Input.action_release("jump")
	var file := FileAccess.open("res://reports/v0.4/long-%d-%d-%s-results.json" % [seed_value, seconds, "nodes" if take_nodes else "skip"], FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	var verification_record: String = app.record_path
	app.free()
	if FileAccess.file_exists(verification_record):
		DirAccess.remove_absolute(verification_record)
	OS.delay_msec(200)
	await process_frame
	quit(0 if result.passed else 1)
