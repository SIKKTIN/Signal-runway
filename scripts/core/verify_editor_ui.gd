extends SceneTree
const Profile = preload("res://scripts/level/generation_profile.gd")
var editor: Control
var checks: Array[Dictionary] = []
const OUT := "res://reports/v0.4.1/"
func _initialize() -> void:
	call_deferred("run")
func frames(n: int = 3) -> void:
	for _i in n:
		await physics_frame
		await process_frame
func check(title: String, passed: bool) -> void:
	checks.append({"check": title, "passed": passed})
	print(title, ": ", passed)
func shot(name_value: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name_value + ".png")
func click(name_value: String) -> void:
	var node: Control = editor.find_child(name_value, true, false)
	var motion := InputEventMouseMotion.new()
	motion.position = node.get_global_rect().get_center()
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await frames(1)
	print("HOVER ", name_value, " ", root.gui_get_hovered_control())
	var event := InputEventMouseButton.new()
	event.position = node.get_global_rect().get_center()
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await frames(1)
	event = event.duplicate()
	event.pressed = false
	event.button_mask = 0
	Input.parse_input_event(event)
	await frames()
	print("CLICK ", name_value, " ", node.get_global_rect(), " -> ", editor.status.text)
func run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	editor = load("res://scenes/tools/generation_editor.tscn").instantiate()
	editor.default_path = "user://editor_ui_default_%d.json" % OS.get_process_id()
	Profile.save_profile(Profile.defaults(), editor.default_path)
	root.add_child(editor)
	await frames(6)
	print("RECT ", root.get_visible_rect(), " EDITOR ", editor.get_global_rect(), " CHROME ", editor.chrome.get_global_rect(), " SCALE ", root.get_canvas_transform()); check("shared_generator_preview_and_theme_ready", editor.rows.size() == 20 and editor.rows[5].category == "relay" and editor.theme != null)
	await shot("editor-overview")
	var old_rows: Array = editor.rows.map(func(r): return r.template_id)
	editor.controls.spike.weight.value = 10
	await frames(20)
	check("ui_parameter_live_debounce_changes_sequence", old_rows != editor.rows.map(func(r): return r.template_id) and editor.draft.templates.spike.weight == 10)
	check("locked_safe_and_relay_controls", editor.controls.safe_a.enabled.disabled and editor.controls.safe_b.enabled.disabled and editor.controls.relay_a.enabled.disabled)
	await click("Next")
	check("real_mouse_selects_next_chunk", editor.preview.focus_index == 1 and editor.details.text.contains("段1"))
	await click("Single")
	check("single_view_uses_same_geometry", editor.preview.single)
	await shot("editor-single")
	await click("Single")
	var zoom_before: float = editor.preview.zoom
	var wheel := InputEventMouseButton.new()
	wheel.position = editor.preview.get_global_rect().get_center()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	Input.parse_input_event(wheel)
	await frames()
	wheel = wheel.duplicate()
	wheel.pressed = false
	Input.parse_input_event(wheel)
	await frames()
	check("wheel_zoom_responds", editor.preview.zoom > zoom_before)
	editor.profile_name.text = "verify_" + str(OS.get_process_id())
	await click("SaveProfile")
	var named: String = editor.PROFILE_DIR + "/" + editor.profile_name.text + ".json"
	check("named_save_actual_control", FileAccess.file_exists(named) and Profile.load_profile(named).profile.templates.spike.weight == 10)
	for i in editor.profiles.item_count:
		if editor.profiles.get_item_text(i) == editor.profile_name.text:
			editor.profiles.select(i)
	await click("Reset")
	check("reset_restores_builtin_not_applied", editor.draft == Profile.defaults())
	await click("LoadProfile")
	check("named_load_restores_parameters", editor.draft.templates.spike.weight == 10)
	await click("Apply")
	check("apply_opens_confirmation_without_write", editor.confirm_apply.visible and Profile.load_profile(editor.default_path).profile == Profile.defaults())
	editor.confirm_apply.hide()
	await click("Apply")
	editor.confirm_apply.confirmed.emit()
	editor.confirm_apply.hide()
	await frames()
	check("confirmed_apply_backup_and_baseline", Profile.load_profile(editor.default_path).profile.templates.spike.weight == 10 and Profile.load_profile(editor.default_path + ".bak").profile == Profile.defaults() and editor.baseline.templates.spike.weight == 10)
	await click("Backup")
	check("backup_load_is_draft_only", editor.draft == Profile.defaults() and Profile.load_profile(editor.default_path).profile.templates.spike.weight == 10)
	await click("Play")
	check("real_control_launches_main_with_same_profile_seed", is_instance_valid(editor.trial) and editor.trial.is_endless() and editor.trial.run_seed == 404 and editor.trial.course.generation_profile == editor.draft and not editor.chrome.visible)
	if not is_instance_valid(editor.trial):
		quit(1)
		return
	check("trial_record_isolation", editor.trial.record_path != "user://signal_runway_endless.json")
	await shot("editor-trial")
	var key := InputEventKey.new()
	key.keycode = KEY_F8
	key.pressed = true
	Input.parse_input_event(key)
	await frames(5)
	check("f8_returns_and_cleans_trial", not is_instance_valid(editor.trial) and editor.chrome.visible and not paused)
	editor.controls.relay_min.value = 8
	editor.controls.relay_max.value = 4
	await frames(20)
	await click("Play")
	check("invalid_draft_visible_and_blocks_trial", not is_instance_valid(editor.trial) and editor.status.text.contains("草稿无效"))
	await shot("editor-invalid")
	await click("Reset")
	root.size = Vector2i(960, 540)
	root.content_scale_size = Vector2i(960, 540)
	await frames(8)
	var fits := true
	for name_value in ["Generate", "NewSeed", "Fit", "SaveProfile", "LoadProfile", "Reset", "Validate", "Play", "Apply", "Backup", "MapPreview"]:
		var node: Control = editor.find_child(name_value, true, false)
		fits = fits and Rect2(Vector2.ZERO, Vector2(960, 540)).encloses(node.get_global_rect())
	check("960_native_core_controls_within_viewport", fits)
	await shot("editor-960")
	var path: String = editor.default_path
	editor.free()
	for file_path in [named, named + ".bak", path, path + ".bak"]:
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)
	var file := FileAccess.open(OUT + "ui-results.json", FileAccess.WRITE)
	var passed: bool = checks.all(func(c): return c.passed)
	file.store_string(JSON.stringify({"checks": checks, "passed": passed, "scope": "Native GPU control clicks/scroll/F8; SpinBox values assigned, confirmation signal explicitly emitted; application file is isolated fixture, real project default never overwritten."}, "\t"))
	file.close()
	OS.delay_msec(100)
	await process_frame
	quit(0 if passed else 1)
