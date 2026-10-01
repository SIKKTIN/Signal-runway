extends SceneTree
const OUT := "res://reports/v0.4.1/independent-checks/"
const Profile = preload("res://scripts/level/generation_profile.gd")
var editor: Control
var checks: Array[Dictionary] = []
var profile_file := ""
var isolated_default := ""

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for _i in n:
		await physics_frame
		await process_frame

func check(name: String, passed: bool, actual: Variant = "") -> void:
	checks.append({"check":name,"passed":passed,"actual":actual})
	print(name, ": ", passed, " ", actual)

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")

func button(id: String) -> Control:
	return editor.find_child(id, true, false)

func motion(at: Vector2, relative := Vector2.ZERO, mask := 0) -> void:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.global_position = at
	e.relative = relative
	e.button_mask = mask
	Input.parse_input_event(e)

func mouse(at: Vector2, index: MouseButton, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = at
	e.global_position = at
	e.button_index = index
	e.pressed = down
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down and index == MOUSE_BUTTON_LEFT else (MOUSE_BUTTON_MASK_MIDDLE if down and index == MOUSE_BUTTON_MIDDLE else 0)
	Input.parse_input_event(e)

func click_at(at: Vector2) -> void:
	motion(at)
	await frames(1)
	mouse(at, MOUSE_BUTTON_LEFT, true)
	await frames(1)
	mouse(at, MOUSE_BUTTON_LEFT, false)
	await frames(3)

func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var window := control.get_window()
	if window != root:
		point += Vector2(window.position)
	await click_at(point)

func key(code: Key, down: bool, unicode := 0, ctrl := false) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.unicode = unicode
	e.ctrl_pressed = ctrl
	e.pressed = down
	Input.parse_input_event(e)

func tap(code: Key) -> void:
	key(code, true)
	await frames(1)
	key(code, false)
	await frames(2)

func enter_text(field: LineEdit, text: String) -> void:
	await click(field)
	key(KEY_A, true, 0, true)
	key(KEY_A, false, 0, true)
	for character in text:
		var value := character.unicode_at(0)
		var code := character.to_upper().unicode_at(0)
		key(code, true, value)
		key(code, false, value)
	await tap(KEY_ENTER)
	await frames(12)

func file_hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"

func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.gui_embed_subwindows = true
	root.size = Vector2i(1280,720)
	editor = load("res://scenes/tools/generation_editor.tscn").instantiate()
	root.add_child(editor)
	await frames(6)
	check("actual_tool_entry_theme_rows_and_locked_controls", editor.rows.size() == 20 and editor.theme.default_font_size == 15 and editor.controls.safe_a.enabled.disabled and editor.controls.relay_a.enabled.disabled)
	await click(button("Fit"))
	await shot("editor-1280")
	var rect: Rect2 = editor.preview.get_global_rect()
	var zoom_before: float = editor.preview.zoom
	motion(rect.get_center())
	mouse(rect.get_center(), MOUSE_BUTTON_WHEEL_UP, true)
	mouse(rect.get_center(), MOUSE_BUTTON_WHEEL_UP, false)
	await frames(3)
	check("wheel_zoom_through_gui", editor.preview.zoom > zoom_before)
	var pan_before: Vector2 = editor.preview.pan
	mouse(rect.get_center(), MOUSE_BUTTON_MIDDLE, true)
	motion(rect.get_center() + Vector2(42, 7), Vector2(42,7), MOUSE_BUTTON_MASK_MIDDLE)
	mouse(rect.get_center() + Vector2(42,7), MOUSE_BUTTON_MIDDLE, false)
	await frames(3)
	check("middle_drag_pans_through_gui", editor.preview.pan.distance_to(pan_before + Vector2(42,7)) < 0.1)
	await click(button("Fit"))
	rect = editor.preview.get_global_rect()
	await click_at(rect.position + Vector2(rect.size.x * 3.5 / 20, rect.size.y * .4))
	check("canvas_click_selects_segment_and_reasons", editor.preview.focus_index == 3 and editor.details.text.contains("段3") and editor.details.text.contains("原因：") and editor.details.text.contains("排除："))
	await click(button("Single"))
	await click(button("Fit"))
	check("single_segment_toggle", editor.preview.single)
	await shot("single")
	await click(button("Next"))
	check("next_segment_button", editor.preview.focus_index == 4)
	await enter_text(editor.seed_control.get_line_edit(), "77")
	await enter_text(editor.count_control.get_line_edit(), "24")
	await click(button("Generate"))
	check("keyboard_seed_count_commits", editor.seed_control.value == 77 and editor.rows.size() == 24)
	await enter_text(editor.controls.gap.weight.get_line_edit(), "9")
	await click(editor.controls.spike.enabled)
	await frames(16)
	check("weight_and_disabled_filter_update_draft", editor.draft.templates.gap.weight == 9 and not editor.draft.templates.spike.enabled and editor.rows.all(func(row):return row.template_id != "spike"))
	check("details_and_fingerprint_show_difference", editor.details.text.contains("gap:") and editor.details.text.contains("spike:") and editor.fingerprint_label.text.contains(Profile.fingerprint(editor.draft)))
	await shot("changed")
	var name_value := "C104_%d" % OS.get_process_id()
	await enter_text(editor.profile_name, name_value)
	await click(button("SaveProfile"))
	profile_file = "user://map_editor_profiles/" + name_value + ".json"
	var custom: Dictionary = editor.draft.duplicate(true)
	check("mouse_save_unique_profile", FileAccess.file_exists(profile_file) and Profile.load_profile(profile_file).profile == custom, editor.status.text)
	await click(button("Reset"))
	check("restore_builtin_default", editor.draft == Profile.normalized(Profile.defaults()))
	# Select only the newly saved profile, then invoke the actual load button.
	var saved_index := -1
	for index in editor.profiles.item_count:
		if editor.profiles.get_item_text(index) == name_value:
			saved_index = index
	if saved_index >= 0:
		editor.profiles.select(saved_index)
	await click(button("LoadProfile"))
	check("mouse_load_restores_saved_draft", saved_index >= 0 and editor.draft == custom)
	await enter_text(editor.profile_name, "bad/name")
	await click(button("SaveProfile"))
	check("invalid_name_error_visible", editor.status.text.contains("方案名需"))
	await enter_text(editor.controls.relay_min.get_line_edit(), "8")
	await enter_text(editor.controls.relay_max.get_line_edit(), "4")
	await click(button("Generate"))
	await click(button("Play"))
	check("invalid_range_visible_and_blocks_trial", editor.status.text.contains("草稿无效") and not is_instance_valid(editor.trial))
	await shot("invalid")
	await click(button("LoadProfile"))
	isolated_default = OUT + "isolated-default-%d.json" % OS.get_process_id()
	Profile.save_profile(Profile.defaults(), isolated_default)
	editor.default_path = isolated_default
	var before_hash := file_hash(isolated_default)
	await click(button("Apply"))
	check("apply_shows_confirmation_dialog", editor.confirm_apply.visible)
	await shot("confirmation")
	await click(editor.confirm_apply.get_cancel_button())
	check("cancel_does_not_apply", not editor.confirm_apply.visible and before_hash == file_hash(isolated_default))
	await click(button("Apply"))
	await click(editor.confirm_apply.get_ok_button())
	check("confirmed_mouse_apply_isolated_file_and_backup", Profile.load_profile(isolated_default).profile == custom and Profile.load_profile(isolated_default + ".bak").profile == Profile.normalized(Profile.defaults()))
	await click(button("Backup"))
	check("backup_load_changes_draft_only", editor.draft == Profile.normalized(Profile.defaults()) and Profile.load_profile(isolated_default).profile == custom)
	await click(button("LoadProfile"))
	await click(button("Play"))
	await frames(4)
	check("actual_play_button_runs_main_with_profile", is_instance_valid(editor.trial) and editor.trial.is_endless() and editor.trial.phase == "running" and editor.trial.player.position.x > 96 and editor.trial.course.generation_profile == custom)
	var trial_record: String = editor.trial.record_path
	check("trial_record_isolated_from_official", trial_record.begins_with("user://map_editor_trial_") and trial_record != "user://signal_runway_endless.json")
	var trial_seed: int = editor.trial.run_seed
	await tap(KEY_R)
	check("trial_r_preserves_seed_and_config", editor.trial.run_seed == trial_seed and editor.trial.course.generation_profile == custom)
	await shot("trial")
	# Explicit failure fixture to reach the actual result's new-map control.
	editor.trial.player.die("caught")
	await frames(3)
	await tap(KEY_DOWN)
	await tap(KEY_ENTER)
	check("trial_new_map_keeps_profile", editor.trial.phase == "running" and editor.trial.run_seed != trial_seed and editor.trial.course.generation_profile == custom)
	await tap(KEY_F8)
	check("f8_returns_draft_and_cleans_trial_record", not is_instance_valid(editor.trial) and editor.chrome.visible and editor.draft == custom and not FileAccess.file_exists(trial_record))
	root.size = Vector2i(960,540)
	await frames(6)
	await click(button("Single"))
	await click(button("Fit"))
	await shot("editor-960")
	var bounds: Rect2 = root.get_visible_rect()
	var visible_actions := true
	for id in ["Generate", "Fit", "Previous", "Next", "Single", "SaveProfile", "LoadProfile", "Reset", "Play", "Apply", "Backup"]:
		visible_actions = visible_actions and bounds.encloses(button(id).get_global_rect())
	check("960_core_actions_within_native_canvas", visible_actions, {"canvas":str(bounds.size),"preview":str(editor.preview.size)})
	await click(button("Play"))
	await frames(3)
	await tap(KEY_F8)
	check("960_play_return_controls_operate", not is_instance_valid(editor.trial) and editor.chrome.visible)
	root.remove_child(editor)
	editor.free()
	# Old main entry is loaded with unmodified production default.
	var app: Node2D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await frames(3)
	await tap(KEY_ENTER)
	check("old_game_default_enter_still_runs", app.is_endless() and app.phase == "running" and app.player.auto_run)
	await tap(KEY_F2)
	check("old_f2_lab_still_manual_goal", app.lab_mode and not app.player.auto_run and app.course.has_node("Goal"))
	root.remove_child(app)
	app.free()
	await frames(6)
	await create_timer(.15).timeout
	var passed := checks.all(func(row):return row.passed)
	var file := FileAccess.open(OUT + "runtime.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"renderer":RenderingServer.get_video_adapter_name(),"profile_file":profile_file,"isolated_default":isolated_default,"scope":"Input.parse_input_event mouse/key through actual controls; profile dropdown index selection and default_path setup are explicit fixtures. Trial caught result only is a state fixture. No real production default application."},"\t"))
	file.close()
	# Remove only this check's uniquely named personal profile, not other plans.
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(profile_file + suffix):
			DirAccess.remove_absolute(profile_file + suffix)
	quit(0 if passed else 1)
