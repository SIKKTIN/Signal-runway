extends SceneTree
const Driver = preload("res://reports/v0.4/input_driver.gd")
var app: Node2D
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://reports/v0.4/frames")
	app = load("res://scenes/main/main.tscn").instantiate()
	app.record_path = "user://codex_v04_capture_%d.json" % OS.get_process_id()
	root.add_child(app)
	await process_frame
	app.start_endless(404)
	var driver := Driver.new()
	var count := 0
	for step in 2200:
		if app.phase == "failed" or app.run_distance > 7550:
			break
		driver.step(app)
		await physics_frame
		await process_frame
		if app.run_distance >= 6500 and step % 4 == 0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://reports/v0.4/frames/run-%03d.png" % count)
			count += 1
	var passed: bool = app.phase == "running" and app.relay_count == 1 and count > 30
	print("CAPTURE ", count, " frames, node ", app.relay_count, ", ", passed)
	Input.action_release("jump")
	app.free()
	OS.delay_msec(200)
	await process_frame
	quit(0 if passed else 1)
