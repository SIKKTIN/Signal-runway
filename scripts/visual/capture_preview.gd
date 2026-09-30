extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	var packed: PackedScene = load("res://scenes/visual/art_preview.tscn")
	var scene := packed.instantiate()
	root.add_child(scene)
	for frame in range(8):
		await process_frame
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Preview capture returned an empty image")
		quit(1)
		return
	var path := ProjectSettings.globalize_path("res://reports/v0.1/art/preview.png")
	var result := image.save_png(path)
	if result != OK:
		push_error("Preview capture failed: %s" % result)
		quit(result)
		return
	for frame in range(75):
		await process_frame
	var motion := root.get_texture().get_image()
	if motion == null or motion.is_empty():
		push_error("Motion capture returned an empty image")
		quit(1)
		return
	result = motion.save_png(ProjectSettings.globalize_path("res://reports/v0.1/art/preview_motion.png"))
	quit(result)
