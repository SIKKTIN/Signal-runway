extends Node2D
## Independent visual fixture. Keys change mock snapshots, never gameplay logic.
signal endless_stats_changed(score: int, distance: float, count: int, stage: int)
signal pause_changed(paused: bool)
signal run_failed(reason: String, elapsed: float, furthest_ratio: float)
signal run_finished(elapsed: float, deaths: int, best: float)
signal mode_changed(mode: String)
signal relay_activated(relay_id: String, added_delay: float, activated_count: int)
signal relay_delay_changed(remaining: float)
var mode := "pursuit"
var phase := "running"
var level_id := "endless"
var run_seed := 43127
var run_score := 900
var run_distance := 9000.0
var relay_count := 0
var difficulty_stage := 1
var best_score := 950
var relay_delay_remaining := 0.0
var relays: Array[Dictionary] = []
var module: Node2D
var hud: CanvasLayer
var relay: Node2D
var threat: Node2D
var chase: Node
var _terrain: Node2D
var _clock := 0.0
var _template := "relay_a"
var _result: PanelContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var background := Sprite2D.new()
	background.texture = load("res://assets/visual/background_industrial.png")
	background.position = Vector2(480, 270)
	background.z_index = -10
	add_child(background)
	module = load("res://scripts/visual/endless_module_visual.gd").new()
	add_child(module)
	_terrain = Node2D.new()
	add_child(_terrain)
	hud = load("res://scripts/visual/endless_hud_visual.gd").new()
	hud.show_controls = false
	add_child(hud)
	hud.bind_flow(self)
	chase = load("res://scripts/visual/chase_preview_source.gd").new()
	add_child(chase)
	chase.sample(95, 633, "near")
	threat = load("res://scripts/visual/chase_visual.gd").new()
	add_child(threat)
	threat.bind_flow(self, chase)
	relay = load("res://scripts/visual/relay_visual.gd").new()
	add_child(relay)
	set_template(_template)
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	var control := Control.new()
	control.theme = load("res://scenes/ui/skins/chase_theme.tres")
	layer.add_child(control)
	var hint := Label.new()
	hint.position = Vector2(24, 497)
	hint.text = "视觉预览    1 平台    2 中继    3 蹬墙    G 接入反馈    P 暂停    R 重置    F 结算"
	hint.add_theme_font_size_override("font_size", 14)
	control.add_child(hint)
	_result = PanelContainer.new()
	_result.position = Vector2(270, 170)
	_result.size = Vector2(420, 270)
	_result.add_theme_stylebox_override("panel", control.theme.get_stylebox("panel", "ChaseHUDNear"))
	control.add_child(_result)
	_result.hide()

func is_endless() -> bool:
	return true

func set_template(id: String) -> void:
	_template = id
	for child in _terrain.get_children():
		_terrain.remove_child(child)
		child.queue_free()
	var definition: Dictionary = load("res://scripts/level/endless_library.gd").definition(id)
	module.configure({"id": "preview:0", "template_id": id, "category": definition.category,
		"origin": 0.0, "length": definition.length})
	for rect in definition.floors + definition.platforms:
		for x in range(int(rect.position.x), int(rect.end.x), 32):
			_sprite("terrain_platform.png", Vector2(x + 16, rect.position.y + 8))
	for rect in definition.walls:
		for y in range(int(rect.position.y), int(rect.end.y), 32):
			_sprite("terrain_wall_left.png", Vector2(rect.position.x + 16, y + 16))
	for rect in definition.spikes:
		_sprite("hazard_spike_up.png", rect.get_center())
	_sprite("player_run_0_0.png", Vector2(738, 424))
	relays.clear()
	for entry in definition.relays:
		relays.append({"id": "preview:0:" + str(entry.local_id), "position": entry.position, "activated": false})
	relay.bind_flow(self, self)

func _sprite(file: String, at: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/visual/" + file)
	sprite.position = at
	_terrain.add_child(sprite)

func sample(score: int, distance: float, count: int, stage: int) -> void:
	run_score = score
	run_distance = distance
	relay_count = count
	difficulty_stage = stage
	endless_stats_changed.emit(score, distance, count, stage)

func gain_demo() -> void:
	if phase != "running":
		return
	for entry in relays:
		if not entry.activated:
			entry.activated = true
			relay_delay_remaining = 0.9
			relay_activated.emit(entry.id, 0.9, relay_count + 1)
			relay_delay_changed.emit(0.9)
			sample(1000, 9000, 1, difficulty_stage)
			return

func set_paused(value: bool) -> void:
	phase = "paused" if value else "running"
	pause_changed.emit(value)

func reset_preview() -> void:
	phase = "running"
	_clock = 0
	relay_delay_remaining = 0
	sample(900, 9000, 0, 1)
	hud.bind_flow(self)
	threat.bind_flow(self, chase)
	set_template(_template)
	_result.hide()

func show_result() -> void:
	phase = "failed"
	run_failed.emit("caught", 36.0, 0.0)
	for child in _result.get_children():
		_result.remove_child(child)
		child.queue_free()
	var label := Label.new()
	label.text = "本次信号中断\n\n总分  %d\n最远距离  %.0f 单位   ·   中继  %d\n本机最高  %d\n地图种子  %d\n\n同图重试 / 换图再跑 / 返回菜单" % [run_score, run_distance, relay_count, maxi(best_score, run_score), run_seed]
	label.add_theme_font_size_override("font_size", 20)
	_result.add_child(label)
	_result.show()

func _process(delta: float) -> void:
	if phase == "running":
		_clock += delta
		if relay_delay_remaining > 0:
			relay_delay_remaining = maxf(0, relay_delay_remaining - delta)
			relay_delay_changed.emit(relay_delay_remaining)
	module.set_clock(_clock)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_1: set_template("safe_b")
		KEY_2: set_template("relay_a")
		KEY_3: set_template("wall_a")
		KEY_G: gain_demo()
		KEY_P: set_paused(phase != "paused")
		KEY_R: reset_preview()
		KEY_F: show_result()
