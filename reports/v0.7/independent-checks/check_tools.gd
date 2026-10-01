extends "res://reports/v0.5/independent-checks/check_tools.gd"
## Public editor actions, disclosed isolated fixtures; no natural-route claim.
const OUT_F := "res://reports/v0.7/independent-checks/"
const Replay=preload("res://scripts/tools/generation_replay.gd")
var observations: Array[Dictionary]=[]
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT_F+label+".png")
func hashes() -> Dictionary:
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/v0.7/version-manifest.json"))
	var result:= {}
	for row in manifest.files:
		result[row.path]=hash_or_missing("res://"+row.path)
	return result
func frozen_matches(current: Dictionary) -> bool:
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/v0.7/version-manifest.json"))
	return manifest.files.all(func(row):return current.get(row.path,"")==row.sha256)
func records() -> Dictionary:
	return {"v07":hash_or_missing(Record.DEFAULT_PATH),"v06":hash_or_missing(Record.V06_PATH),"v05":hash_or_missing(Record.V05_PATH),"earlier":hash_or_missing(Record.LEGACY_PATH),"failure":hash_or_missing(Replay.DEFAULT_PATH)}
func press(name_value: String) -> void:
	var button: Button=editor.find_children(name_value,"Button",true,false)[0]
	button.grab_focus()
	await tap(KEY_ENTER)
func isolate(label: String) -> String:
	var path: String=OUT_F+"isolated-tool-"+label+".json"
	editor._trial_record=path
	editor.trial.record_path=path
	return path
func hint_check(label_value: String,first_line: String,index: int) -> void:
	var trial: Node=editor.trial
	var panel: Control=trial.ui.get_node("EditorReturnHint")
	var label: Label=panel.get_child(0)
	var rectangle: Rect2=panel.get_global_rect()
	var actual:= {"case":label_value,"text":label.text,"visible":label.is_visible_in_tree(),"panel":str(rectangle),"label":str(label.get_global_rect()),"minimum":str(label.get_combined_minimum_size()),"global_x":trial.player.position.x+trial.course.total_offset,"floor":trial.player.is_on_floor(),"seed":trial.run_seed,"fingerprint":Profile.fingerprint(trial.generation_profile),"lifecycle":trial.course.lifecycle_state(),"static_bodies":trial.course.find_children("*","StaticBody2D",true,false).size()}
	observations.append(actual)
	check(label_value+"_three_lines_visible_and_complete",label.is_visible_in_tree() and panel.is_visible_in_tree() and label.text.contains(first_line) and label.text.contains("距离注入 · 成绩隔离") and label.text.contains("F8返回") and label.get_line_count()==3 and Rect2(0,0,960,540).encloses(rectangle) and rectangle.encloses(label.get_global_rect()) and label.size.x>=label.get_combined_minimum_size().x and label.size.y>=label.get_combined_minimum_size().y,actual)
	check(label_value+"_global_connection_start_on_real_floor",actual.global_x>index*1280-192 and actual.global_x<index*1280 and actual.floor,actual)
	check(label_value+"_active_chunks_and_collision_bounded",actual.lifecycle.chunks<=8 and actual.lifecycle.holders==actual.lifecycle.chunks and actual.static_bodies<=96,actual)
func run() -> void:
	print("V07_F_TOOL_PID ",OS.get_process_id())
	var before:=hashes()
	var records_before:=records()
	check("109_frozen_sources_match_before",frozen_matches(before))
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size=Vector2i(960,540)
	root.size=Vector2i(960,540)
	editor=load("res://scenes/tools/generation_editor.tscn").instantiate()
	editor.replay_path=OUT_F+"early-failure-fixture.json"
	root.add_child(editor)
	await frames(4)
	editor.set_draft(Profile.v06_defaults())
	check("old_v4_draft_retained_and_spatial_controls_locked",editor.draft.generator_revision==4 and not editor.controls.elevation_range.editable and editor.controls.station_min.editable)
	await press("Play")
	var legacy_path:=isolate("v4")
	await frames(4)
	check("actual_Enter_old_v4_trial_keeps_geometry_and_no_SpatialVisual",editor.trial.generation_profile.generator_revision==4 and not editor.trial.world.has_node("SpatialVisual"))
	await tap(KEY_F8)
	check("actual_F8_old_trial_cleanup_preserves_v4",not is_instance_valid(editor.trial) and editor.draft.generator_revision==4 and not FileAccess.file_exists(legacy_path))
	await press("Upgrade")
	check("actual_Enter_explicit_upgrade5_draft_only",editor.draft.generator_revision==5 and editor.controls.elevation_range.editable and editor.status.text.contains("显式升级") and before[Profile.DEFAULT_PATH.trim_prefix("res://")]==hash_or_missing(Profile.DEFAULT_PATH))
	editor.select_chunk(5)
	var fingerprint:=Profile.fingerprint(editor.draft)
	await press("PlayConnection")
	var connection_record:=isolate("early-connection")
	await frames(12)
	hint_check("early_connection","连接前起跑 · 第5段",5)
	await shot("tool-connection-960")
	var pickups: Array=[]
	editor.trial.relay_activated.connect(func(id,delay_value,count_value):pickups.append({"id":id,"delay":delay_value,"count":count_value}))
	for _i in 420:
		await frames(1)
		if not pickups.is_empty() or editor.trial.phase!="running":
			break
	var live_trial: Node=editor.trial
	var actual_hud: Node=live_trial.world.get_node("EndlessHUDVisual")
	var actual_score_label: Label=actual_hud.get("_score")
	var actual_health: int=live_trial._survival_status.presentation_state().health
	check("actual_pickup_first_process_frame_visible_score_and_life",not pickups.is_empty() and actual_score_label.is_visible_in_tree() and actual_score_label.text==str(live_trial.run_score) and actual_hud.presentation_state().score==live_trial.total_score() and actual_health==live_trial.player.health,{"pickups":pickups,"label_text":actual_score_label.text,"run_score":live_trial.run_score,"total":live_trial.total_score(),"ui_health":actual_health,"actual_health":live_trial.player.health,"elapsed":live_trial.elapsed})
	await shot("tool-first-pickup-frame-960")
	# Disclosed terminal fixture only to exercise actual isolated record serialization.
	editor.trial._queue_failure("caught")
	await frames(5)
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(connection_record))
	var scores: Dictionary=data.get("score_breakdown",{})
	check("terminal_fixture_isolated_rule7_gen5_four_parts",data.get("rules_revision")==7 and data.get("generator_revision")==5 and scores.has_all(["distance","nodes","combo","station"]) and int(data.best.score)==int(scores.distance)+int(scores.nodes)+int(scores.combo)+int(scores.station),data)
	await tap(KEY_F8)
	check("actual_F8_cleans_early_trial_keeps_draft",not is_instance_valid(editor.trial) and editor.chrome.visible and Profile.fingerprint(editor.draft)==fingerprint and not FileAccess.file_exists(connection_record))
	await press("SaveFailure")
	var saved:=Replay.load_from(editor.replay_path)
	check("actual_Enter_SaveFailure_keeps_seed_frozen_profile",saved.ok and saved.value.seed==404 and saved.value.fingerprint==fingerprint and saved.value.reason=="caught")
	# Late index200 is an explicit file fixture, not an observed natural failure.
	var late_profile:=Profile.defaults()
	late_profile.elevation_range=32
	late_profile.upper_span=3
	var late:=Replay.make(9001,late_profile,256800,"fixture-late-caught")
	editor.replay_path=OUT_F+"late-failure-fixture.json"
	check("late_fixture_saved_isolated_and_valid",Replay.save(late,editor.replay_path).ok)
	editor.seed_control.value=77
	editor.set_draft(Profile.v06_defaults())
	await press("LoadFailure")
	check("actual_Enter_LoadFailure_200_window_seed_and_fingerprint",editor.seed_control.value==9001 and Profile.fingerprint(editor.draft)==late.fingerprint and editor.preview_start==198 and editor.rows.size()==20 and editor.rows[editor.preview.focus_index].index==200 and editor.details.text.contains("段200"),{"seed":editor.seed_control.value,"fingerprint":Profile.fingerprint(editor.draft),"preview_start":editor.preview_start,"rows":editor.rows.size(),"selected_global_index":editor.rows[editor.preview.focus_index].index})
	await shot("tool-late-failure-window-960")
	await press("PlayConnection")
	var late_record:=isolate("late-connection")
	await frames(12)
	hint_check("late_connection","连接前起跑 · 第200段",200)
	check("late_trial_uses_loaded_seed_profile_and_isolated_record",editor.trial.run_seed==9001 and Profile.fingerprint(editor.trial.generation_profile)==late.fingerprint and editor.trial.record_path==late_record)
	await shot("tool-late-connection-960")
	await tap(KEY_F8)
	check("actual_F8_late_connection_cleanup_keeps_window",not is_instance_valid(editor.trial) and editor.chrome.visible and editor.rows[editor.preview.focus_index].index==200 and not FileAccess.file_exists(late_record))
	await press("PlayFailure")
	var replay_record:=isolate("late-replay")
	await frames(8)
	hint_check("late_replay","失败连接前起跑",200)
	await shot("tool-late-replay-960")
	await tap(KEY_F8)
	check("actual_F8_replay_clean_and_same_config",not is_instance_valid(editor.trial) and not paused and Profile.fingerprint(editor.draft)==late.fingerprint and not FileAccess.file_exists(replay_record))
	root.remove_child(editor)
	editor.free()
	await frames(8)
	OS.delay_msec(150)
	var after:=hashes()
	check("109_sources_default_and_formal_records_unchanged",before==after and frozen_matches(after) and records_before==records())
	var file:=FileAccess.open(OUT_F+"tools-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":checks.all(func(row):return row.passed),"checks":checks,"observations":observations,"before":before,"after":after,"records_before":records_before,"records_after":records(),"method":"Independent frozen v07 editor, actual synthetic Enter/F8. Public draft snapshots, explicit caught terminal and isolated late index200 failure file are fixtures. Connection/replay starts deliberately inject position/distance, fully visible; no natural/human experience claim. GPU fixed60 accelerated. No default apply/save writes; formal record missing remains missing. Runtime bodies counted after discarded prefix reconstruction."},"\t"))
	file.close()
	quit(0 if checks.all(func(row):return row.passed) else 1)
