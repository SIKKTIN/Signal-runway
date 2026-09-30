extends SceneTree
var app: Node2D
var image_index := 0
func _initialize() -> void:
	call_deferred("run")
func frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/v0.3/frames"))
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await frames(5)
	app.start_challenge(false, "pursuit", "relay_station")
	Input.action_press("move_right")
	var held := 0
	for step in 760:
		if app.phase in ["failed", "finished"]:
			break
		var p: CharacterBody2D = app.player
		if held > 0:
			held -= 1
			if held == 0:
				Input.action_release("jump")
		if p.is_on_floor() and not Input.is_action_pressed("jump"):
			var jump := (p.position.x >= 2158 and p.position.x < 2204 and p.position.y > 410) or (p.position.x >= 2337 and p.position.x < 2384 and p.position.y < 410)
			if p.position.y > 410:
				for gap in app.course.gaps:
					jump = jump or (p.position.x >= gap.position.x - 44 and p.position.x < gap.position.x)
				for spike in app.course.spikes:
					jump = jump or (p.position.x >= spike.position.x - 54 and p.position.x < spike.end.x)
			if jump:
				Input.action_press("jump")
				held = 25
		await frames(1)
		if p.position.x >= 2100 and p.position.x <= 2900 and step % 4 == 0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://reports/v0.3/frames/frame-%03d.png" % image_index)
			image_index += 1
	Input.action_release("move_right")
	Input.action_release("jump")
	print("Actual input capture: ", image_index, " frames, relays=", app.relay_count, " phase=", app.phase)
	var passed: bool = image_index > 20 and app.relay_count == 1 and app.phase == "running"
	app.free()
	app = null
	OS.delay_msec(200)
	await frames(2)
	quit(0 if passed else 1)
