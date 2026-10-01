extends "res://reports/v0.7/independent-checks/check_tools.gd"
## Only one connection-camera fixture for the new G candidate.
func run() -> void:
	print("V07_G_CAMERA_TOOL_PID ",OS.get_process_id())
	var before:=hashes()
	var records_before:=records()
	check("new_109_camera_tool_matches_before",frozen_matches(before))
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size=Vector2i(960,540)
	root.size=Vector2i(960,540)
	editor=load("res://scenes/tools/generation_editor.tscn").instantiate()
	editor.replay_path=OUT_F+"late-failure-fixture.json"
	root.add_child(editor)
	await frames(4)
	await press("LoadFailure")
	await press("PlayConnection")
	var path:=isolate("g-camera-connection")
	await frames(12)
	var trial: Node=editor.trial
	var feet: Vector2=trial.player.get_global_transform_with_canvas()*Vector2(0,15)
	var life: Rect2=trial._survival_status.get_global_rect()
	var panel: Control=trial.ui.get_node("EditorReturnHint")
	var label: Label=panel.get_child(0)
	var actual:= {"feet_canvas":str(feet),"camera":str(trial.camera.position),"grounded":trial.player.is_on_floor(),"smoothing":trial.camera.position_smoothing_enabled,"global_x":trial.player.position.x+trial.course.total_offset,"label":label.text,"panel":str(panel.get_global_rect()),"label_rect":str(label.get_global_rect()),"seed":trial.run_seed,"fingerprint":Profile.fingerprint(trial.generation_profile),"chunks":trial.course.chunks.size()}
	check("late_connection_new_camera_foot_safe",trial.player.is_on_floor() and not life.has_point(feet) and feet.y<450 and not trial.camera.position_smoothing_enabled,actual)
	check("late_connection_three_lines_still_visible_complete",label.is_visible_in_tree() and label.text.contains("第200段") and label.text.contains("距离注入 · 成绩隔离") and label.text.contains("F8返回") and Rect2(0,0,960,540).encloses(panel.get_global_rect()) and panel.get_global_rect().encloses(label.get_global_rect()),actual)
	await shot("g-tool-connection-camera-960")
	await tap(KEY_ESCAPE)
	var paused_camera: Vector2=trial.camera.position
	await frames(12)
	check("connection_pause_freezes_new_camera",paused and paused_camera==trial.camera.position)
	await tap(KEY_F8)
	check("actual_F8_cleans_paused_connection_and_keeps_index200",not paused and not is_instance_valid(editor.trial) and editor.chrome.visible and editor.rows[editor.preview.focus_index].index==200 and not FileAccess.file_exists(path))
	root.remove_child(editor)
	editor.free()
	await frames(8)
	OS.delay_msec(150)
	var after:=hashes()
	check("new_109_camera_tool_and_formal_records_unchanged",before==after and frozen_matches(after) and records_before==records())
	var file:=FileAccess.open(OUT_F+"g-camera-tool-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":checks.all(func(row):return row.passed),"checks":checks,"actual":actual,"before":before,"after":after,"records_before":records_before,"records_after":records(),"method":"Only new camera on a public Enter LoadFailure/PlayConnection from existing isolated index200 fixture, then actual Esc/F8. Position/distance injection is tool-defined and explicitly visible. GPU fixed60; no rerun of earlier 24 tool checks or old-mode suites. Record path isolated, existing failure file read only."},"\t"))
	file.close()
	quit(0 if checks.all(func(row):return row.passed) else 1)
