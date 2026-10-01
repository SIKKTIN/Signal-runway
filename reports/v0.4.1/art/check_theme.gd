extends SceneTree
const OUT := "res://reports/v0.4.1/art/"
var surface: Control
var theme: Theme
var input: LineEdit

func _initialize() -> void:
	call_deferred("run")

func label(parent: Node, text: String, variation := "") -> Label:
	var node := Label.new()
	node.text = text
	node.theme_type_variation = variation
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node)
	return node

func panel(parent: Node, variation: String) -> VBoxContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = variation
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var column := VBoxContainer.new()
	card.add_child(column)
	return column

func button(parent: Node, text: String, primary := false) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 32
	if primary:
		node.theme_type_variation = "ToolPrimary"
	parent.add_child(node)
	return node

func build() -> void:
	surface = Control.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.theme = theme
	root.add_child(surface)
	var background := ColorRect.new()
	background.color = Color("18212b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	surface.add_child(margin)
	var body := VBoxContainer.new()
	margin.add_child(body)
	label(body, "信号跑道  /  地图工具控件主题", "ToolTitle")
	label(body, "主题样例：中文、输入、选中、警告和焦点。正式编辑器行为由制作人接入。", "ToolMuted")
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	var normal := panel(row, "")
	label(normal, "正常  /  参数与列表", "ToolTitle")
	label(normal, "地图种子  ·  输入框获得键盘焦点")
	input = LineEdit.new()
	input.text = "43127"
	normal.add_child(input)
	label(normal, "预览片段数")
	var count := SpinBox.new()
	count.min_value = 4
	count.max_value = 120
	count.value = 20
	normal.add_child(count)
	var choice := OptionButton.new()
	choice.add_item("默认工业跑道")
	choice.add_item("个人配置")
	normal.add_child(choice)
	var locked := CheckBox.new()
	locked.text = "安全片段 A  ·  锁定启用"
	locked.button_pressed = true
	locked.disabled = true
	normal.add_child(locked)
	button(normal, "重新生成", true)
	var selected := panel(row, "ToolSelected")
	label(selected, "已选中  /  relay_b", "ToolTitle")
	label(selected, "中继上路 · 蹬墙 · 1280 单位")
	label(selected, "当前片段采用双路线轮廓。选择边框表示正在查看详情，不代表可碰撞地形。", "ToolMuted")
	var list := ItemList.new()
	list.custom_minimum_size.y = 104
	list.add_item("safe_a  /  安全开局")
	list.add_item("relay_b  /  中继分支")
	list.add_item("rhythm_a  /  连续节奏")
	list.select(1)
	selected.add_child(list)
	button(selected, "整体适配")
	button(selected, "不可用操作").disabled = true
	var warning := panel(row, "ToolWarning")
	label(warning, "注意  /  约束与差异", "ToolTitle")
	label(warning, "当前候选不足，使用已验证安全兜底。", "ToolWarningText")
	label(warning, "规则满足只说明结构符合约束；动作可达和玩家体验需要实际验证。", "ToolMuted")
	var error := panel(warning, "ToolError")
	label(error, "无效配置", "ToolErrorText")
	label(error, "中继间隔必须在 4–8 段内。", "ToolMuted")
	button(warning, "查看排除原因")
	var actions := HFlowContainer.new()
	body.add_child(actions)
	for text in ["保存方案", "加载方案", "恢复默认", "当前配置试玩", "应用工程默认"]:
		button(actions, text)
	label(body, "样例不执行生成、保存或应用。输入及警告文字保持15 / 14 px。", "ToolMuted")
	input.grab_focus()

func frames(count: int) -> void:
	for _i in count:
		await process_frame
		await physics_frame

func run() -> void:
	theme = load("res://scenes/tools/generation_editor_theme.tres")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	var checks := []
	for size in [Vector2i(1280,720), Vector2i(960,540)]:
		root.size = size
		build()
		await frames(5)
		var overflow := []
		for control in surface.find_children("*", "Control", true, false):
			if control.is_visible_in_tree() and control.size.x > 0:
				var rect: Rect2 = control.get_global_rect()
				if rect.position.x < -1 or rect.end.x > size.x + 1 or rect.position.y < -1 or rect.end.y > size.y + 1:
					overflow.append(control.get_class())
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT + "theme-%dx%d.png" % [size.x,size.y])
		checks.append({"size": str(size), "logical_size": str(root.get_visible_rect().size), "overflow": overflow, "passed": overflow.is_empty()})
		root.remove_child(surface)
		surface.free()
	checks.append({"check": "chinese_font_and_size", "passed": theme.default_font is SystemFont and theme.default_font_size == 15 and theme.default_font.get_string_size("地图生成参数", HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x > 60})
	checks.append({"check": "standalone_resource", "passed": theme.has_stylebox("panel", "ToolError") and theme.get_type_variation_base("ToolPrimary") == "Button"})
	var file := FileAccess.open(OUT + "theme-check.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "passed": checks.all(func(row): return row.passed), "scope": "Theme controls sample only; actual editor not yet checked.", "renderer": RenderingServer.get_video_adapter_name()}, "\t"))
	file.close()
	await frames(5)
	quit(0 if checks.all(func(row): return row.passed) else 1)
