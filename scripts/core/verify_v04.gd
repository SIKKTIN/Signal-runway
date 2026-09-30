extends SceneTree
const Driver = preload("res://reports/v0.4/input_driver.gd")
var app: Node2D
var checks: Array[Dictionary] = []
const OUT := "res://reports/v0.4/"
func _initialize() -> void:
	call_deferred("run")
func frames(n: int) -> void:
	for _i in n:
		await physics_frame
		await process_frame
func check(name: String, passed: bool) -> void:
	checks.append({"check": name, "passed": passed})
	print(name, ": ", passed)
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await frames(2)
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")
func visual_clocks() -> Array:
	var result: Array = []
	for name in ["EndlessWorldVisual", "EndlessHUDVisual", "EnvironmentVisual", "RelayVisual", "ChaseVisual"]:
		result.append(app.world.get_node(name).presentation_state().animation_time)
	return result
func run() -> void:
	app = load("res://scenes/main/main.tscn").instantiate()
	app.record_path = "user://codex_v04_gpu_%d.json" % OS.get_process_id()
	root.add_child(app)
	await frames(6)
	await shot("menu")
	await key(KEY_ENTER)
	check("actual_enter_default_endless_autostart", app.is_endless() and app.phase == "running" and app.player.position.x > 96 and app.player.auto_run)
	check("production_visuals_and_pause_button", app.world.has_node("EndlessWorldVisual") and app.world.has_node("EndlessHUDVisual") and not app.ui.hud.visible and app.ui.endless_pause.visible)
	check("stream_has_no_goal", app.course.streaming and not app.course.has_node("Goal"))
	await key(KEY_ESCAPE)
	var before: Array = [app.elapsed, app.player.position, app.chase.front_x, app.run_score, app.course.generator.index, visual_clocks()]
	await shot("pause-a")
	await frames(12)
	check("keyboard_pause_freezes_logic_and_five_clocks", before == [app.elapsed, app.player.position, app.chase.front_x, app.run_score, app.course.generator.index, visual_clocks()])
	await shot("pause-b")
	var seed_value: int = app.run_seed
	await key(KEY_R)
	check("paused_r_same_seed_new_round", app.phase == "running" and app.run_seed == seed_value and not paused and app.relay_count == 0 and app.course.total_offset == 0)
	app.start_endless(404)
	var driver := Driver.new()
	for _i in 1800:
		if app.phase == "failed" or app.relay_count == 1:
			break
		driver.step(app)
		await frames(1)
	check("normal_jump_input_collects_first_relay", app.phase == "running" and app.relay_count == 1 and app.run_distance > 6000)
	check("relay_score_exact_formula", app.run_score == int(floor(app.run_distance / 10)) + 100)
	await shot("relay-active")
	var front: float = app.chase.front_x
	var elapsed: float = app.elapsed
	await frames(12)
	check("delay_front_stops_clock_continues", app.chase.front_x == front and app.elapsed > elapsed and app.relay_delay_remaining > 0)
	var snapshot: Dictionary = app.world.get_node("RelayVisual").presentation_state()
	check("relay_feedback_once", snapshot.sound_triggers == 1 and snapshot.activated_count == 1)
	app._queue_relay(app.course.relays[0].id)
	await frames(2)
	check("repeated_candidate_no_double_score", app.relay_count == 1)
	app.toggle_pause()
	before = [app.run_score, app.relay_delay_remaining, visual_clocks()]
	await frames(12)
	check("active_delay_pause_freezes", before == [app.run_score, app.relay_delay_remaining, visual_clocks()])
	app.toggle_pause()
	for _i in 65:
		driver.step(app)
		await frames(1)
	check("delay_exhausts_and_front_resumes", app.relay_delay_remaining == 0 and app.chase.front_x > front)
	# Explicit rebase fixture: preserve normal physics objects and public snapshots.
	Input.action_release("jump")
	app.set_physics_process(false)
	app.player.set_physics_process(false)
	app.course.update_stream(33333, 32000)
	app.player.position = Vector2(33333, 433)
	app._previous_position = app.player.position
	app.camera.position = Vector2(33513, 270)
	app.camera.reset_smoothing()
	app.chase.front_x = 32000
	app.chase.advance(0, app.player.position.x - 10)
	await frames(2)
	var gap: float = app.chase.gap_px
	var score: int = app.run_score
	var ids: Array = app.course.relays.map(func(r): return r.id)
	app._shift_endless_world(25600)
	await frames(2)
	check("rebase_preserves_gap_score_node_ids", app.chase.gap_px == gap and app.run_score == score and app.course.total_offset == 25600 and ids == app.course.relays.map(func(r): return r.id))
	var state: Dictionary = app.world.get_node("EndlessWorldVisual").presentation_state()
	check("rebase_art_snapshot_matches_active_chunks", state.module_count == app.course.chunks.size() and app.world.get_node("RelayVisual").presentation_state().node_count == app.course.relays.size())
	await shot("rebase")
	app.start_endless(404)
	app.set_physics_process(true)
	await frames(3)
	app.player.set_physics_process(false)
	app._queue_relay("unknown")
	app.player.die("spike")
	await frames(2)
	check("death_priority_single_record_result", app.phase == "failed" and app.relay_count == 0 and app.deaths == 1)
	await shot("result")
	await key(KEY_ENTER)
	check("result_enter_same_seed_retry", app.phase == "running" and app.run_seed == 404 and app.relay_count == 0)
	app.ui.new_seed_requested.emit()
	await frames(2)
	check("new_map_guarantees_different_seed", app.run_seed != 404 and app.phase == "running")
	await key(KEY_F2)
	check("actual_f2_manual_lab_goal_present", app.lab_mode and not app.player.auto_run and app.course.has_node("Goal") and not app.world.has_node("EndlessWorldVisual") and app.ui.hud.visible)
	app.return_to_menu()
	await frames(2)
	check("menu_keeps_valid_fixed_selection", app.ui.selected_level in ["level01", "relay_station"])
	app.ui.start_requested.emit()
	await frames(3)
	check("fixed_challenge_original_manual_rules", not app.is_endless() and not app.player.auto_run and app.phase == "ready" and app.chase.speed == 270 and app.course.has_node("Goal"))
	var passed := checks.all(func(c): return c.passed)
	var file := FileAccess.open(OUT + "integration-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "scope": "Actual main GPU keyboard/default/normal first relay plus explicit rebase/candidate/death fixtures. Full random routes separately recorded.", "engine": Engine.get_version_info().string, "renderer": RenderingServer.get_video_adapter_name()}, "\t"))
	file.close()
	var verification_record: String = app.record_path
	app.free()
	if FileAccess.file_exists(verification_record):
		DirAccess.remove_absolute(verification_record)
	OS.delay_msec(200)
	await frames(2)
	quit(0 if passed else 1)
