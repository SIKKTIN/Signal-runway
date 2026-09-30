extends SceneTree
var checks: Array[Dictionary] = []
var app: Node2D
var failures := 0
var finishes := 0
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
	for action in ["move_right", "move_left", "jump", "pause", "restart", "confirm"]:
		Input.action_release(action)
func key(keycode: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	Input.parse_input_event(event)
func begin(mode: String = "pursuit") -> void:
	clear_input()
	app.start_challenge(false, mode)
	await frames(5)
	Input.action_press("move_right")
	await frames(12)
	Input.action_release("move_right")
	await frames(8)
func _run() -> void:
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	app.run_failed.connect(func(_r, _t, _p): failures += 1)
	app.run_finished.connect(func(_t, _d, _b): finishes += 1)
	await frames(5)
	check("main_menu_default_pursuit", app.phase == "menu" and app.mode == "pursuit")
	await begin()
	check("presentation_bound", app.world.has_node("ChaseVisual") and app.world.get_node("ChaseVisual").presentation_state().mode == "pursuit")
	await frames(125)
	check("real_front_uses_selected_speed", app.chase.speed == 270.0 and app.chase.front_x > -544.0 and app.phase == "running")
	var visual: Node = app.world.get_node("ChaseVisual")
	check("threat_loop_started", visual.presentation_state().loop_playing)
	key(KEY_ESCAPE, true)
	await frames(1)
	key(KEY_ESCAPE, false)
	var snapshot := [app.elapsed, app.chase.front_x, app.chase.grace_remaining, app.player.position]
	await frames(30)
	check("running_pause_freezes_everything", app.phase == "paused" and snapshot == [app.elapsed, app.chase.front_x, app.chase.grace_remaining, app.player.position])
	check("threat_loop_paused", visual.presentation_state().loop_paused)
	key(KEY_ESCAPE, true)
	await frames(1)
	key(KEY_ESCAPE, false)
	await frames(10)
	check("resume_restores_running_and_audio", app.phase == "running" and app.elapsed > snapshot[0] and not visual.presentation_state().loop_paused)
	app.toggle_pause()
	key(KEY_R, true)
	await frames(2)
	key(KEY_R, false)
	check("pause_r_resets_front_and_stats", not paused and app.phase == "ready" and app.elapsed == 0 and app.chase.front_x == -544.0 and app.furthest_ratio == 0 and not app.chase.enabled)
	check("restart_no_loop_or_warning", not app.world.get_node("ChaseVisual").presentation_state().loop_playing and app.chase.warning_level == "grace")
	await begin()
	app._on_goal(app.player)
	app._queue_failure("caught")
	app._queue_failure("fall")
	app.player.die("spike")
	await frames(3)
	check("same_frame_failure_priority", app.phase == "failed" and app.failure_reason == "spike" and failures == 1 and finishes == 0)
	check("failure_does_not_write_best", app.best_seconds == -1.0)
	var failure_time: float = app.elapsed
	var failure_front: float = app.chase.front_x
	app._on_goal(app.player)
	app._queue_failure("caught")
	await frames(10)
	check("repeated_result_is_ignored", failures == 1 and app.elapsed == failure_time and app.chase.front_x == failure_front)
	check("failure_stops_threat_loop", not app.world.get_node("ChaseVisual").presentation_state().loop_playing)
	await begin()
	app.player.die("spike")
	app.toggle_pause()
	await frames(3)
	check("pause_during_pending_failure_resolves", app.phase == "failed" and app.failure_reason == "spike" and not paused)
	await begin()
	app.toggle_pause()
	app.player.die("fall")
	await frames(3)
	check("late_contact_after_pause_resolves", app.phase == "failed" and app.failure_reason == "fall" and not paused)
	await begin()
	app._on_goal(app.player)
	app.toggle_pause()
	await frames(3)
	check("pending_goal_waits_during_pause", app.phase == "paused" and app._goal_pending)
	app.toggle_pause()
	await frames(3)
	check("pending_goal_resolves_on_resume", app.phase == "finished")
	await begin()
	app.toggle_pause()
	app._on_goal(app.player)
	await frames(3)
	check("late_goal_after_pause_is_retained", app.phase == "paused" and app._goal_pending)
	app.toggle_pause()
	await frames(3)
	check("late_goal_resolves_after_resume", app.phase == "finished")
	# Later fixtures compare event counts locally, since the pause/goal fixture
	# intentionally completed once.
	var before_competition_finishes := finishes
	var earlier_pursuit_best: float = app._best_by_mode.pursuit.seconds
	await begin()
	app.player.reset_at(Vector2(app.course.finish_x, 430))
	app.chase.front_x = app.course.finish_x + 20.0
	await frames(5)
	check("physical_caught_beats_real_goal", app.phase == "failed" and app.failure_reason == "caught" and finishes == before_competition_finishes)
	await begin()
	app.player.reset_at(Vector2(220, 700))
	await frames(4)
	check("physical_fall_is_round_failure", app.phase == "failed" and app.failure_reason == "fall")
	var stable := true
	for _i in 20:
		await begin()
		app.player.reset_at(Vector2(622, 433))
		await frames(4)
		stable = stable and app.phase == "failed" and app.failure_reason == "spike" and app.deaths == 1
		app.restart_challenge()
		await frames(4)
		stable = stable and app.phase == "ready" and app.elapsed == 0 and app.deaths == 0 and app.failure_reason == "" and app.chase.front_x == -544.0 and app.chase.grace_remaining == 2.0 and not app.player.dead
	check("20_real_hazard_failure_replays", stable)
	await begin("time_trial")
	check("time_trial_disables_pursuer", not app.chase.enabled and not app.world.get_node("ChaseVisual").presentation_state().hud_visible)
	app.toggle_pause()
	app.player.die("spike")
	await frames(3)
	check("legacy_late_contact_preserves_pause", app.phase == "paused" and app._previous_phase == "recovering" and app.deaths == 1)
	app.toggle_pause()
	await frames(22)
	check("legacy_late_contact_recovers_on_resume", app.phase == "running" and not app.player.dead)
	await begin("time_trial")
	app.player.reset_at(Vector2(622, 433))
	await frames(4)
	check("legacy_hazard_recovers", app.phase == "recovering" and app.deaths == 1)
	await frames(22)
	check("legacy_recovery_keeps_time", app.phase == "running" and app.elapsed > 0.5 and not app.player.dead)
	app.player.reset_at(Vector2(app.course.finish_x, 430))
	await frames(5)
	var trial_best: float = app.best_seconds
	check("trial_success_writes_only_trial_best", app.phase == "finished" and trial_best > 0 and app._best_by_mode.pursuit.seconds == earlier_pursuit_best)
	await begin("pursuit")
	check("pursuit_best_is_separate", app.best_seconds == earlier_pursuit_best)
	app.player.reset_at(Vector2(app.course.finish_x, 430))
	await frames(5)
	var pursuit_best: float = app.best_seconds
	check("pursuit_success_and_best", app.phase == "finished" and pursuit_best > 0 and app._best_by_mode.time_trial.seconds == trial_best)
	await begin("pursuit")
	app.player.reset_at(Vector2(622, 433))
	await frames(5)
	check("later_failure_preserves_success_best", app.phase == "failed" and app.best_seconds == pursuit_best)
	app.return_to_menu()
	await frames(5)
	check("menu_cleans_threat", app.phase == "menu" and not paused and not app.world.get_node("ChaseVisual").presentation_state().hud_visible and not app.world.get_node("ChaseVisual").presentation_state().loop_playing)
	app.ui.lab_requested.emit()
	await frames(5)
	check("lab_keeps_legacy_rules", app.lab_mode and app.mode == "time_trial" and not app.chase.enabled)
	clear_input()
	var passed := checks.all(func(c): return c.passed)
	var file := FileAccess.open("res://reports/v0.2/integration-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"suite": "v0.2-integrated-rules", "godot": Engine.get_version_info().string, "checks": checks, "passed": passed, "scope": "State/collision fixtures; full no-teleport routes are in route-budget-results.json."}, "\t"))
	file.close()
	app.free()
	OS.delay_msec(200)
	await process_frame
	quit(0 if passed else 1)
