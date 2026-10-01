extends SceneTree
const OUT := "res://reports/v0.8/art/"
const Main := preload("res://scenes/main/main.tscn")
const Profile := preload("res://scripts/level/generation_profile.gd")
func _initialize() -> void:
	call_deferred("run")
func frames(count: int) -> void:
	for _i in count:
		await process_frame
		await physics_frame
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + str(int(root.size.x)) + "-surface-" + label + ".png")
func run() -> void:
	print("ART_PIXEL_PID=" + str(OS.get_process_id()))
	var flow: Node2D = Main.instantiate()
	flow.generation_profile = Profile.defaults()
	flow.dash_prototype_kind = "shortcut"
	flow.trial_speed = 380.0
	flow.record_path = OUT + "isolated-pixel.json"
	root.add_child(flow)
	flow.start_endless(404)
	# Explicit visual fixture: normal beginning, then real public dash on floor.
	await frames(6)
	Input.action_press("dash")
	await frames(1)
	Input.action_release("dash")
	await frames(5)
	flow.toggle_pause()
	# Hide pause overlay for a frozen unobscured terrain comparison.
	flow.ui.show_playing()
	await frames(3)
	var visual: Node2D = flow.world.get_node("DashVisual")
	visual.set_process(false)
	await shot("with")
	visual.hide()
	await shot("without")
	paused = false
	root.remove_child(flow)
	flow.free()
	await frames(8)
	OS.delay_msec(150)
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(OUT + "isolated-pixel.json" + suffix):
			DirAccess.remove_absolute(OUT + "isolated-pixel.json" + suffix)
	quit()
