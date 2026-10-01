extends "res://reports/v0.6/check_editor.gd"
const Replay=preload("res://scripts/tools/generation_replay.gd")
func run() -> void:
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size=Vector2i(960,540)
	root.size=Vector2i(960,540)
	var fixture:="res://reports/v0.7/workflow/"
	DirAccess.make_dir_recursive_absolute(fixture)
	var editor:=Editor.new()
	editor.default_path=fixture+"late-default.json"
	editor.replay_path=fixture+"late-failure.json"
	Profile.save_profile(Profile.defaults(),editor.default_path)
	Replay.save(Replay.make(404,Profile.defaults(),200*1280+800,"late-fixture"),editor.replay_path)
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(editor)
	await frames(4)
	var button: Button=editor.find_children("LoadFailure","Button",true,false)[0]
	button.grab_focus()
	await key(KEY_ENTER)
	check("远距离失败预览仍仅20段且包含实际200片段",editor.rows.size()==20 and editor.rows[editor.preview.focus_index].index==200 and editor.preview_start==198 and editor.details.text.contains("段200"))
	var g:=Generator.new()
	g.reset(404,editor.draft)
	for _i in 198:
		g.next()
	var same:=true
	for row in editor.rows:
		same=same and var_to_bytes(row.geometry)==var_to_bytes(g.next().geometry)
	check("远距离窗口与原同seed前缀生成相同",same)
	button=editor.find_children("PlayConnection","Button",true,false)[0]
	button.grab_focus()
	await key(KEY_ENTER)
	await frames(12)
	var trial: Node2D=editor.trial
	var global_x: float=trial.player.position.x+trial.course.total_offset
	var hint: Label=trial.ui.get_node("EditorReturnHint").get_child(0)
	check("连接试玩使用实际200编号及全球起点",trial.course.chunks.size()<=8 and global_x>200*1280-192 and global_x<200*1280 and hint.text.contains("第200段") and hint.is_visible_in_tree())
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/v0.7/editor-late-replay-960.png")
	await key(KEY_F8)
	check("远距离试玩清理且草稿窗口保留",not is_instance_valid(editor.trial) and editor.rows[editor.preview.focus_index].index==200)
	root.remove_child(editor)
	editor.queue_free()
	await frames(3)
	OS.delay_msec(150)
	var passed:=checks.all(func(c):return c.passed)
	var file:=FileAccess.open("res://reports/v0.7/late-replay-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"method":"GPU fixed60, synthetic Enter/F8, isolated failed_x=256800 fixture with frozen seed/profile. Preview is a20chunk window generated after deterministic198chunk prefix; actual connection debug start global255808, not natural run."},"\t"))
	file.close()
	print(JSON.stringify({"passed":passed,"checks":checks}))
	quit(0 if passed else 1)
