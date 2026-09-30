extends SceneTree
## Fixed camera/front fixtures inspect presentation, not gameplay or route proof.
var app: Node2D
var checks: Array[Dictionary] = []
const OUT := "res://reports/v0.2.1/"

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame

func check(label: String, passed: bool) -> void:
	checks.append({"check": label, "passed": passed})
	print(label, ": ", passed)

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + label + ".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "frames"))
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await frames(8)
	check("menu_environment_installed", app.world.has_node("EnvironmentVisual") and app.course.dynamic_environment_enabled)
	await shot("menu")
	app.start_challenge(false, "pursuit")
	Input.action_press("move_right")
	await frames(8)
	Input.action_release("move_right")
	# Isolate animation from camera, actor and front movement for frame comparison.
	app.set_physics_process(false)
	app.player.reset_at(Vector2(550, 430))
	app.player.set_physics_process(false)
	app.camera.position = Vector2(480, 270)
	app.camera.reset_smoothing()
	app.chase.front_x = 310.0
	app.chase.grace_remaining = 0.0
	app.chase.advance(0.0, 540.0)
	var environment: Node = app.world.get_node("EnvironmentVisual")
	var threat: Node = app.world.get_node("ChaseVisual")
	var initial_environment: float = environment.presentation_state().animation_time
	var initial_threat: float = threat.presentation_state().animation_time
	for i in 36:
		await frames(4)
		await shot("frames/frame-%02d" % i)
	check("environment_clock_moves", environment.presentation_state().animation_time > initial_environment + 1.0)
	check("wave_clock_moves", threat.presentation_state().animation_time > initial_threat + 1.0)
	check("visual_does_not_move_lethal_boundary", app.chase.front_x == 310.0)
	await shot("pursuit")
	app.toggle_pause()
	await frames(3)
	var paused_environment: float = environment.presentation_state().animation_time
	var paused_threat: float = threat.presentation_state().animation_time
	await shot("pause-a")
	await frames(30)
	check("pause_freezes_environment", environment.presentation_state().animation_time == paused_environment)
	check("pause_freezes_wave", threat.presentation_state().animation_time == paused_threat)
	await shot("pause-b")
	app.toggle_pause()
	await frames(8)
	check("resume_moves_environment", environment.presentation_state().animation_time > paused_environment)
	app.player.die("caught")
	await frames(4)
	var ended_environment: float = environment.presentation_state().animation_time
	var ended_threat: float = threat.presentation_state().animation_time
	await frames(20)
	check("failure_freezes_both", app.phase == "failed" and environment.presentation_state().animation_time == ended_environment and threat.presentation_state().animation_time == ended_threat)
	app.restart_challenge()
	check("restart_resets_environment_clock", app.world.get_node("EnvironmentVisual").presentation_state().animation_time < 0.1)
	check("restart_resets_wave_clock", app.world.get_node("ChaseVisual").presentation_state().animation_time < 0.1)
	app.set_physics_process(true)
	app.start_challenge(false, "time_trial")
	await frames(6)
	check("time_trial_has_environment", app.world.has_node("EnvironmentVisual"))
	check("time_trial_has_no_threat_hud", not app.world.get_node("ChaseVisual").presentation_state().hud_visible)
	await shot("time-trial")
	app.start_challenge(true, "time_trial")
	await frames(6)
	check("lab_has_environment", app.world.has_node("EnvironmentVisual") and app.course.course_length == 2400)
	await shot("lab")
	var file := FileAccess.open(OUT + "motion-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "fixture": "fixed camera, fixed lethal front; no route proof"}, "\t"))
	file.close()
	var passed := true
	for row in checks:
		passed = passed and row.passed
	app.free()
	await process_frame
	quit(0 if passed else 1)
