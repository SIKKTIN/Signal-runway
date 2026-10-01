extends "res://reports/v0.7/independent-checks/check_tools.gd"
const OUT8 := "res://reports/v0.8/independent-checks/"

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT8+label+".png")
func hashes() -> Dictionary:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://reports/v0.8/version-manifest.json"))
	var value: Dictionary = {}
	for row in manifest.files:
		value[row.path] = hash_or_missing("res://"+row.path)
	return value
func frozen_matches(current: Dictionary) -> bool:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://reports/v0.8/version-manifest.json"))
	return manifest.files.all(func(row: Dictionary) -> bool:return current.get(row.path)==row.sha256)
func records() -> Dictionary:
	return {"v08":hash_or_missing(Record.DEFAULT_PATH),"v07":hash_or_missing(Record.V07_PATH),"v06":hash_or_missing(Record.V06_PATH),"v05":hash_or_missing(Record.V05_PATH),"earlier":hash_or_missing(Record.LEGACY_PATH),"failure":hash_or_missing(Replay.DEFAULT_PATH),"failure_v07":hash_or_missing(Replay.V07_PATH)}
func isolate(label: String) -> String:
	var path := OUT8+"isolated-tool-"+label+".json"
	editor._trial_record = path
	editor.trial.record_path = path
	return path
func visible_hint(label: String) -> void:
	var panel: Control = editor.trial.ui.get_node("EditorReturnHint")
	var text: Label = panel.get_child(0)
	var observation := {"case":label,"text":text.text,"visible":text.is_visible_in_tree(),"panel":str(panel.get_global_rect()),"label":str(text.get_global_rect()),"minimum":str(text.get_minimum_size()),"dash":editor.trial.player.dash_snapshot(),"hud":editor.trial._dash_status.presentation_state(),"global_x":editor.trial.player.position.x+editor.trial.course.total_offset,"health":editor.trial.player.health,"seed":editor.trial.run_seed,"chunks":editor.trial.course.chunks.size()}
	observations.append(observation)
	check(label+"_hint_actually_visible",text.is_visible_in_tree() and panel.get_global_rect().encloses(text.get_global_rect()) and Rect2(0,0,960,540).encloses(panel.get_global_rect()) and text.get_minimum_size().x<=text.size.x and text.get_minimum_size().y<=text.size.y and text.text.contains("F8返回") and (text.text.contains("成绩隔离") or text.text.contains("注入/成绩隔离")),observation)
func run() -> void:
	print("V08_F_TOOL_PID=",OS.get_process_id())
	var before := hashes()
	var records_before := records()
	check("118_frozen_before",frozen_matches(before))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(960,540)
	root.size = Vector2i(960,540)
	editor = load("res://scenes/tools/generation_editor.tscn").instantiate()
	editor.replay_path = OUT8+"tool-failure-fixture.json"
	root.add_child(editor)
	await frames(4)
	check("actual_default6",editor.draft.generator_revision==6 and editor.controls.skill_weight.editable)
	editor.count_control.value = 40
	editor.regenerate()
	var selection := -1
	for i in editor.rows.size():
		if editor.rows[i].geometry.has("skill"):
			selection = i
			break
	check("actual_skill_preview_present",selection>=0)
	editor.select_chunk(selection)
	check("actual_details_requirement_reward",editor.details.text.contains("入口") and editor.details.text.contains("路径") and editor.details.text.contains("节点"),editor.details.text)
	await shot("tool-preview")
	for amount in 3:
		editor.dash_choice.select(amount)
		await press("PlaySelected")
		var path := isolate("resources-"+str(amount))
		await frames(3)
		check("actual_resources_"+str(amount),editor.trial.player.dash_charges==amount and editor.trial._dash_status.presentation_state().snapshot.charges==amount)
		visible_hint("resources_"+str(amount))
		await shot("tool-resources-"+str(amount))
		await tap(KEY_SHIFT)
		if amount==0:
			check("actual_shift_empty_no_consumption",not editor.trial.player.dash_active and editor.trial.player.dash_used==0 and editor.trial._dash_status.presentation_state().detail.contains("冲刺耗尽"))
		elif amount==2:
			await tap(KEY_F9)
			check("actual_F9_hurt_cancel_no_refund",editor.trial.player.health==2 and not editor.trial.player.dash_active and editor.trial.player.dash_charges==1 and editor.trial.world.get_node("DashVisual").presentation_state().trace_count==0)
			editor.trial._queue_failure("caught")
			await frames(4)
			var resource_before: Dictionary = editor.trial.player.dash_snapshot()
			await tap(KEY_SHIFT)
			check("terminal_priority_shift_no_revive",editor.trial.phase=="failed" and not editor.trial.player.dash_active and editor.trial.player.dash_snapshot()==resource_before and not editor.trial._dash_status.visible)
			var result: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
			check("isolated_rule8_four_score_parts",result.rules_revision==8 and result.generator_revision==6 and result.score_breakdown.has_all(["distance","nodes","combo","station"]),result)
		await tap(KEY_F8)
		check("actual_F8_cleanup_"+str(amount),not is_instance_valid(editor.trial) and editor.chrome.visible and not FileAccess.file_exists(path))
	# Disclosed file fixture: late200 connection and original resource snapshot only.
	var late: Dictionary = Replay.make(9001,Profile.defaults(),256800,"F-late200-fixture",{"charges":0,"progress":1})
	check("late_fixture_saved",Replay.save(late,editor.replay_path).ok)
	await press("LoadFailure")
	check("actual_load_late200_frozen_config",editor.preview_start==198 and editor.rows.size()==20 and editor.rows[editor.preview.focus_index].index==200 and int(editor.seed_control.value)==9001 and Profile.fingerprint(editor.draft)==late.fingerprint)
	editor.replay_resources.grab_focus()
	await tap(KEY_SPACE)
	check("actual_snapshot_checkbox",editor.replay_resources.button_pressed)
	await press("PlayFailure")
	var late_record := isolate("late-snapshot")
	await frames(8)
	visible_hint("late_snapshot")
	var trial: Node2D = editor.trial
	check("actual_snapshot_position_resources_bounded",trial.player.dash_charges==0 and trial.player.dash_progress==1 and trial.player.position.x+trial.course.total_offset>255808 and trial.course.chunks.size()<=8 and trial.course._holders.size()==trial.course.chunks.size(),{"global_x":trial.player.position.x+trial.course.total_offset,"dash":trial.player.dash_snapshot(),"chunks":trial.course.chunks.size(),"bodies":trial.course.find_children("*","StaticBody2D",true,false).size()})
	await shot("tool-late200-snapshot")
	await tap(KEY_F8)
	check("actual_F8_late_cleanup",not is_instance_valid(editor.trial) and editor.chrome.visible and not paused and not FileAccess.file_exists(late_record))
	root.remove_child(editor)
	editor.free()
	await frames(8)
	OS.delay_msec(150)
	var after := hashes()
	check("118_sources_and_formal_records_unchanged",before==after and frozen_matches(after) and records_before==records())
	var passed: bool = checks.all(func(row: Dictionary) -> bool:return row.passed)
	var file := FileAccess.open(OUT8+"tools-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"observations":observations,"before":before,"after":after,"records_before":records_before,"records_after":records(),"method":"Frozen actual editor, GPU fixed60, synthetic Enter/Shift/F9/Space/F8. Public selected 0/1/2 resource widgets and disclosed distance starts; isolated record override before terminal. caught terminal and seed9001 index200 resource snapshot file explicitly fixture. Actual visible Label bounds, no natural failure or input replay claim. No D30/long/legacy matrix rerun."},"\t"))
	file.close()
	quit(0 if passed else 1)
