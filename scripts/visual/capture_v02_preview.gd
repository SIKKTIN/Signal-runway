extends SceneTree


func _initialize() -> void:
	call_deferred("_capture")


func frames(count: int) -> void:
	for index in range(count):
		await process_frame


func save_frame(name: String) -> bool:
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Graphical capture required; do not use --headless")
		return false
	return image.save_png("res://reports/v0.2/art/%s.png" % name) == OK


func _capture() -> void:
	var preview: Node2D = load("res://scenes/visual/chase_preview.tscn").instantiate()
	root.add_child(preview)
	await frames(12)
	var passed := true
	for grade in ["grace", "safe", "near", "urgent"]:
		preview.choose_grade(grade)
		await frames(12)
		passed = save_frame(grade) and passed
	preview.show_failure_skins()
	await frames(12)
	passed = save_frame("failure_skins") and passed
	preview.show_caught()
	await frames(12)
	passed = save_frame("caught") and passed
	preview.queue_free()
	await frames(8)
	await create_timer(0.12).timeout
	quit(0 if passed else 1)
