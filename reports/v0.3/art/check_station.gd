extends SceneTree
const OUT := "res://reports/v0.3/art/station/"
var app: Node2D
var checks: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame

func check(label: String, passed: bool, actual: Variant = "") -> void:
	checks.append({"check": label, "passed": passed, "actual": actual})
	print(label, ": ", passed, " ", actual)

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")

func geometry() -> String:
	var relay_positions: Array = []
	for entry in app.course.relays:
		relay_positions.append([entry.id, entry.position])
	return str([app.course.course_length, app.course.finish_x, app.course.floors, app.course.walls, app.course.gaps, app.course.spikes, relay_positions])

func frame_at(camera_x: float, player_at: Vector2) -> void:
	app.camera.position = Vector2(camera_x, 270)
	app.camera.reset_smoothing()
	app.player.reset_at(player_at)
	app.player.set_physics_process(false)
	app.chase.front_x = player_at.x - 1000
	app.chase.grace_remaining = 0
	app.chase.set_enabled(true)
	app.chase.advance(0, player_at.x - 10)
	app._update_ui()
	await frames(4)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "frames"))
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await frames(5)
	await shot("menu")
	app.start_challenge(false, "pursuit", "relay_station")
	app.phase = "running"
	app.set_physics_process(false)
	app.player.set_physics_process(false)
	# These camera fixtures inspect visuals only; isolate teleported poses
	# from Area callbacks. This is not a collision or no-teleport route test.
	app.player.collision_layer = 0
	app.player.collision_mask = 0
	app.camera.position_smoothing_enabled = false
	app.ui.set_notice("", Color.WHITE)
	var baseline := geometry()
	var environment: Node2D = app.world.get_node("EnvironmentVisual")
	check("formal_station_enabled", environment.presentation_state().station_enabled and app.course.course_length == 14500)
	var poses := [["intake", 480.0, Vector2(180, 432), 0], ["branch-one", 2400.0, Vector2(2250, 384), 1],
		["branch-one-exit", 2870.0, Vector2(3000, 432), 1], ["transmission", 5800.0, Vector2(5640, 432), 2],
		["branch-two", 8350.0, Vector2(8260, 368), 3], ["branch-two-exit", 8900.0, Vector2(9000, 432), 3],
		["output", 14000.0, Vector2(14100, 432), 4]]
	for pose in poses:
		await frame_at(pose[1], pose[2])
		await shot(pose[0])
		check("section_" + pose[0], environment.presentation_state().station_section == pose[3], environment.presentation_state())
	await frame_at(2400, Vector2(2490, 336))
	app._queue_relay("relay_one")
	await frames(3)
	app._update_ui()
	await shot("branch-one-activation")
	await frame_at(8350, Vector2(8490, 280))
	app._queue_relay("relay_two")
	await frames(3)
	app._update_ui()
	await shot("branch-two-activation")
	check("node_and_hud_formal_feedback", app.relay_count == 2 and app.world.get_node("RelayVisual").presentation_state().sound_triggers == 2 and app.world.get_node("ChaseVisual").presentation_state().relay_delay_visible)
	for index in 16:
		await frames(3)
		await shot("frames/branch-%02d" % index)
	app.toggle_pause()
	await frames(3)
	await shot("pause-a")
	var clock: float = environment.presentation_state().animation_time
	await frames(18)
	await shot("pause-b")
	check("pause_freezes_station", environment.presentation_state().animation_time == clock)
	app.toggle_pause()
	app.player.die("fall")
	await frames(4)
	clock = environment.presentation_state().animation_time
	await frames(12)
	check("failure_freezes_station", app.phase == "failed" and environment.presentation_state().animation_time == clock)
	check("geometry_unchanged_by_presentation", geometry() == baseline)
	app.start_challenge(false, "time_trial", "level01")
	await frames(4)
	check("original_level_uses_original_ambient", not app.world.get_node("EnvironmentVisual").presentation_state().station_enabled)
	app.start_challenge(true, "time_trial")
	await frames(4)
	check("lab_bool_disables_station_wrapper", app.lab_mode and not app.world.get_node("EnvironmentVisual").presentation_state().station_enabled)
	await shot("lab")
	root.remove_child(app)
	app.free()
	await frames(8)
	await create_timer(0.15).timeout
	var passed := checks.all(func(row): return row.passed)
	var file := FileAccess.open(OUT + "station-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "godot": Engine.get_version_info().string, "fixture": "Fixed camera and actor in formal completed geometry; no route proof. Event activation candidates for layout/HUD checks."}, "\t"))
	file.close()
	quit(0 if passed else 1)
