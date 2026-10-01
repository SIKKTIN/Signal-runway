extends "res://reports/v0.6/check_editor.gd"
const Replay=preload("res://scripts/tools/generation_replay.gd")
var observations: Dictionary={}
func press(editor: Node,name: String) -> void:
	var b: Button=editor.find_children(name,"Button",true,false)[0]
	b.grab_focus()
	await key(KEY_ENTER)
func run() -> void:
	print("V08_EDITOR_PID ",OS.get_process_id())
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size=Vector2i(960,540)
	root.size=Vector2i(960,540)
	var before:={}
	for path in [Profile.DEFAULT_PATH,Record.DEFAULT_PATH,Record.V07_PATH,Record.V06_PATH,Record.V05_PATH,Replay.DEFAULT_PATH]:
		before[path]=file_hash(path)
	var fixture:="res://reports/v0.8/workflow/editor-"
	var editor:=Editor.new()
	editor.default_path=fixture+"default.json"
	editor.replay_path=fixture+"failure.json"
	Profile.save_profile(Profile.defaults(),editor.default_path)
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(editor)
	await frames(4)
	check("default6_controls_and_valid_json",editor.draft.generator_revision==6 and editor.controls.skill_weight.editable and Profile.validate(editor.read_draft()).is_empty())
	editor.set_draft(Profile.v07_defaults())
	check("old5_preserved_skill_locked",editor.draft.generator_revision==5 and not editor.controls.skill_weight.editable and editor.controls.elevation_step.editable)
	await press(editor,"Upgrade")
	check("actual_enter_explicit_upgrade6",editor.draft.generator_revision==6 and editor.controls.skill_weight.editable)
	editor.controls.skill_weight.value=0
	editor.regenerate()
	check("weight0_removes_skill_routes",editor.rows.all(func(r):return not r.geometry.has("skill")))
	editor.controls.skill_weight.value=2
	editor.count_control.value=40
	editor.regenerate()
	var selection:=-1
	for i in editor.rows.size():
		if editor.rows[i].geometry.has("skill"):
			selection=i
			break
	check("skill_routes_present",selection>=0)
	editor.select_chunk(selection)
	check("details_actual_resource_and_reward",editor.details.text.contains("技能：") and editor.details.text.contains("节点") and editor.rows[selection].geometry.skill.stable)
	var g:=Generator.new()
	g.reset(int(editor.seed_control.value),editor.draft)
	var same:=true
	for row in editor.rows:
		same=same and var_to_bytes(row.geometry)==var_to_bytes(g.next().geometry)
	check("preview_matches_actual_generator",same)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/v0.8/editor-preview-960.png")
	for charges in 3:
		editor.dash_choice.select(charges)
		await press(editor,"PlaySelected")
		await frames(3)
		var trial: Node2D=editor.trial
		var hint: Label=trial.ui.get_node("EditorReturnHint").get_child(0)
		check("actual_selected_resources_"+str(charges),trial.player.dash_charges==charges and hint.text.contains("资源"+str(charges)) and hint.text.contains("成绩隔离") and trial.record_path!=Record.DEFAULT_PATH)
		if charges==0:
			observations.hint={"text":hint.text,"rect":str(hint.get_global_rect()),"minimum":str(hint.get_minimum_size()),"panel":str(trial.ui.get_node("EditorReturnHint").get_global_rect())}
			check("hint_three_lines_fit_visible",hint.text.split("\n").size()==3 and hint.is_visible_in_tree() and hint.get_minimum_size().x<=hint.size.x and Rect2(0,0,960,540).encloses(trial.ui.get_node("EditorReturnHint").get_global_rect()))
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://reports/v0.8/editor-resources-960.png")
		if charges==2:
			trial._queue_failure("caught")
			await frames(3)
			var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(trial.record_path))
			check("actual_terminal_record8_generator6",data.rules_revision==8 and data.generator_revision==6 and data.score_breakdown.has("nodes"))
			check("editor_captures_resource_failure",not editor.last_failure.is_empty() and editor.last_failure.schema==2 and editor.last_failure.dash.charges==2)
		var path: String=trial.record_path
		await key(KEY_F8)
		check("actual_F8_isolation_cleanup_"+str(charges),not is_instance_valid(editor.trial) and editor.chrome.visible and not FileAccess.file_exists(path))
	await press(editor,"SaveFailure")
	check("actual_failure_save_roundtrip",Replay.load_from(editor.replay_path).ok)
	Replay.save(Replay.make(9001,Profile.defaults(),256800,"late-fixture",{"charges":0,"progress":1}),editor.replay_path)
	await press(editor,"LoadFailure")
	check("actual_load_late200_window",editor.rows.size()==20 and editor.rows[editor.preview.focus_index].index==200 and editor.preview_start==198)
	editor.replay_resources.grab_focus()
	await key(KEY_SPACE)
	check("actual_checkbox_snapshot_enabled",editor.replay_resources.button_pressed)
	await press(editor,"PlayFailure")
	await frames(12)
	var trial: Node2D=editor.trial
	var hint: Label=trial.ui.get_node("EditorReturnHint").get_child(0)
	observations.late={"global_x":trial.player.position.x+trial.course.total_offset,"dash":trial.player.dash_snapshot(),"chunks":trial.course.chunks.size(),"hint":hint.text,"rect":str(hint.get_global_rect())}
	check("actual_late_resource_snapshot_and_bounded_course",hint.text.contains("资源0+1/2") and hint.text.contains("注入") and trial.course.chunks.size()<=8 and trial.player.position.x+trial.course.total_offset>255808)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/v0.8/editor-failure-snapshot-960.png")
	await key(KEY_F8)
	await press(editor,"Prototypes")
	check("prototype_hub_actual_enter",is_instance_valid(editor.prototype_view) and not editor.chrome.visible)
	var hub=editor.prototype_view
	var b: Button=hub.find_children("Shortcut","Button",true,false)[0]
	b.grab_focus()
	await key(KEY_ENTER)
	check("prototype_uses_actual_main_and_isolation",is_instance_valid(hub.trial) and hub.trial.player.dash_enabled and hub.trial.course.skill_prototype=="shortcut" and hub.trial.record_path!=Record.DEFAULT_PATH)
	await key(KEY_F8)
	check("prototype_first_F8_returns_hub",not is_instance_valid(hub.trial) and hub.chrome.visible)
	await key(KEY_F8)
	check("prototype_second_F8_returns_editor",not is_instance_valid(editor.prototype_view) and editor.chrome.visible)
	for path in before:
		check("formal_state_preserved_"+path,before[path]==file_hash(path))
	root.remove_child(editor)
	editor.queue_free()
	await frames(3)
	OS.delay_msec(150)
	var passed:=checks.all(func(c):return c.passed)
	var file:=FileAccess.open("res://reports/v0.8/editor-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"observations":observations,"formal_before":before,"method":"GPU fixed60 actual Enter/Space/F8 widgets; isolated default/failure/terminal, selected and late200 distance/resource injection fixtures. Snapshot replays resources only, not actions/health/chase. Formal files unchanged or missing observed."},"\t"))
	file.close()
	print(JSON.stringify({"passed":passed,"checks":checks.size(),"failed":checks.filter(func(c):return not c.passed)}))
	quit(0 if passed else 1)
