extends Control
const Profile = preload("res://scripts/level/generation_profile.gd")
const Generator = preload("res://scripts/level/endless_generator.gd")
const Library = preload("res://scripts/level/endless_library.gd")
const Preview = preload("res://scripts/tools/map_preview.gd")
const Spatial = preload("res://scripts/level/spatial_library.gd")
const Replay = preload("res://scripts/tools/generation_replay.gd")
const Skill = preload("res://scripts/level/skill_library.gd")
const Main = preload("res://scenes/main/main.tscn")
const PROFILE_DIR := "user://map_editor_profiles"
var default_path := Profile.DEFAULT_PATH
var draft: Dictionary = Profile.defaults()
var baseline: Dictionary = Profile.defaults()
var rows: Array[Dictionary] = []
var controls := {}
var seed_control: SpinBox
var count_control: SpinBox
var profile_name: LineEdit
var profiles: OptionButton
var preview: Control
var details: RichTextLabel
var status: Label
var summary: Label
var fingerprint_label: Label
var confirm_apply: ConfirmationDialog
var chrome: VBoxContainer
var trial: Node2D
var updating := false
var _debounce: Timer
var _trial_record := ""
var preview_start := 0
var replay_path := Replay.DEFAULT_PATH
var last_failure: Dictionary={}
var _trial_failure_saved:=false
var speed_choice: OptionButton
var dash_choice: OptionButton
var replay_resources: CheckBox
var prototype_view: Control
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var background := ColorRect.new()
	background.color = Color("0b141c")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	if ResourceLoader.exists("res://scenes/tools/generation_editor_theme.tres"):
		theme = load("res://scenes/tools/generation_editor_theme.tres")
	else:
		theme = load("res://scenes/ui/skins/chase_theme.tres")
	_build_ui()
	_debounce = Timer.new()
	_debounce.one_shot = true
	_debounce.wait_time = 0.15
	_debounce.timeout.connect(regenerate)
	add_child(_debounce)
	var loaded := Profile.load_profile(default_path)
	baseline = loaded.profile
	set_draft(baseline)
	_refresh_profiles()
	if loaded.fallback:
		message("工程默认不可用：" + "；".join(loaded.errors), false)
func button(parent: Node, text: String, callback: Callable, id: String) -> Button:
	var b := Button.new()
	b.name = id
	if id in ["Generate", "Play"]:
		b.theme_type_variation = "ToolPrimary"
	b.text = text
	b.pressed.connect(callback)
	parent.add_child(b)
	return b
func label(parent: Node, text: String) -> Label:
	var l := Label.new()
	l.text = text
	parent.add_child(l)
	return l
func spin(parent: Node, low: float, high: float, step_value: float, value: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = low
	s.max_value = high
	s.step = step_value
	s.value = value
	s.custom_minimum_size.x = 75
	parent.add_child(s)
	return s
func _build_ui() -> void:
	chrome = VBoxContainer.new()
	chrome.name = "EditorChrome"
	chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chrome.offset_left = 12
	chrome.offset_top = 10
	chrome.offset_right = -12
	chrome.offset_bottom = -10
	add_child(chrome)
	var top := HBoxContainer.new()
	chrome.add_child(top)
	label(top, "地图生成编辑器")
	label(top, "种子")
	seed_control = spin(top, 0, 2147483647, 1, 404)
	seed_control.custom_minimum_size.x = 120
	seed_control.name = "Seed"
	label(top, "段数")
	count_control = spin(top, 4, 120, 1, 20)
	button(top, "重新生成", regenerate, "Generate")
	button(top, "随机种子", new_seed, "NewSeed")
	button(top, "整体适配", func(): preview.fit_all(), "Fit")
	fingerprint_label = label(chrome, "")
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chrome.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.x = 270
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var params := VBoxContainer.new()
	params.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(params)
	label(params, "生成规则（草稿）")
	for item in [["stage_distance", "阶段距离", 4200, 16800, 100, 8400], ["relay_min", "中继最小段距", 4, 8, 1, 5], ["relay_max", "中继最大段距", 4, 8, 1, 6]]:
		label(params, item[1])
		var s := spin(params, item[2], item[3], item[4], item[5])
		s.name = item[0]
		controls[item[0]] = s
		s.value_changed.connect(func(_v): changed())
	label(params, "立体几何（16单位档位）")
	for item in [["height_min","高差最小",32,64,32],["height_max","高差最大",32,64,64],["gap_min","平台间距最小",64,96,64],["gap_max","平台间距最大",64,96,96]]:
		label(params,item[1])
		var s := spin(params,item[2],item[3],16,item[4])
		controls[item[0]] = s
		s.value_changed.connect(func(_v): changed())
	label(params, "v0.7 连续空间")
	for item in [["elevation_step","跨段净高差",32,64,16,64],["elevation_range","地面高度范围±",32,64,16,64],["upper_span","高路片段长度",2,3,1,2]]:
		label(params,item[1])
		var s:=spin(params,item[2],item[3],item[4],item[5])
		controls[item[0]]=s
		s.value_changed.connect(func(_v):changed())
	for id in Spatial.NAMES:
		label(params,Spatial.NAMES[id]+"权重")
		var s:=spin(params,1 if id=="slope" else 0,10,1,2)
		controls["space_"+id]=s
		s.value_changed.connect(func(_v):changed())
	label(params,"v0.8技能：冲刺0.20秒/800，按M1冻结")
	for spec in [["skill_weight","技能权重（0关闭）",0,3,2],["skill_limit","技能频率档（1疏/2密）",1,2,1]]:
		label(params,spec[1])
		var s:=spin(params,spec[2],spec[3],1,spec[4])
		controls[spec[0]]=s
		s.value_changed.connect(func(_v):changed())
	label(params, "片段开关 / 合格候选权重")
	label(params,"v0.6 段落节奏与奖励")
	for item in [["phase_one","进阶距离",5000,20000,1000,10000],["phase_two","持续挑战距离",20000,60000,1000,30000],["challenge_weight","挑战基础权重",1,3,1,1],["challenge_limit","最多连续挑战",1,2,1,2],["station_min","恢复站最小段距",16,24,1,16],["station_max","恢复站最大段距",16,24,1,24],["combo_bonus","连段完成分",100,400,100,200],["station_bonus","恢复站积分",100,400,100,200]]:
		label(params,item[1])
		var s:=spin(params,item[2],item[3],item[4],item[5])
		controls[item[0]]=s
		s.value_changed.connect(func(_v):changed())
	for id in Library.ids():
		var row := HBoxContainer.new()
		params.add_child(row)
		var check := CheckBox.new()
		check.text = id
		check.name = id + "Enabled"
		check.custom_minimum_size.x = 135
		check.disabled = id in Profile.LOCKED
		check.tooltip_text = "安全/奖励保障锁定" if check.disabled else "仅影响合格候选；不关闭安全规则"
		row.add_child(check)
		var weight := spin(row, 1 if id in Profile.LOCKED else 0.1, 10, 0.1, 1)
		weight.name = id + "Weight"
		controls[id] = {"enabled": check, "weight": weight}
		check.toggled.connect(func(_v): changed())
		weight.value_changed.connect(func(_v): changed())
	var middle := VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(middle)
	preview = Preview.new()
	preview.name = "MapPreview"
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.custom_minimum_size = Vector2(380, 120)
	preview.selected.connect(select_chunk)
	middle.add_child(preview)
	var nav := HBoxContainer.new()
	middle.add_child(nav)
	button(nav, "上一段", func(): select_chunk(maxi(0, preview.focus_index - 1)), "Previous")
	button(nav, "下一段", func(): select_chunk(mini(rows.size() - 1, preview.focus_index + 1)), "Next")
	button(nav, "单段 / 连续", toggle_single, "Single")
	button(nav,"选段试玩",play_selected,"PlaySelected")
	button(nav,"连接试玩",play_connection,"PlayConnection")
	summary = label(middle, "")
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details = RichTextLabel.new()
	details.name = "Details"
	details.custom_minimum_size.y = 80
	details.scroll_active = true
	middle.add_child(details)
	var debug_row := HBoxContainer.new()
	chrome.add_child(debug_row)
	label(debug_row,"试玩速度")
	speed_choice = OptionButton.new()
	for item in ["自然加速","基础280","过渡330","最高380"]:
		speed_choice.add_item(item)
	debug_row.add_child(speed_choice)
	label(debug_row,"试玩：F9受伤 · F10掉坑 · F8返回")
	button(debug_row,"升级v6草稿",upgrade_draft,"Upgrade")
	var resources_row:=HBoxContainer.new()
	chrome.add_child(resources_row)
	label(resources_row,"试玩资源")
	dash_choice=OptionButton.new()
	dash_choice.name="DashResources"
	for i in 3:
		dash_choice.add_item("%d次冲刺（注入）"%i,i)
	dash_choice.select(1)
	resources_row.add_child(dash_choice)
	replay_resources=CheckBox.new()
	replay_resources.name="ReplayResources"
	replay_resources.text="失败复盘用原资源快照（注入）"
	resources_row.add_child(replay_resources)
	button(resources_row,"三段玩法原型",play_prototypes,"Prototypes")
	var actions := HBoxContainer.new()
	chrome.add_child(actions)
	profile_name = LineEdit.new()
	profile_name.name = "ProfileName"
	profile_name.placeholder_text = "方案名：字母/数字/中文"
	profile_name.custom_minimum_size.x = 180
	actions.add_child(profile_name)
	button(actions, "保存方案", save_named, "SaveProfile")
	profiles = OptionButton.new()
	profiles.name = "Profiles"
	profiles.custom_minimum_size.x = 150
	actions.add_child(profiles)
	button(actions, "加载方案", load_named, "LoadProfile")
	button(actions, "恢复内置默认", func(): set_draft(Profile.defaults()), "Reset")
	var actions2 := HBoxContainer.new()
	chrome.add_child(actions2)
	button(actions2, "100种子结构检查", batch_check, "Validate")
	button(actions2, "当前草稿试玩 · F8返回", play_draft, "Play")
	button(actions2, "应用工程默认…", request_apply, "Apply")
	button(actions2, "加载上次默认备份", load_backup, "Backup")
	var replay_row:=HBoxContainer.new()
	chrome.add_child(replay_row)
	button(replay_row,"保存本次失败种子",save_failure,"SaveFailure")
	button(replay_row,"加载最近失败种子",load_failure,"LoadFailure")
	button(replay_row,"失败连接前试玩",play_failure,"PlayFailure")
	status = label(chrome, "结构检查不代表跳跃可达；试玩使用隔离纪录。")
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_apply = ConfirmationDialog.new()
	confirm_apply.title = "应用为工程默认"
	confirm_apply.ok_button_text = "应用"
	confirm_apply.cancel_button_text = "取消"
	confirm_apply.theme = theme
	confirm_apply.dialog_text = "将当前规则写入工程默认配置，旧文件备份为.bak。\n新局使用新几何参数；当前局和正式纪录保持。"
	confirm_apply.confirmed.connect(apply_default)
	add_child(confirm_apply)
func changed() -> void:
	if not updating:
		_debounce.start()
func set_draft(value: Dictionary) -> void:
	updating = true
	draft = value.duplicate(true)
	for key in ["stage_distance", "relay_min", "relay_max"]:
		controls[key].value = draft[key]
	for key in ["height_min","height_max","gap_min","gap_max"]:
		controls[key].value = draft.get(key,Profile.defaults()[key])
		controls[key].editable = draft.generator_revision >= 3
	for key in ["phase_one","phase_two","challenge_weight","challenge_limit","station_min","station_max","combo_bonus","station_bonus"]:
		controls[key].value=draft.get(key,Profile.defaults()[key])
		controls[key].editable=draft.generator_revision>=4
	for key in ["elevation_step","elevation_range","upper_span"]:
		controls[key].value=draft.get(key,Profile.defaults()[key])
		controls[key].editable=draft.generator_revision>=5
	for id in Spatial.NAMES:
		controls["space_"+id].value=draft.get("spatial_weights",Profile.defaults().spatial_weights)[id]
		controls["space_"+id].editable=draft.generator_revision>=5
	for key in ["skill_weight","skill_limit"]:
		controls[key].value=draft.get(key,Profile.defaults()[key])
		controls[key].editable=draft.generator_revision==6
	for id in Library.ids():
		controls[id].enabled.button_pressed = draft.templates[id].enabled
		controls[id].weight.value = draft.templates[id].weight
		var available: bool=draft.generator_revision<4 or id in ["safe_a","safe_b","step","gap","rhythm_a","relay_a","relay_b"]
		controls[id].enabled.disabled=id in Profile.LOCKED or not available
		controls[id].weight.editable=available and draft.generator_revision<5
		if draft.generator_revision>=5:
			controls[id].enabled.disabled=true
		controls[id].enabled.tooltip_text="v5使用空间权重与保留的节奏规则；旧模板字段供旧配置兼容" if draft.generator_revision==5 else ("v4段落库暂不选此旧结构；v2/v3保留原行为" if not available else ("安全/奖励保障锁定" if id in Profile.LOCKED else "影响本段合格候选"))
	controls.stage_distance.editable=draft.generator_revision<4
	controls.stage_distance.tooltip_text="v4/v5使用进阶/持续挑战两个距离边界；此旧阶段参数保留用于旧配置兼容" if draft.generator_revision>=4 else "旧版距离阶段边界"
	updating = false
	regenerate()
func read_draft() -> Dictionary:
	var value := draft.duplicate(true)
	for key in ["stage_distance", "relay_min", "relay_max"]:
		value[key] = controls[key].value
	if value.generator_revision >= 3:
		for key in ["height_min","height_max","gap_min","gap_max"]:
			value[key] = controls[key].value
	if value.generator_revision>=4:
		for key in ["phase_one","phase_two","challenge_weight","challenge_limit","station_min","station_max","combo_bonus","station_bonus"]:
			value[key]=controls[key].value
	if value.generator_revision>=5:
		for key in ["elevation_step","elevation_range","upper_span"]:
			value[key]=controls[key].value
		for id in Spatial.NAMES:
			value.spatial_weights[id]=controls["space_"+id].value
	if value.generator_revision==6:
		for key in ["skill_weight","skill_limit"]:
			value[key]=controls[key].value
	for id in Library.ids():
		value.templates[id] = {"enabled": controls[id].enabled.button_pressed, "weight": controls[id].weight.value}
	return value
func regenerate() -> void:
	draft = read_draft()
	var errors := Profile.validate(draft)
	if not errors.is_empty():
		message("草稿无效，预览保留上次有效结果；不可试玩或保存：" + "；".join(errors), false)
		return
	draft = Profile.normalized(draft)
	var g := Generator.new()
	g.reset(int(seed_control.value), draft)
	rows.clear()
	for _skip in preview_start:
		g.next()
	for _i in int(count_control.value):
		rows.append(g.next())
	preview.set_rows(rows)
	fingerprint_label.text = "规则v%d%s · 草稿 %s · 工程 %s" % [draft.generator_revision," 旧配置模式，几何锁定" if draft.generator_revision==2 else (" 旧v3立体，节奏锁定" if draft.generator_revision==3 else " 段落节奏"),Profile.fingerprint(draft),Profile.fingerprint(baseline)]
	var original := Generator.new()
	original.reset(int(seed_control.value), baseline)
	for _skip in preview_start:
		original.next()
	var changed_segments := 0
	var distribution := {}
	var fallback := 0
	for row in rows:
		changed_segments += int(var_to_bytes(original.next().geometry) != var_to_bytes(row.geometry))
		distribution[row.template_id] = distribution.get(row.template_id, 0) + 1
		fallback += int(row.reason.begins_with("安全兜底"))
	summary.text = "%d段 / %.0f距离 · 与工程默认同seed %d段不同 · 安全兜底%d次\n分布 %s" % [rows.size(), rows.size() * Library.LENGTH, changed_segments, fallback, JSON.stringify(distribution)]
	summary.text+="\n预览实际片段%d至%d"%[preview_start,preview_start+rows.size()-1]
	select_chunk(preview.focus_index)
	var issues := sequence_errors(rows, draft)
	message("当前预览结构通过；权重只影响合格候选，需试玩验证压力。" if issues.is_empty() else "；".join(issues), issues.is_empty())
func select_chunk(index: int) -> void:
	if rows.is_empty():
		return
	index = clampi(index, 0, rows.size() - 1)
	preview.focus_on(index)
	var r := rows[index]
	var d: Dictionary = r.get("geometry",Library.definition(r.template_id))
	var changes: Array[String] = []
	for key in ["stage_distance", "relay_min", "relay_max","height_min","height_max","gap_min","gap_max","phase_one","phase_two","challenge_weight","challenge_limit","station_min","station_max","combo_bonus","station_bonus"]:
		if draft.get(key) != baseline.get(key):
			changes.append("%s: %s→%s" % [key, baseline.get(key), draft.get(key)])
	for id in Library.ids():
		if draft.templates[id] != baseline.templates[id]:
			changes.append(id + ": " + JSON.stringify(draft.templates[id]))
	details.text = "段%d · %s · %s · 长度1280\n原因：%s\n合格候选：%s\n排除：%s\n几何：%d地面 / %d平台 / %d墙 / %d坑 / %d尖刺 / %d节点\n配置差异：%s" % [r.index, r.template_id, r.category, r.reason, ", ".join(r.candidates), JSON.stringify(r.excluded), d.floors.size(), d.platforms.size(), d.walls.size(), d.gaps.size(), d.spikes.size(), d.relays.size(), "；".join(changes) if not changes.is_empty() else "无"]
	details.text += "\n结构：%s · 变体%d · 参数%s\n路线/安全表面：%d · %s\n六立体结构的发布范围有三档动作检查；当前配置压力需试玩。" % [d.get("structure","旧固定片段"),d.get("variant",0),JSON.stringify(d.get("parameters",{})),d.get("routes",[]).size(),d.get("validation","旧版固定几何")]
	if draft.generator_revision>=4:
		details.text += "\n段落：%s · 距离阶段%d · 下一恢复站%d\n连段：%s · 恢复站：%s"%[r.segment_role,r.stage+1,r.next_station,"三个有序节点、出口奖励%d"%d.challenge.bonus if d.has("challenge") else "无","补1生命 / 积分%d，只能选一次"%d.station.bonus if d.has("station") else "无"]

	if d.has("connection"):
		details.text+="\n实际地面：%.0f→%.0f · 高路入口%.0f/出口%.0f · 前接%s/后接%s\n空间候选%s · 起跳/落点窗口%d"%[d.connection.entry_y,d.connection.exit_y,d.connection.upper_entry_y,d.connection.upper_exit_y,str(d.connection.upper_from),str(d.connection.upper_to),JSON.stringify(r.get("spatial_candidates",[])),d.jump_windows.size()]

	if d.has("skill"):
		var skill: Dictionary=d.skill
		details.text+="\n技能：%s · 入口%d次 / 路径%d次 · %d节点\n充能按两节点与容量结算，稳定主路0资源可走。"%[Skill.NAMES[skill.kind],skill.required,skill.get("dash_cost",0),skill.reward_nodes]

func upgrade_draft() -> void:
	var value := Profile.defaults()
	for key in value:
		if key!="generator_revision":
			value[key] = draft.get(key,value[key])
	set_draft(value)
	message("已显式升级为v6草稿；技能路线将变化，工程默认需另行应用")
func toggle_single() -> void:
	preview.single = not preview.single
	preview.focus_on(preview.focus_index)
	preview.queue_redraw()
func new_seed() -> void:
	preview_start=0
	var previous := int(seed_control.value)
	seed_control.value = (previous + int(Time.get_ticks_msec()) + 7919) % 2147483647
	regenerate()
func valid_draft() -> bool:
	draft = read_draft()
	var errors := Profile.validate(draft)
	if not errors.is_empty():
		message("草稿无效：" + "；".join(errors), false)
		return false
	draft = Profile.normalized(draft)
	return true
func message(text: String, okay: bool = true) -> void:
	status.text = text
	status.add_theme_color_override("font_color", Color("7ee6cf") if okay else Color("ff685c"))
func _refresh_profiles() -> void:
	DirAccess.make_dir_recursive_absolute(PROFILE_DIR)
	profiles.clear()
	var names: Array[String] = []
	for file in DirAccess.get_files_at(PROFILE_DIR):
		if file.ends_with(".json"):
			names.append(file.trim_suffix(".json"))
	names.sort()
	for name_value in names:
		profiles.add_item(name_value)
func save_named() -> void:
	if not valid_draft():
		return
	var pattern := RegEx.new()
	pattern.compile("^[A-Za-z0-9_\\-\\x{4e00}-\\x{9fff}]{1,32}$")
	var name_value := profile_name.text.strip_edges()
	if pattern.search(name_value) == null:
		message("方案名需1至32位字母、数字、中文、下划线或短横线", false)
		return
	var result := Profile.save_profile(draft, PROFILE_DIR + "/" + name_value + ".json")
	_refresh_profiles()
	message(result.message, result.ok)
func load_named() -> void:
	if profiles.selected < 0:
		message("没有已保存方案", false)
		return
	var loaded := Profile.load_profile(PROFILE_DIR + "/" + profiles.get_item_text(profiles.selected) + ".json")
	if loaded.fallback:
		message("方案加载失败，草稿保留：" + "；".join(loaded.errors), false)
	else:
		set_draft(loaded.profile)
		message("已加载个人方案；工程默认未改")
func request_apply() -> void:
	if valid_draft():
		confirm_apply.popup_centered(Vector2i(460, 160))
func apply_default() -> void:
	if not valid_draft():
		return
	var result := Profile.save_profile(draft, default_path)
	if result.ok:
		baseline = draft.duplicate(true)
		regenerate()
	message(result.message + "；只影响下一局", result.ok)
func load_backup() -> void:
	var loaded := Profile.load_profile(default_path + ".bak")
	if loaded.fallback:
		message("没有有效工程备份，草稿保留", false)
	else:
		set_draft(loaded.profile)
		message("已将备份加载为草稿；需再次应用才替换工程默认")
func play_draft() -> void:
	if not valid_draft():
		return
	_debounce.stop()
	trial = Main.instantiate()
	trial.generation_profile = draft.duplicate(true)
	_trial_record = "user://map_editor_trial_%d.json" % OS.get_process_id()
	trial.record_path = _trial_record
	add_child(trial)
	trial.start_endless(int(seed_control.value))
	if trial.player.dash_enabled:
		trial.player.dash_charges=dash_choice.get_selected_id()
		trial.player.dash_progress=0
		trial.player._dash_changed("debug_resources")
	_trial_failure_saved=false
	trial.trial_speed = [0.0,280.0,330.0,380.0][speed_choice.selected]
	chrome.hide()
	var hint := PanelContainer.new()
	hint.name = "EditorReturnHint"
	hint.theme = theme
	hint.theme_type_variation = "ToolSelected"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trial.ui.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -256
	hint.offset_top = -76
	hint.offset_right = -16
	hint.offset_bottom = -12
	var hint_text := Label.new()
	hint_text.text = "工具试玩 · 资源%d次注入\n成绩隔离 · F8返回"%dash_choice.get_selected_id()
	hint_text.tooltip_text = "试玩成绩与正式最高分隔离；F8返回当前配置。"
	hint_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_child(hint_text)
func stop_trial() -> void:
	if is_instance_valid(trial):
		get_tree().paused = false
		remove_child(trial)
		trial.queue_free()
		trial = null
		Input.action_release("jump")
		Input.action_release("dash")
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(_trial_record + suffix):
				DirAccess.remove_absolute(_trial_record + suffix)
		chrome.show()
		message("已返回草稿，试玩配置和正式纪录分离")
func play_selected() -> void:
	var index: int=int(rows[preview.focus_index].index)
	play_draft()
	if not is_instance_valid(trial):
		return
	_place_trial(index*Library.LENGTH+96,"定点起跑 · 第%d段"%index)
func _place_trial(target: float,label_value: String) -> void:
	var index:=int(target/Library.LENGTH)
	trial.course.prepare_debug_start(target)
	var definition: Dictionary={}
	for chunk in trial.course.chunks:
		if target>=chunk.origin and target<chunk.origin+chunk.length:
			definition=chunk.geometry
			break
	var y:=Spatial.ground_y(definition,fmod(target,Library.LENGTH)) if definition.has("ground_segments") else 448.0
	trial.player.recover_at(Vector2(target,y-18 if is_finite(y) else 430))
	trial._previous_position=trial.player.position
	trial.run_distance=target-trial.course.spawn_position.x
	trial.speed_distance_base=trial.run_distance
	trial.chase.reset(target)
	trial.chase.set_enabled(true)
	trial.camera.position=Vector2(maxf(target+180,480),270)
	trial.camera.reset_smoothing()
	trial.ui.set_notice("工具定点起跑 · 第%d段 · 距离注入，成绩隔离"%index,Color("ffd166"))
	var hint: PanelContainer = trial.ui.get_node("EditorReturnHint")
	hint.offset_top = -96
	var hint_text: Label = hint.get_child(0)
	hint_text.text = label_value+"\n资源%d · 距离注入 · 成绩隔离\nF8返回"%trial.player.dash_charges
func _input(event: InputEvent) -> void:
	if is_instance_valid(prototype_view) and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F8 and not is_instance_valid(prototype_view.get("trial")):
		remove_child(prototype_view)
		prototype_view.queue_free()
		prototype_view=null
		chrome.show()
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(trial) and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_F9,KEY_F10]:
		if trial.phase == "running" and not get_tree().paused:
			if event.keycode == KEY_F9:
				trial.player.take_damage("debug")
			else:
				trial.player.position.y = 660
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(trial) and event is InputEventKey and event.pressed and event.keycode == KEY_F8:
		stop_trial()
		get_viewport().set_input_as_handled()
static func sequence_errors(sequence: Array[Dictionary], settings: Dictionary) -> Array[String]:
	if settings.generator_revision>=4:
		var issues: Array[String]=[]
		var station_index:=0
		var seen_station:=false
		var previous_relay:=-1
		for i in sequence.size():
			var row:=sequence[i]
			if settings.generator_revision>=5:
				issues.append_array(Spatial.errors(row.geometry))
				if i>0:
					var a: Dictionary=sequence[i-1].geometry.connection
					var b: Dictionary=row.geometry.connection
					if a.exit_y!=b.entry_y or a.upper_to!=b.upper_from or (b.upper_from and a.upper_exit_y!=b.upper_entry_y):
						issues.append("跨段连接不一致："+str(i))
			if row.challenge_streak>settings.challenge_limit:
				issues.append("连续挑战超限："+str(i))
			if row.segment_role=="恢复":
				if ((sequence[0].index==0 or seen_station) and (i-station_index<settings.station_min or i-station_index>settings.station_max)) or (i>0 and sequence[i-1].segment_role!="缓和"):
					issues.append("恢复站间隔/入口："+str(i))
				station_index=i
				seen_station=true
			if i>0 and sequence[i-1].segment_role=="恢复" and row.segment_role!="缓和":
				issues.append("恢复站出口："+str(i))
			if row.category=="relay":
				if previous_relay>=0 and (i-previous_relay<settings.relay_min or i-previous_relay>settings.relay_max):
					issues.append("中继间隔："+str(i))
				previous_relay=i
		return issues
	var errors: Array[String] = []
	var last_relay := -1
	var wall_cost := 0
	for i in sequence.size():
		var row := sequence[i]
		if i < 2 and row.template_id != ("safe_a" if i == 0 else "safe_b"):
			errors.append("开局安全段错误")
		if i > 0 and (row.template_id == sequence[i - 1].template_id or (sequence[i - 1].difficulty >= 2 and row.category != "safe")):
			errors.append("重复/高难恢复错误：" + str(i))
		wall_cost += int(row.category == "wall" or row.template_id == "relay_b")
		if wall_cost > 1:
			errors.append("墙跳预算超过一次：" + str(i))
		if row.category == "relay":
			if last_relay >= 0 and (i - last_relay < settings.relay_min or i - last_relay > settings.relay_max):
				errors.append("中继间隔错误：" + str(i))
			last_relay = i
			wall_cost = 0
	return errors
func batch_check() -> void:
	if not valid_draft():
		return
	var errors: Array[String] = []
	for seed_value in 100:
		var g := Generator.new()
		g.reset(seed_value, draft)
		var sequence: Array[Dictionary] = []
		for _i in 200:
			sequence.append(g.next())
		errors.append_array(sequence_errors(sequence, draft))
	message("100种子×200片段结构通过；动作可达和长期压力需另外试玩验证" if errors.is_empty() else "结构失败：" + "；".join(errors.slice(0, 5)), errors.is_empty())
func play_connection() -> void:
	var index: int=int(rows[preview.focus_index].index)
	var target:=maxf(96,index*Library.LENGTH-192)
	play_draft()
	if is_instance_valid(trial):
		_place_trial(target,"连接前起跑 · 第%d段"%index)
func _process(_delta: float) -> void:
	if is_instance_valid(trial) and trial.phase=="failed" and not _trial_failure_saved:
		last_failure=Replay.make(trial.run_seed,trial.generation_profile,trial.player.position.x+trial.course.total_offset,trial.failure_reason,trial.player.dash_snapshot())
		_trial_failure_saved=true
func save_failure() -> void:
	if last_failure.is_empty():
		message("本次工具试玩尚未失败；正式游玩失败会自动保存最近种子",false)
		return
	var result:=Replay.save(last_failure,replay_path)
	message(result.message,result.ok)
func load_failure() -> void:
	var result:=Replay.load_from(replay_path)
	if not result.ok:
		message(result.message,false)
		return
	last_failure=result.value
	seed_control.value=last_failure.seed
	preview_start=maxi(0,int(last_failure.failed_x/Library.LENGTH)-2)
	count_control.value=20
	set_draft(last_failure.profile)
	select_chunk(mini(rows.size()-1,int(last_failure.failed_x/Library.LENGTH)-preview_start))
	message(result.message+" · 原失败位置%.0f · %s"%[last_failure.failed_x,last_failure.reason])
func play_failure() -> void:
	if last_failure.is_empty():
		message("先加载或保存一次实际失败种子",false)
		return
	seed_control.value=last_failure.seed
	preview_start=maxi(0,int(last_failure.failed_x/Library.LENGTH)-2)
	set_draft(last_failure.profile)
	play_draft()
	if is_instance_valid(trial):
		_place_trial(maxf(96,floor(last_failure.failed_x/Library.LENGTH)*Library.LENGTH-192),"失败连接前起跑")
		if replay_resources.button_pressed and last_failure.has("dash") and trial.player.dash_enabled:
			trial.player.dash_charges=int(last_failure.dash.charges)
			trial.player.dash_progress=int(last_failure.dash.progress)
			trial.player._dash_changed("debug_snapshot")
			var hint: Label=trial.ui.get_node("EditorReturnHint").get_child(0)
			hint.text="失败资源快照起跑\n资源%d+%d/2 · 注入/成绩隔离\nF8返回"%[trial.player.dash_charges,trial.player.dash_progress]

func play_prototypes() -> void:
	if is_instance_valid(trial) or is_instance_valid(prototype_view):
		return
	_debounce.stop()
	prototype_view=load("res://scenes/tools/dash_prototypes.tscn").instantiate()
	prototype_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(prototype_view)
	chrome.hide()

func _exit_tree() -> void:
	get_tree().paused = false
	if not _trial_record.is_empty():
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(_trial_record + suffix):
				DirAccess.remove_absolute(_trial_record + suffix)
