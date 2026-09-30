extends SceneTree

var app: Node2D

func _initialize() -> void:
	call_deferred("_capture")

func frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame

func save_frame(name: String) -> void:
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	if screenshot.is_empty():
		push_error("Empty rendered screenshot")
		return
	screenshot.save_png("res://reports/v0.1/" + name + ".png")

func _capture() -> void:
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await frames(12)
	await save_frame("menu")
	app.start_challenge(false)
	Input.action_press("move_right")
	await frames(80)
	Input.action_release("move_right")
	await frames(3)
	await save_frame("playing")
	app.toggle_pause()
	await frames(3)
	await save_frame("pause")
	app.toggle_pause()
	app.player.reset_at(Vector2(app.course.finish_x, 430))
	await frames(5)
	await save_frame("result-layout")
	app.return_to_menu()
	await frames(3)
	app.queue_free()
	await process_frame
	quit()
