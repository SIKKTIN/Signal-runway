extends SceneTree
## Fixed main-scene fixtures: animation, pixels and lifecycle; not route proof.
const OUT := "res://reports/v0.2.1/art/"
var app: Node2D
var checks: Array[Dictionary] = []
var boundary_samples: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame

func check(name: String, passed: bool, actual: Variant = "") -> void:
	checks.append({"check": name, "passed": passed, "actual": actual})
	print(name, ": ", passed, " ", actual)

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")

func environment() -> Node2D:
	return app.world.get_node("EnvironmentVisual")

func threat() -> Node2D:
	return app.world.get_node("ChaseVisual")

func bind_fixture(front := 560.0) -> void:
	app.set_physics_process(false)
	app.player.reset_at(Vector2(820, 430))
	app.player.set_physics_process(false)
	app.camera.position_smoothing_enabled = false
	app.camera.position = Vector2(480, 270)
	app.camera.reset_smoothing()
	app.phase = "running"
	app.chase.front_x = front
	app.chase.grace_remaining = 0.0
	app.chase.set_enabled(true)
	app.chase.advance(0.0, 810.0)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "frames"))
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await frames(5)
	check("environment_installed_with_identity_and_layer", environment().transform == Transform2D.IDENTITY and environment().z_index == -10 and app.course.dynamic_environment_enabled)
	var menu_time: float = environment().presentation_state().animation_time
	await frames(10)
	check("menu_ambient_motion", environment().presentation_state().animation_time > menu_time)
	await shot("menu")
	app.start_challenge(false, "pursuit")
	check("new_world_clocks_start_at_zero", environment().presentation_state().animation_time == 0 and threat().presentation_state().animation_time == 0)
	bind_fixture()
	var saved_front: float = app.chase.front_x
	for index in 24:
		await frames(4)
		await shot("frames/motion-%02d" % index)
	check("both_clocks_advance_with_fixed_front", environment().presentation_state().animation_time > 1.5 and threat().presentation_state().animation_time > 1.5 and app.chase.front_x == saved_front, {"environment": environment().presentation_state(), "threat": threat().presentation_state()})
	app.toggle_pause()
	await frames(3)
	var paused_clocks: Array = [environment().presentation_state().animation_time, threat().presentation_state().animation_time]
	await shot("paused-a")
	await frames(24)
	await shot("paused-b")
	check("pause_freezes_clocks_and_loop", paused_clocks == [environment().presentation_state().animation_time, threat().presentation_state().animation_time] and threat().presentation_state().loop_paused, paused_clocks)
	# Freeze both components and compare the wave draw against exactly the
	# same world at several phases, not against a differently moving scene.
	app.ui.overlay.hide()
	for clock in [0.0, 0.23, 0.51, 0.94, 1.43, 2.0]:
		threat()._animation_time = clock
		threat().queue_redraw()
		threat().show()
		await frames(2)
		await shot("boundary-%02d-with" % boundary_samples.size())
		threat().hide()
		await frames(2)
		await shot("boundary-%02d-without" % boundary_samples.size())
		boundary_samples.append({"time": clock, "front_world_x": app.chase.front_x, "front_canvas_x": (threat().get_global_transform_with_canvas() * Vector2(app.chase.front_x, 0)).x, "wave_stroke_max_x": threat().presentation_state().wave_stroke_max_x})
	threat().show()
	app.ui.overlay.show()
	app.toggle_pause()
	await frames(8)
	check("resume_advances_clocks_and_loop", environment().presentation_state().animation_time > paused_clocks[0] and threat().presentation_state().animation_time > 2.0 and not threat().presentation_state().loop_paused)
	var old_fields := ["front_x", "gap_px", "warning_level", "mode", "paused", "resolved", "hud_visible", "loop_playing", "loop_paused", "loop_position", "animation_time", "caught_playing", "caught_position"]
	check("legacy_diagnostics_preserved", old_fields.all(func(field): return threat().presentation_state().has(field)))
	app.player.die("caught")
	await frames(4)
	var ended_clocks: Array = [environment().presentation_state().animation_time, threat().presentation_state().animation_time]
	await frames(20)
	check("failure_freezes_both_and_stops_loop", app.phase == "failed" and ended_clocks == [environment().presentation_state().animation_time, threat().presentation_state().animation_time] and not threat().presentation_state().loop_playing)
	await shot("failed")
	app.restart_challenge()
	check("restart_clears_both_clocks", environment().presentation_state().animation_time == 0 and threat().presentation_state().animation_time == 0)
	bind_fixture()
	await frames(5)
	app._on_goal(app.player)
	await frames(4)
	ended_clocks = [environment().presentation_state().animation_time, threat().presentation_state().animation_time]
	await frames(20)
	check("success_freezes_both_and_stops_loop", app.phase == "finished" and ended_clocks == [environment().presentation_state().animation_time, threat().presentation_state().animation_time] and not threat().presentation_state().loop_playing)
	app.start_challenge(false, "time_trial")
	bind_fixture()
	await frames(6)
	check("time_trial_ambient_without_threat", environment().presentation_state().animation_time > 0 and not threat().presentation_state().hud_visible and not threat().presentation_state().loop_playing)
	await shot("time-trial")
	# Parallax movement must follow the camera at distinct depths.
	var far_a: float = environment()._screen_world_x(4, 220.0, 0.0, 0.14)
	var far_b: float = environment()._screen_world_x(4, 220.0, 800.0, 0.14) - 800.0
	var near_a: float = environment()._screen_world_x(4, 304.0, 0.0, 0.57)
	var near_b: float = environment()._screen_world_x(4, 304.0, 800.0, 0.57) - 800.0
	check("distinct_parallax_depths", is_equal_approx(far_a - far_b, 112.0) and is_equal_approx(near_a - near_b, 456.0), {"far_shift": far_a - far_b, "near_shift": near_a - near_b})
	app.camera.position = Vector2(4800, 270)
	app.player.reset_at(Vector2(4520, 430))
	await frames(8)
	await shot("wall-jump")
	app.camera.position = Vector2(app.course.finish_x - 340.0, 270)
	app.player.reset_at(Vector2(app.course.finish_x - 180, 430))
	await frames(8)
	await shot("goal")
	for _i in 4:
		environment().bind_flow(app, app.camera, app.course)
		threat().bind_flow(app, app.chase)
	check("rebind_does_not_duplicate_listeners", app.get_signal_connection_list("pause_changed").size() == 2 and app.chase.get_signal_connection_list("threat_updated").size() == 1)
	app.start_challenge(true, "time_trial")
	await frames(8)
	check("lab_environment_installed", app.lab_mode and app.course.course_length == 2400 and environment().presentation_state().course_bound)
	await shot("lab")
	app.return_to_menu()
	await frames(4)
	check("menu_leaves_no_threat", not threat().presentation_state().hud_visible and not threat().presentation_state().loop_playing)
	var audio: AudioStreamPlayer = threat().get_node("ThreatLoop")
	root.remove_child(app)
	check("exit_disconnects_and_releases_audio", app.get_signal_connection_list("pause_changed").is_empty() and audio.stream == null and not audio.playing)
	app.free()
	await frames(6)
	await create_timer(0.15).timeout
	var passed := checks.all(func(row): return row.passed)
	var file := FileAccess.open(OUT + "lifecycle-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "boundary_samples": boundary_samples, "godot": Engine.get_version_info().string, "renderer": RenderingServer.get_video_adapter_name(), "fixture": "Fixed main scene, camera, player and chase boundary. Animation/lifecycle evidence only."}, "\t"))
	file.close()
	quit(0 if passed else 1)
