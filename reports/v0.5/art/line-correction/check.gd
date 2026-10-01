extends SceneTree
## Reproduce the user's fixed-front image in the current production scene.
const OUT := "res://reports/v0.5/art/line-correction/"
var app: Node2D

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for _i in count:
		await process_frame
		await physics_frame

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")

func run() -> void:
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await frames(5)
	app.start_challenge(false, "pursuit", "level01")
	app.set_physics_process(false)
	app.player.reset_at(Vector2(820, 430))
	app.player.set_physics_process(false)
	app.camera.position_smoothing_enabled = false
	app.camera.position = Vector2(480, 270)
	app.camera.reset_smoothing()
	app.phase = "running"
	app.chase.front_x = 560.0
	app.chase.grace_remaining = 0.0
	app.chase.set_enabled(true)
	app.chase.advance(0.0, 810.0)
	await frames(5)
	var visual: Node2D = app.world.get_node("ChaseVisual")
	app.world.get_node("EnvironmentVisual").set_process(false)
	visual.set_process(false)
	visual._animation_time = 0.23
	visual.queue_redraw()
	await frames(3)
	await shot("front-line-current")
	visual.hide()
	await frames(3)
	await shot("front-line-without-effect")
	var metadata := {"front_world_x": app.chase.front_x,
		"front_canvas_x": (visual.get_global_transform_with_canvas() * Vector2(560, 0)).x,
		"canvas_size": root.get_visible_rect().size,
		"fixture": "Current main scene with fixed camera/player/front; visual evidence only.",
		"renderer": RenderingServer.get_video_adapter_name(),
		"godot": Engine.get_version_info().string}
	var file := FileAccess.open(OUT + "front-line-runtime.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata, "\t"))
	file.close()
	root.remove_child(app)
	app.free()
	await frames(8)
	await create_timer(0.15).timeout
	quit()
