extends SceneTree
const Record = preload("res://scripts/level/endless_record.gd")
var app: Node2D
var checks: Array[Dictionary] = []
var path := "user://codex_v04_score_%d.json" % OS.get_process_id()
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
	var record := Record.new()
	record.load_from(path)
	check("missing_record_defaults_zero", record.best.score == 0 and record.status == "missing")
	check("first_record_saved", record.consider(path, 1500, 12000, 3, 404) and record.status == "saved")
	var reread := Record.new()
	reread.load_from(path)
	check("new_instance_reads_record", reread.best.score == 1500 and reread.best.seed == 404 and reread.status == "loaded")
	check("lower_score_does_not_overwrite", not reread.consider(path, 1400, 13000, 1, 405))
	check("atomic_second_record", reread.consider(path, 1600, 13000, 3, 405) and reread.status == "saved" and not FileAccess.file_exists(path + ".bak"))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("broken {")
	file.close()
	record.load_from(path)
	check("corrupt_record_defaults_visible_status", record.best.score == 0 and record.status == "invalid")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema": 1, "best": {"score": -5, "distance": 0, "nodes": 0, "seed": 1}}))
	file.close()
	record.load_from(path)
	check("invalid_negative_record_rejected", record.status == "invalid" and record.best.score == 0)
	app = load("res://scenes/main/main.tscn").instantiate()
	app.record_path = path
	root.add_child(app)
	await frames(3)
	app.start_endless(404)
	await frames(8)
	check("distance_score_real_motion", app.run_distance > 0 and app.run_score == int(floor(app.run_distance / 10)) and app.relay_count == 0)
	app.run_distance = 12000
	app.relay_count = 3
	app._update_ui()
	check("explicit_12k_three_nodes_equals_1500", app.run_score == 1500)
	await frames(2)
	check("earlier_position_does_not_recount_distance", app.run_score == 1500 and app.run_distance == 12000)
	app.restart_challenge()
	await frames(3)
	check("r_same_seed_clears_distance_nodes", app.run_seed == 404 and app.relay_count == 0 and app.run_distance < 10)
	var node_id: String = app.course.relays[0].id if not app.course.relays.is_empty() else ""
	# Initial buffer may not include first relay; explicitly request its chunk.
	if node_id.is_empty():
		app.course.update_stream(4000, -544)
		node_id = app.course.relays[0].id
	var score_before: int = app.run_score
	app._queue_relay(node_id)
	app._queue_relay(node_id)
	await frames(2)
	check("unique_node_adds_once_100_and_delay", app.relay_count == 1 and app.run_score >= score_before + 100 and app.relay_delay_remaining > 0)
	app._queue_relay(node_id)
	app._queue_relay("unknown")
	await frames(2)
	check("duplicate_unknown_no_score_reward", app.relay_count == 1)
	app.toggle_pause()
	var before: Array = [app.run_distance, app.run_score, app.elapsed, app.relay_delay_remaining]
	await frames(12)
	check("pause_all_score_and_delay_frozen", before == [app.run_distance, app.run_score, app.elapsed, app.relay_delay_remaining])
	app.toggle_pause()
	app.run_distance = 12000
	app.relay_count = 3
	app._update_ui()
	app.player.die("spike")
	app._queue_relay("late")
	await frames(2)
	check("single_failure_saves_final_score", app.phase == "failed" and app.run_score == 1500 and app.best_score == 1500 and app.new_record)
	app.reload_endless_record()
	check("root_record_reload_persists", app.best_score == 1500)
	app.restart_challenge()
	await frames(2)
	check("record_survives_same_seed_restart", app.best_score == 1500 and app.run_seed == 404 and not app.new_record)
	app.start_endless(405)
	await frames(2)
	check("new_seed_new_round_preserves_record", app.run_seed == 405 and app.relay_count == 0 and app.best_score == 1500)
	app.start_challenge(false, "time_trial", "relay_station")
	await frames(2)
	check("fixed_mode_manual_and_scores_isolated", not app.player.auto_run and app.best_seconds == -1 and app.best_score == 1500)
	var passed := checks.all(func(c): return c.passed)
	file = FileAccess.open("res://reports/v0.4/score-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "scope": "Record tests use unique disposable user file; score budgets/direct node/death candidates explicitly are fixtures, not normal routes."}, "\t"))
	file.close()
	app.free()
	DirAccess.remove_absolute(path)
	OS.delay_msec(200)
	await frames(2)
	quit(0 if passed else 1)
