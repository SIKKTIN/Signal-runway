extends SceneTree

const OUT := "res://reports/v0.2/independent-checks/"
var app: Node2D
var checks: Array[Dictionary] = []
var failure_count := 0
var finish_count := 0
var screenshots: Array[String] = []
var boundary := {}
var observed_grades: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func tap(code: Key) -> void:
	key(code, true)
	await frames(2)
	key(code, false)
	await frames(2)

func check(name: String, passed: bool, detail: Variant, method := "real-input") -> void:
	checks.append({"check": name, "passed": passed, "actual": detail, "method": method})
	print(name, ": ", passed, " ", detail)

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var status := root.get_texture().get_image().save_png(OUT + name + ".png")
	screenshots.append(name + ".png")
	if status != OK:
		check("capture_" + name, false, status, "GPU")

func visual() -> Node:
	return app.world.get_node("ChaseVisual")

func move_then_stop() -> void:
	key(KEY_D, true)
	await frames(20)
	key(KEY_D, false)
	await frames(12)

func labels(node: Node) -> Array[String]:
	var result: Array[String] = []
	if node is Label:
		result.append(node.text)
	for child in node.get_children():
		result.append_array(labels(child))
	return result

func run() -> void:
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	app.run_failed.connect(func(_r, _t, _p): failure_count += 1)
	app.run_finished.connect(func(_t, _d, _b): finish_count += 1)
	await frames(8)
	check("menu_defaults_to_pursuit", app.phase == "menu" and app.mode == "pursuit", {"phase": app.phase, "mode": app.mode})
	await capture("menu")
	await tap(KEY_ENTER)
	check("real_enter_starts_ready_pursuit", app.phase == "ready" and app.mode == "pursuit" and app.ui.hud.visible, {"phase": app.phase, "mode": app.mode})
	var initial_front: float = app.chase.front_x
	await frames(90)
	check("idle_before_first_action_is_safe", app.elapsed == 0 and app.chase.front_x == initial_front and app.chase.grace_remaining == 2.0, {"elapsed": app.elapsed, "front": app.chase.front_x, "grace": app.chase.grace_remaining})
	await capture("ready")
	await move_then_stop()
	check("real_d_starts_grace", app.phase == "running" and app.elapsed > 0 and app.chase.grace_remaining > 1.0 and app.chase.front_x == initial_front, {"elapsed": app.elapsed, "front": app.chase.front_x, "grace": app.chase.grace_remaining, "player": app.player.position})
	await capture("grace")
	await frames(100)
	check("grace_ends_front_advances_at_270", app.chase.grace_remaining == 0 and app.chase.front_x > initial_front and app.chase.speed == 270, {"front": app.chase.front_x, "elapsed": app.elapsed, "speed": app.chase.speed})
	check("live_loop_loaded_and_playing", visual().presentation_state().loop_playing and visual().get_node("ThreatLoop").stream != null, visual().presentation_state(), "engine-audio-state")
	var gap_before_backtrack: float = app.chase.gap_px
	var x_before_backtrack: float = app.player.position.x
	key(KEY_A, true)
	await frames(12)
	key(KEY_A, false)
	await frames(6)
	check("real_backtrack_consumes_gap", app.chase.gap_px < gap_before_backtrack and app.player.position.x < x_before_backtrack, {"before_gap": gap_before_backtrack, "after_gap": app.chase.gap_px, "before_x": x_before_backtrack, "after_x": app.player.position.x})
	await tap(KEY_ESCAPE)
	var paused_snapshot: Array = [app.elapsed, app.chase.front_x, app.chase.grace_remaining, app.player.position, visual().presentation_state().animation_time]
	var audio_position: float = visual().presentation_state().loop_position
	await frames(45)
	var after_snapshot: Array = [app.elapsed, app.chase.front_x, app.chase.grace_remaining, app.player.position, visual().presentation_state().animation_time]
	check("real_esc_freezes_time_front_player_animation", app.phase == "paused" and paused_snapshot == after_snapshot, {"before": paused_snapshot, "after": after_snapshot})
	check("real_esc_freezes_threat_audio", visual().presentation_state().loop_paused and absf(visual().presentation_state().loop_position - audio_position) < 0.04, {"before": audio_position, "after": visual().presentation_state().loop_position}, "engine-audio-state")
	await capture("pause")
	await tap(KEY_R)
	await frames(60)
	check("real_r_while_paused_resets_and_waits", not paused and app.phase == "ready" and app.elapsed == 0 and app.chase.front_x == initial_front and app.chase.grace_remaining == 2 and app.deaths == 0 and not app.chase.enabled and not visual().presentation_state().loop_playing, {"phase": app.phase, "elapsed": app.elapsed, "front": app.chase.front_x, "audio": visual().presentation_state()})
	await move_then_stop()
	var prior_front: float = app.chase.front_x
	var prior_time: float = app.elapsed
	var saw_boundary := false
	for _i in 360:
		await frames(1)
		var grade: String = app.chase.warning_level
		if grade not in observed_grades:
			observed_grades.append(grade)
			if grade in ["near", "urgent"]:
				await capture(grade)
		if app.chase.grace_remaining == 0 and app.phase == "running":
			prior_front = app.chase.front_x
			prior_time = app.elapsed
			await frames(6)
			var dt: float = app.elapsed - prior_time
			if dt > 0.0 and app.chase.front_x > prior_front:
				check("stationary_front_rate", absf((app.chase.front_x - prior_front) / dt - 270.0) < 0.01, {"rate": (app.chase.front_x - prior_front) / dt}, "real-input")
				prior_front = app.chase.front_x
				prior_time = app.elapsed
				# One rate measurement is sufficient; prevent repeated assertions.
				break
	# Capture the exact draw half-plane with world frozen by real Esc.
	for _i in 240:
		await frames(1)
		var grade: String = app.chase.warning_level
		if grade not in observed_grades:
			observed_grades.append(grade)
			if grade in ["near", "urgent"]:
				await capture(grade)
		if not saw_boundary and app.chase.front_x > 20 and app.chase.gap_px > 20 and app.phase == "running":
			saw_boundary = true
			await tap(KEY_ESCAPE)
			app.ui.overlay.hide()
			boundary = {"front_world_x": app.chase.front_x, "front_screen_x": (visual().get_global_transform_with_canvas() * Vector2(app.chase.front_x, 0)).x, "player_left": app.player.position.x - 10.0, "gap": app.chase.gap_px, "viewport": root.get_texture().get_size()}
			check("hud_estimate_matches_gap_over_actual_speed", visual()._hud_detail.text == "原地余量约 %.1f 秒" % (app.chase.gap_px / app.chase.speed), {"text": visual()._hud_detail.text, "gap": app.chase.gap_px, "speed": app.chase.speed}, "engine-ui-state")
			await capture("front_with")
			visual().hide()
			await capture("front_without")
			visual().show()
			app.ui.overlay.show()
			await tap(KEY_ESCAPE)
		if app.phase == "failed":
			break
	check("stationary_player_is_naturally_caught_once", app.phase == "failed" and app.failure_reason == "caught" and app.chase.gap_px <= 0 and failure_count == 1 and finish_count == 0, {"reason": app.failure_reason, "phase": app.phase, "gap": app.chase.gap_px, "front": app.chase.front_x, "player_left": app.player.position.x - 10.0, "failures": failure_count})
	check("warning_near_and_urgent_are_observed", observed_grades.has("near") and observed_grades.has("urgent"), observed_grades, "state-and-GPU-screenshots")
	check("caught_card_and_loop_stop", labels(app.ui.content).has("被崩塌吞没") and not visual().presentation_state().loop_playing, {"labels": labels(app.ui.content), "audio": visual().presentation_state()}, "real-input-and-engine-state")
	await capture("caught")
	var caught_time: float = app.elapsed
	var caught_front: float = app.chase.front_x
	app._on_goal(app.player)
	app._queue_failure("spike")
	await frames(20)
	check("resolved_result_ignores_duplicate_goal_failure", failure_count == 1 and finish_count == 0 and app.elapsed == caught_time and app.chase.front_x == caught_front, {"failures": failure_count, "finishes": finish_count}, "event-fixture")
	await tap(KEY_ENTER)
	check("result_enter_restarts", app.phase == "ready" and app.failure_reason == "" and not app.player.dead, app.phase)
	await move_then_stop()
	app._on_goal(app.player)
	app._queue_failure("caught")
	app._queue_failure("fall")
	app.player.die("spike")
	await frames(4)
	check("same_frame_failure_beats_goal_once", app.phase == "failed" and app.failure_reason == "spike" and failure_count == 2 and finish_count == 0 and app.best_seconds == -1, {"phase": app.phase, "reason": app.failure_reason, "failures": failure_count, "finishes": finish_count, "best": app.best_seconds}, "event-fixture")
	await capture("spike")
	await tap(KEY_R)
	await move_then_stop()
	app.player.reset_at(Vector2(220, 700))
	await frames(5)
	check("fall_card_matches_real_fall_threshold", app.phase == "failed" and app.failure_reason == "fall" and labels(app.ui.content).has("坠入空隙"), {"phase": app.phase, "reason": app.failure_reason, "labels": labels(app.ui.content)}, "position-fixture-real-physics")
	await capture("fall")
	app.return_to_menu()
	await frames(5)
	# Menu second button is selected using actual keyboard navigation.
	await tap(KEY_DOWN)
	await tap(KEY_ENTER)
	check("keyboard_selects_original_time_trial", app.phase == "ready" and app.mode == "time_trial" and not app.lab_mode, {"phase": app.phase, "mode": app.mode})
	await move_then_stop()
	check("original_mode_has_no_threat", not app.chase.enabled and not visual().presentation_state().hud_visible and not visual().presentation_state().loop_playing, visual().presentation_state())
	var trial_time: float = app.elapsed
	app.player.reset_at(Vector2(622, 433))
	await frames(5)
	check("original_real_spike_enters_recovery", app.phase == "recovering" and app.deaths == 1, {"phase": app.phase, "deaths": app.deaths}, "position-fixture-real-collision")
	await frames(24)
	check("original_recovery_keeps_elapsed_and_respawns", app.phase == "running" and app.deaths == 1 and app.elapsed > trial_time and not app.player.dead and absf(app.player.position.x - app.course.spawn_position.x) < 0.1, {"phase": app.phase, "deaths": app.deaths, "elapsed": app.elapsed, "player": app.player.position}, "position-fixture-real-collision")
	await capture("time_trial")
	# Regression fixtures for the producer-reported deferred/pause race.
	app.start_challenge(false, "pursuit")
	await frames(5)
	await move_then_stop()
	var failure_baseline := failure_count
	app.player.die("spike")
	app.toggle_pause()
	await frames(4)
	check("pending_death_then_pause_resolves_without_dead_lock", app.phase == "failed" and not paused and failure_count == failure_baseline + 1 and app.failure_reason == "spike" and not visual().presentation_state().paused, {"phase": app.phase, "tree_paused": paused, "reason": app.failure_reason, "audio": visual().presentation_state()}, "same-callback-event-fixture")
	app.restart_challenge()
	await frames(5)
	await move_then_stop()
	app.toggle_pause()
	app.player.die("fall")
	await frames(4)
	check("late_death_after_pause_resolves", app.phase == "failed" and not paused and app.failure_reason == "fall" and failure_count == failure_baseline + 2, {"phase": app.phase, "tree_paused": paused, "reason": app.failure_reason}, "same-callback-event-fixture")
	app.restart_challenge()
	await frames(5)
	await move_then_stop()
	var goal_baseline := finish_count
	app._on_goal(app.player)
	app.toggle_pause()
	await frames(10)
	check("pending_goal_is_retained_during_pause", app.phase == "paused" and paused and app._goal_pending and finish_count == goal_baseline, {"phase": app.phase, "pending": app._goal_pending, "finishes": finish_count}, "same-callback-event-fixture")
	await tap(KEY_ESCAPE)
	check("pending_goal_resolves_once_after_real_resume", app.phase == "finished" and not paused and not app._goal_pending and finish_count == goal_baseline + 1, {"phase": app.phase, "pending": app._goal_pending, "finishes": finish_count}, "event-fixture-real-resume")
	app.restart_challenge()
	await frames(5)
	await move_then_stop()
	goal_baseline = finish_count
	app.toggle_pause()
	app._on_goal(app.player)
	await frames(10)
	check("late_goal_after_pause_is_retained", app.phase == "paused" and paused and app._goal_pending and finish_count == goal_baseline, {"phase": app.phase, "pending": app._goal_pending, "finishes": finish_count}, "same-callback-event-fixture")
	await tap(KEY_ESCAPE)
	check("late_goal_resolves_once_after_real_resume", app.phase == "finished" and not paused and not app._goal_pending and finish_count == goal_baseline + 1, {"phase": app.phase, "pending": app._goal_pending, "finishes": finish_count}, "event-fixture-real-resume")
	app.start_challenge(false, "time_trial")
	await frames(5)
	await move_then_stop()
	app.toggle_pause()
	app.player.die("spike")
	await frames(10)
	check("legacy_late_death_preserves_pause_and_recovery", app.phase == "paused" and paused and app._previous_phase == "recovering" and app.deaths == 1 and app.player.dead, {"phase": app.phase, "resume_phase": app._previous_phase, "deaths": app.deaths}, "same-callback-event-fixture")
	await tap(KEY_ESCAPE)
	await frames(20)
	check("legacy_late_death_recovers_after_real_resume", app.phase == "running" and not paused and not app.player.dead and app.deaths == 1, {"phase": app.phase, "deaths": app.deaths, "player": app.player.position}, "event-fixture-real-resume")
	app.return_to_menu()
	await frames(6)
	check("menu_clears_active_audio_and_hud", app.phase == "menu" and not visual().presentation_state().loop_playing and not visual().presentation_state().hud_visible, visual().presentation_state())
	var passed := checks.all(func(row): return row.passed)
	var file := FileAccess.open(OUT + "runtime-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": "v0.2.0+0dd12888c9bf", "godot": Engine.get_version_info().string, "renderer": RenderingServer.get_video_adapter_name(), "passed": passed, "checks": checks, "boundary": boundary, "screenshots": screenshots, "scope": "Real GPU/input critical paths plus explicitly marked event/position fixtures; no subjective listening or player study."}, "\t"))
	file.close()
	root.remove_child(app)
	app.free()
	await frames(6)
	await create_timer(0.15).timeout
	quit(0 if passed else 1)
