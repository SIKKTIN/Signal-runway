extends "res://reports/v0.5/independent-checks/check_tools.gd"
## Only v4 upgrade/selected trial/debug/return and isolated record checks.
const OUT_F := "res://reports/v0.6/independent-checks/"
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT_F+label+".png")
func hashes() -> Dictionary:
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/v0.6/version-manifest.json"))
	var result:= {}
	for row in manifest.files:
		result[row.path]=hash_or_missing("res://"+row.path)
	return result
func records() -> Dictionary:
	return {"v06":hash_or_missing(Record.DEFAULT_PATH),"v05":hash_or_missing(Record.V05_PATH),"earlier":hash_or_missing(Record.LEGACY_PATH)}
func press_button(name_value: String) -> void:
	var button: Button=editor.find_children(name_value,"Button",true,false)[0]
	button.grab_focus()
	await tap(KEY_ENTER)
func isolate_trial(label: String) -> String:
	var path: String=OUT_F+"isolated-tool-"+label+".json"
	editor._trial_record=path
	editor.trial.record_path=path
	return path
func run() -> void:
	print("F_TOOL_PID ",OS.get_process_id())
	var before:=hashes()
	var records_before:=records()
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size=Vector2i(960,540)
	root.size=Vector2i(1280,720)
	editor=load("res://scenes/tools/generation_editor.tscn").instantiate()
	root.add_child(editor)
	await frames(4)
	check("actual_v4_default_controls_lock_unused_structures",editor.draft.generator_revision==4 and editor.controls.spike.enabled.disabled and not editor.controls.spike.weight.editable and not editor.controls.stage_distance.editable and editor.controls.phase_one.editable)
	editor.set_draft(Profile.legacy_defaults())
	check("v2_draft_keeps_legacy_geometry_and_version",editor.draft.generator_revision==2 and not editor.controls.height_min.editable and not editor.controls.phase_one.editable)
	editor.set_draft(Profile.v05_defaults())
	check("v3_draft_keeps_original_generation",editor.draft.generator_revision==3 and editor.controls.height_min.editable and not editor.controls.phase_one.editable)
	await press_button("Play")
	var legacy_record:=isolate_trial("v3")
	await frames(5)
	check("v3_trial_does_not_install_v4_route_visuals",editor.trial.generation_profile.generator_revision==3 and not editor.trial.world.has_node("RouteVisual") and not is_instance_valid(editor.trial._route_status))
	await tap(KEY_F8)
	check("actual_F8_returns_legacy_draft",not is_instance_valid(editor.trial) and editor.draft.generator_revision==3 and not FileAccess.file_exists(legacy_record))
	await press_button("Upgrade")
	check("actual_Upgrade_button_is_explicit_draft_only",editor.draft.generator_revision==4 and editor.status.text.contains("显式升级") and editor.controls.phase_one.editable)
	editor.count_control.value=30
	editor.regenerate()
	var selected: Dictionary=editor.rows.filter(func(row):return row.geometry.has("challenge"))[0]
	editor.select_chunk(int(selected.index))
	editor.speed_choice.select(2)
	var draft_hash:=Profile.fingerprint(editor.draft)
	await shot("tool-v4-selected-preview-1280")
	await press_button("PlaySelected")
	var path:=isolate_trial("selected")
	var trial: Node2D=editor.trial
	await frames(25)
	var notice_text: String=trial.ui.notice.text
	check("selected_trial_is_explicit_debug_start",trial.player.position.x>selected.index*1280 and trial.run_distance>selected.index*1280-96 and notice_text.contains("定点") and trial.trial_speed==330,notice_text)
	await tap(KEY_F9)
	check("actual_F9_decrements_once_resets_speed",trial.player.health==2 and trial.player.hurt_count==1 and trial.target_run_speed<281 and trial.player.velocity.x<281 and trial.trial_speed==0)
	await tap(KEY_F9)
	check("actual_F9_invulnerability_deduplicates",trial.player.health==2 and trial.player.hurt_count==1)
	await shot("tool-debug-hurt-1280")
	await frames(82)
	check("actual_post_hurt_forward_rebuilds_speed",trial.player.health==2 and trial.target_run_speed>280.5 and trial.player.invulnerable_remaining==0)
	await tap(KEY_F10)
	await frames(18)
	check("actual_F10_recovers_confirmed_safe_point",trial.phase=="running" and trial.player.health==1 and trial.player.hurt_count==2 and trial.player.position.y<600 and trial.fall_recovery_remaining==0)
	root.size=Vector2i(960,540)
	await frames(2)
	await shot("tool-debug-recovered-960")
	var hint: Control=trial.ui.get_node("EditorReturnHint")
	check("960_debug_F8_and_route_status_clear",not hint.get_global_rect().intersects(trial._route_status.get_global_rect()) and not trial._survival_status.get_global_rect().intersects(trial._route_status.get_global_rect()))
	# Explicit caught fixture exercises tool record metadata/result. Not natural route failure.
	trial.player.die("caught")
	await frames(4)
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var detail: Dictionary=data.get("score_breakdown",{})
	check("isolated_v06_record_has_four_score_parts",data.get("rules_revision",0)==6 and data.get("generator_revision",0)==4 and detail.has_all(["distance","nodes","combo","station"]) and int(data.best.score)==int(detail.distance)+int(detail.nodes)+int(detail.combo)+int(detail.station),data)
	await shot("tool-isolated-result-960")
	await tap(KEY_ENTER)
	check("actual_result_retry_keeps_seed_and_record",trial.phase=="running" and trial.run_seed==int(editor.seed_control.value) and trial.best_score==int(data.best.score))
	await tap(KEY_ESCAPE)
	check("actual_trial_pause_before_return",trial.phase=="paused" and paused)
	await tap(KEY_F8)
	check("actual_F8_cleans_paused_trial_preserves_draft",not is_instance_valid(editor.trial) and not paused and editor.chrome.visible and Profile.fingerprint(editor.draft)==draft_hash and not FileAccess.file_exists(path))
	await shot("tool-v4-return-960")
	root.remove_child(editor)
	editor.free()
	await frames(8)
	OS.delay_msec(150)
	var after:=hashes()
	check("105_sources_default_and_real_records_unchanged",before==after and records_before==records())
	var passed: bool=checks.all(func(row):return row.passed)
	var file:=FileAccess.open(OUT_F+"tools-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"before":before,"after":after,"records_before":records_before,"records_after":records(),"method":"Small public editor workflows, actual synthetic Enter/F9/F10/Esc/F8. v2/v3 snapshots and explicit upgrade are tool draft fixtures; PlaySelected is explicitly positional/distance/330-speed debug injection and isolated scores. Caught terminal is explicit fixture. Fixed60 GPU accelerated game time; no natural-route or human experience claim for these tool checks. No default/save writes."},"\t"))
	file.close()
	quit(0 if passed else 1)
