extends SceneTree
var app: Node2D
func _initialize() -> void:
	call_deferred("_capture")
func frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame
func save_frame(label: String) -> void:
	await RenderingServer.frame_post_draw
	var pixels := root.get_texture().get_image()
	if pixels.is_empty():
		push_error("Empty screenshot")
		return
	pixels.save_png("res://reports/v0.2/" + label + ".png")
func _capture() -> void:
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await frames(12)
	await save_frame("menu")
	app.start_challenge(false, "pursuit")
	Input.action_press("move_right")
	await frames(75)
	Input.action_release("move_right")
	await frames(3)
	await save_frame("grace")
	await frames(120)
	await save_frame("near")
	await frames(60)
	await save_frame("pursuit")
	app.toggle_pause()
	await frames(3)
	await save_frame("pause")
	app.toggle_pause()
	await frames(150)
	await save_frame("failure")
	# Targeted fixture only for successful result layout, not route proof.
	app.start_challenge(false, "pursuit")
	Input.action_press("move_right")
	await frames(3)
	Input.action_release("move_right")
	app.player.reset_at(Vector2(app.course.finish_x, 430))
	await frames(5)
	await save_frame("result-layout")
	app.return_to_menu()
	app.free()
	OS.delay_msec(200)
	await process_frame
	quit()
