extends SceneTree
var checks: Array[Dictionary] = []
func _initialize() -> void:
	call_deferred("run")
func frames(n: int) -> void:
	for _i in n:
		await physics_frame
		await process_frame
func check(name_value: String, passed: bool) -> void:
	checks.append({"check": name_value, "passed": passed})
	print(name_value, ": ", passed)
func shot(name_value: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/v0.4.1/" + name_value + ".png")
func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.gui_embed_subwindows = true
	root.size = Vector2i(1280, 720)
	var editor: Control = load("res://scenes/tools/generation_editor.tscn").instantiate()
	root.add_child(editor)
	await frames(5)
	editor.request_apply()
	await frames(3)
	check("confirmation_chinese_buttons_and_tool_theme", editor.confirm_apply.get_ok_button().text == "应用" and editor.confirm_apply.get_cancel_button().text == "取消" and editor.confirm_apply.theme == editor.theme)
	await shot("d-confirmation")
	editor.confirm_apply.hide()
	for dimensions in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = dimensions
		await frames(5)
		editor.play_draft()
		await frames(5)
		var hint: Control = editor.trial.ui.get_node("EditorReturnHint")
		var bounds: Rect2 = hint.get_global_rect()
		check("hint_bottom_right_inside_%d" % dimensions.x, Rect2(Vector2.ZERO, dimensions).encloses(bounds) and bounds.position.x >= dimensions.x - 200 and bounds.position.y >= dimensions.y - 50)
		check("hint_backplate_text_and_ignores_mouse_%d" % dimensions.x, hint is PanelContainer and hint.get_child(0).text == "工具试玩 · F8返回" and hint.mouse_filter == Control.MOUSE_FILTER_IGNORE)
		await shot("d-trial-%d" % dimensions.x)
		var event := InputEventKey.new()
		event.keycode = KEY_F8
		event.pressed = true
		Input.parse_input_event(event)
		await frames(4)
		check("f8_returns_after_hint_fix_%d" % dimensions.x, not is_instance_valid(editor.trial) and editor.chrome.visible)
	var file := FileAccess.open("res://reports/v0.4.1/d-fix-results.json", FileAccess.WRITE)
	var passed: bool = checks.all(func(c): return c.passed)
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "scope": "Targeted D confirmation text/theme, actual trial UI anchored positions and F8 input; request/play called directly, no configuration/physics changes or production default writes."}, "\t"))
	file.close()
	editor.free()
	OS.delay_msec(100)
	await process_frame
	quit(0 if passed else 1)
