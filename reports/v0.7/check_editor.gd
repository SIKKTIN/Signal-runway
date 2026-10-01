extends "res://reports/v0.6/check_editor.gd"
const Replay=preload("res://scripts/tools/generation_replay.gd")
func press(editor: Node,name_value: String) -> void:
	var b: Button=editor.find_children(name_value,"Button",true,false)[0]
	b.grab_focus()
	await key(KEY_ENTER)
func run() -> void:
	print("V07_EDITOR_PID ",OS.get_process_id())
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size=Vector2i(960,540)
	root.size=Vector2i(960,540)
	var formal_before:=file_hash(Record.DEFAULT_PATH)
	var old_before:=file_hash(Record.V06_PATH)
	var default_before:=file_hash(Profile.DEFAULT_PATH)
	var editor:=Editor.new()
	var fixture:="res://reports/v0.7/workflow/"
	DirAccess.make_dir_recursive_absolute(fixture)
	editor.default_path=fixture+"editor-default.json"
	editor.replay_path=fixture+"failure-seed.json"
	Profile.save_profile(Profile.defaults(),editor.default_path)
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(editor)
	await frames(4)
	check("v5空间控件与多边形预览",editor.draft.generator_revision==5 and editor.controls.elevation_step.editable and editor.controls.space_bridge.editable and editor.rows[2].geometry.has("polygons"))
	editor.controls.elevation_range.value=32
	editor.controls.upper_span.value=3
	editor.controls.space_bridge.value=4
	editor.regenerate()
	check("新参数归一化不丢失",editor.draft.elevation_range==32 and editor.draft.upper_span==3 and editor.draft.spatial_weights.bridge==4)
	var clone:=Generator.new()
	clone.reset(int(editor.seed_control.value),editor.draft)
	var metadata_match:=true
	for row in editor.rows:
		metadata_match=metadata_match and var_to_bytes(row.geometry)==var_to_bytes(clone.next().geometry)
	check("20段最终生成几何和工具相同",metadata_match)
	check("新参数配置读写及备份",Profile.save_profile(editor.draft,editor.default_path).ok and Profile.load_profile(editor.default_path).profile.upper_span==3 and FileAccess.file_exists(editor.default_path+".bak"))
	for old in [Profile.legacy_defaults(),Profile.v05_defaults(),Profile.v06_defaults()]:
		editor.set_draft(old)
		check("旧%d保持版本且空间锁定"%old.generator_revision,editor.draft.generator_revision==old.generator_revision and not editor.controls.elevation_range.editable and editor.controls.station_min.editable==(old.generator_revision==4))
	await press(editor,"Upgrade")
	check("真实Enter显式升级5且未写默认",editor.draft.generator_revision==5 and Profile.load_profile(editor.default_path).profile.upper_span==3)
	editor.select_chunk(5)
	await press(editor,"PlayConnection")
	await frames(12)
	var trial: Node2D=editor.trial
	var hint_panel: Control=trial.ui.get_node("EditorReturnHint")
	var hint: Label=hint_panel.get_child(0)
	check("连接前安全起跑与完整可见注入说明",trial.player.position.x>5*1280-192 and trial.player.position.x<5*1280 and trial.player.is_on_floor() and hint.is_visible_in_tree() and hint.text.contains("连接前起跑") and hint.text.contains("成绩隔离") and Rect2(0,0,960,540).encloses(hint_panel.get_global_rect()))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/v0.7/editor-connection-960.png")
	var frozen: Dictionary=trial.generation_profile.duplicate(true)
	trial._queue_failure("caught")
	await frames(4)
	var isolated: String=trial.record_path
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(isolated))
	check("隔离成绩为规则7生成5",data.get("rules_revision")==7 and data.get("generator_revision")==5 and data.get("score_breakdown",{}).has("distance"))
	await key(KEY_F8)
	check("真实F8清理试玩成绩并保留草稿",not is_instance_valid(editor.trial) and editor.chrome.visible and not FileAccess.file_exists(isolated) and not editor.last_failure.is_empty())
	await press(editor,"SaveFailure")
	var saved:=Replay.load_from(editor.replay_path)
	check("失败种子保存冻结配置和指纹",saved.ok and var_to_bytes(Profile.normalized(saved.value.profile))==var_to_bytes(Profile.normalized(frozen)) and saved.value.fingerprint==Profile.fingerprint(frozen))
	editor.seed_control.value=77
	editor.set_draft(Profile.v06_defaults())
	await press(editor,"LoadFailure")
	check("失败种子加载恢复种子配置定位",editor.seed_control.value==saved.value.seed and Profile.fingerprint(editor.draft)==saved.value.fingerprint and editor.rows[editor.preview.focus_index].index==int(saved.value.failed_x/1280))
	await press(editor,"PlayFailure")
	await frames(4)
	check("失败定位试玩仍隔离且可见",editor.trial.record_path!=Record.DEFAULT_PATH and editor.trial.ui.get_node("EditorReturnHint").get_child(0).text.contains("失败连接前"))
	await key(KEY_F8)
	var bad: Dictionary=saved.value.duplicate(true)
	bad.fingerprint="000000000000"
	var prior_hash:=file_hash(editor.replay_path)
	check("坏指纹拒绝且原文件保留",not Replay.save(bad,editor.replay_path).ok and file_hash(editor.replay_path)==prior_hash)
	check("正式配置和新旧成绩不污染",default_before==file_hash(Profile.DEFAULT_PATH) and formal_before==file_hash(Record.DEFAULT_PATH) and old_before==file_hash(Record.V06_PATH))
	root.remove_child(editor)
	editor.queue_free()
	await frames(3)
	OS.delay_msec(150)
	var failed:=checks.filter(func(c):return not c.passed)
	var file:=FileAccess.open("res://reports/v0.7/editor-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failed.is_empty(),"checks":checks,"method":"GPU fixed60 synthetic Enter/F8, actual editor widgets. Isolated default/replay fixtures and explicitly queued caught terminal to test real failure serialization; connection/replay are disclosed debug position/distance injections, not natural routes. No production default/formal records writes."},"\t"))
	file.close()
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	quit(0 if failed.is_empty() else 1)
