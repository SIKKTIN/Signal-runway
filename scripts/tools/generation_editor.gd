extends Control
const Profile = preload("res://scripts/level/generation_profile.gd")
const Generator = preload("res://scripts/level/endless_generator.gd")
const Library = preload("res://scripts/level/endless_library.gd")
const Preview = preload("res://scripts/tools/map_preview.gd")
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
var speed_choice: OptionButton
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
	label(params, "片段开关 / 合格候选权重")
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
	button(debug_row,"升级v3草稿",upgrade_draft,"Upgrade")
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
		controls[key].editable = draft.generator_revision == 3
	for id in Library.ids():
		controls[id].enabled.button_pressed = draft.templates[id].enabled
		controls[id].weight.value = draft.templates[id].weight
	updating = false
	regenerate()
func read_draft() -> Dictionary:
	var value := draft.duplicate(true)
	for key in ["stage_distance", "relay_min", "relay_max"]:
		value[key] = controls[key].value
	if value.generator_revision == 3:
		for key in ["height_min","height_max","gap_min","gap_max"]:
			value[key] = controls[key].value
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
	for _i in int(count_control.value):
		rows.append(g.next())
	preview.set_rows(rows)
	fingerprint_label.text = "规则v%d%s · 草稿 %s · 工程 %s" % [draft.generator_revision," 旧配置模式，几何锁定" if draft.generator_revision==2 else " 立体参数化",Profile.fingerprint(draft),Profile.fingerprint(baseline)]
	var original := Generator.new()
	original.reset(int(seed_control.value), baseline)
	var changed_segments := 0
	var distribution := {}
	var fallback := 0
	for row in rows:
		changed_segments += int(var_to_bytes(original.next().geometry) != var_to_bytes(row.geometry))
		distribution[row.template_id] = distribution.get(row.template_id, 0) + 1
		fallback += int(row.reason.begins_with("安全兜底"))
	summary.text = "%d段 / %.0f距离 · 与工程默认同seed %d段不同 · 安全兜底%d次\n分布 %s" % [rows.size(), rows.size() * Library.LENGTH, changed_segments, fallback, JSON.stringify(distribution)]
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
	for key in ["stage_distance", "relay_min", "relay_max","height_min","height_max","gap_min","gap_max"]:
		if draft.get(key) != baseline.get(key):
			changes.append("%s: %s→%s" % [key, baseline.get(key), draft.get(key)])
	for id in Library.ids():
		if draft.templates[id] != baseline.templates[id]:
			changes.append(id + ": " + JSON.stringify(draft.templates[id]))
	details.text = "段%d · %s · %s · 入口/出口地面448 · 长度1280\n原因：%s\n合格候选：%s\n排除：%s\n几何：%d地面 / %d平台 / %d墙 / %d坑 / %d尖刺 / %d节点\n配置差异：%s" % [index, r.template_id, r.category, r.reason, ", ".join(r.candidates), JSON.stringify(r.excluded), d.floors.size(), d.platforms.size(), d.walls.size(), d.gaps.size(), d.spikes.size(), d.relays.size(), "；".join(changes) if not changes.is_empty() else "无"]
	details.text += "\n结构：%s · 变体%d · 参数%s\n路线/安全表面：%d · %s\n六立体结构的发布范围有三档动作检查；当前配置压力需试玩。" % [d.get("structure","旧固定片段"),d.get("variant",0),JSON.stringify(d.get("parameters",{})),d.get("routes",[]).size(),d.get("validation","旧版固定几何")]

func upgrade_draft() -> void:
	var value := Profile.defaults()
	for key in ["stage_distance","relay_min","relay_max","templates"]:
		value[key] = draft[key]
	set_draft(value)
	message("已升级为v3草稿；地图几何将变化，工程默认需另行应用")
func toggle_single() -> void:
	preview.single = not preview.single
	preview.focus_on(preview.focus_index)
	preview.queue_redraw()
func new_seed() -> void:
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
	trial.trial_speed = [0.0,280.0,330.0,380.0][speed_choice.selected]
	chrome.hide()
	var hint := PanelContainer.new()
	hint.name = "EditorReturnHint"
	hint.theme = theme
	hint.theme_type_variation = "ToolSelected"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trial.ui.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -188
	hint.offset_top = -44
	hint.offset_right = -16
	hint.offset_bottom = -12
	var hint_text := Label.new()
	hint_text.text = "工具试玩 · F8返回"
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
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(_trial_record + suffix):
				DirAccess.remove_absolute(_trial_record + suffix)
		chrome.show()
		message("已返回草稿，试玩配置和正式纪录分离")
func _input(event: InputEvent) -> void:
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
func _exit_tree() -> void:
	get_tree().paused = false
	if not _trial_record.is_empty():
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(_trial_record + suffix):
				DirAccess.remove_absolute(_trial_record + suffix)
