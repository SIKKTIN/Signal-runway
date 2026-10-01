extends SceneTree
const Editor=preload("res://scripts/tools/generation_editor.gd")
const Profile=preload("res://scripts/level/generation_profile.gd")
const Generator=preload("res://scripts/level/endless_generator.gd")
const Record=preload("res://scripts/level/endless_record.gd")
var checks: Array[Dictionary]=[]
func _initialize() -> void:
	call_deferred("run")
func frames(count:int) -> void:
	for _i in count:
		await physics_frame
		await process_frame
func check(name_value:String,passed:bool) -> void:
	checks.append({"name":name_value,"passed":passed})
func file_hash(path:String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
func key(code:int) -> void:
	var event:=InputEventKey.new()
	event.keycode=code
	event.pressed=true
	Input.parse_input_event(event)
	await frames(2)
	event=InputEventKey.new()
	event.keycode=code
	Input.parse_input_event(event)
	await frames(2)
func run() -> void:
	var before_formal:=file_hash(Record.DEFAULT_PATH)
	var before_legacy:=file_hash(Record.LEGACY_PATH)
	var editor:=Editor.new()
	editor.default_path="user://v06_editor_default_%d.json" % OS.get_process_id()
	Profile.save_profile(Profile.defaults(),editor.default_path)
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(editor)
	await frames(3)
	check("v4几何控件与实际预览",editor.draft.generator_revision==4 and editor.rows[2].has("geometry") and editor.controls.height_min.editable)
	check("节奏控件与恢复站元数据",editor.controls.station_min.editable and editor.controls.combo_bonus.value==200)
	var original:=var_to_bytes(editor.rows)
	editor.controls.height_min.value=64
	editor.controls.height_max.value=64
	editor.regenerate()
	check("真实几何参数变化与差异",var_to_bytes(editor.rows)!=original and editor.summary.text.contains("不同"))
	var same:=true
	var generator:=Generator.new()
	generator.reset(int(editor.seed_control.value),editor.draft)
	for row in editor.rows:
		same=same and var_to_bytes(row.geometry)==var_to_bytes(generator.next().geometry)
	check("工具20段实际几何逐项一致",same)
	editor.controls.height_min.value=64
	editor.controls.height_max.value=32
	check("坏范围阻止试玩保存",not editor.valid_draft())
	editor.set_draft(Profile.v05_defaults())
	check("旧v3显式节奏锁定",editor.draft.generator_revision==3 and not editor.controls.station_min.editable and editor.controls.height_min.editable)
	editor.set_draft(Profile.legacy_defaults())
	check("v2明确模式且几何锁定",not editor.controls.height_min.editable and editor.fingerprint_label.text.contains("旧配置"))
	editor.upgrade_draft()
	check("显式升级v4而非静默改图",editor.draft.generator_revision==4 and editor.controls.height_min.editable)
	editor.profile_name.text="v06_test_%d" % OS.get_process_id()
	editor.save_named()
	var personal:=Editor.PROFILE_DIR+"/"+editor.profile_name.text+".json"
	check("命名方案写入合法指纹",not Profile.load_profile(personal).fallback and Profile.fingerprint(Profile.load_profile(personal).profile)==Profile.fingerprint(editor.draft))
	editor.request_apply()
	check("应用必须先出现确认",editor.confirm_apply.visible and editor.confirm_apply.ok_button_text=="应用")
	editor.confirm_apply.hide()
	editor.apply_default()
	check("原子应用并保留备份",not Profile.load_profile(editor.default_path).fallback and FileAccess.file_exists(editor.default_path+".bak"))
	editor.speed_choice.select(3)
	editor.play_draft()
	await frames(24)
	check("最高速度档与生命真实接口",editor.trial.player.health==3 and editor.trial.trial_speed==380 and editor.trial.target_run_speed==380)
	await key(KEY_F9)
	check("实际F9受伤扣1并重置高速",editor.trial.player.health==2 and editor.trial.trial_speed==0 and editor.trial.target_run_speed<281)
	await frames(80)
	editor.trial.chase.front_x=-100000
	await key(KEY_F10)
	await frames(20)
	check("实际F10掉坑扣血后恢复",editor.trial.player.health==1 and editor.trial.phase=="running" and editor.trial.player.position.y<650)
	var trial_record:String=editor.trial.record_path
	await key(KEY_F8)
	check("实际F8返回并清理隔离记录",not is_instance_valid(editor.trial) and editor.chrome.visible and not FileAccess.file_exists(trial_record))
	editor.count_control.value=40
	editor.regenerate()
	var station_index:=0
	for row in editor.rows:
		if row.geometry.has("station"):
			station_index=row.index
			break
	editor.select_chunk(station_index)
	editor.play_selected()
	await frames(4)
	check("选段实际定点起跑与隔离",is_instance_valid(editor.trial) and editor.trial.run_distance>station_index*1280-120 and editor.trial.routes.completed==0 and editor.trial.generation_profile.generator_revision==4)
	await key(KEY_F8)
	check("定点F8返回",not is_instance_valid(editor.trial) and editor.chrome.visible)
	check("正式与历史成绩逐字节不变",before_formal==file_hash(Record.DEFAULT_PATH) and before_legacy==file_hash(Record.LEGACY_PATH))
	var default_path:String=editor.default_path
	editor.queue_free()
	await frames(3)
	for name_value in [personal,default_path]:
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists(name_value+suffix):
				DirAccess.remove_absolute(name_value+suffix)
	var failed:=checks.filter(func(c):return not c.passed).size()
	var file:=FileAccess.open("res://reports/v0.6/editor-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failed==0,"checks":checks,"method":"真实F9/F10/F8输入；参数/确认使用程序化控件调用，default_path与个人方案为隔离fixture，正常GPU固定步长"},"\t"))
	file.close()
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	quit(0 if failed==0 else 1)
