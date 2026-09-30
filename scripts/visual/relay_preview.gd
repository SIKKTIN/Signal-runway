extends Node2D
## Frozen-interface fixture, never included in gameplay route proof.
signal mode_changed(mode: String)
signal pause_changed(paused: bool)
signal run_failed(reason: String, elapsed: float, furthest_ratio: float)
signal run_finished(elapsed: float, deaths: int, best: float)
signal relay_activated(relay_id: String, added_delay: float, activated_count: int)
signal relay_delay_changed(remaining: float)

var mode := "pursuit"
var phase := "running"
var level_id := "relay_station"
var relay_count := 0
var relay_delay_remaining := 0.0
var relays: Array[Dictionary] = []
var relay: Node2D
var chase_visual: Node2D
var chase: Node
var _caption: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/visual/background_industrial.png")
	sprite.position = Vector2(480, 270)
	add_child(sprite)
	for x in range(0, 960, 32):
		var ground := Sprite2D.new()
		ground.texture = load("res://assets/visual/terrain_platform.png")
		ground.position = Vector2(x + 16, 456)
		add_child(ground)
	for at in [Vector2(200, 366), Vector2(520, 306), Vector2(810, 368)]:
		var ground := Sprite2D.new()
		ground.texture = load("res://assets/visual/terrain_platform.png")
		ground.position = at
		ground.scale.x = 3
		add_child(ground)
	var player := Sprite2D.new()
	player.texture = load("res://assets/visual/player_run_0_0.png")
	player.position = Vector2(738, 424)
	add_child(player)
	var spike := Sprite2D.new()
	spike.texture = load("res://assets/visual/hazard_spike_up.png")
	spike.position = Vector2(850, 432)
	add_child(spike)
	reset_nodes()
	chase = load("res://scripts/visual/chase_preview_source.gd").new()
	add_child(chase)
	chase.sample(95.0, 633.0, "near")
	chase_visual = load("res://scripts/visual/chase_visual.gd").new()
	add_child(chase_visual)
	chase_visual.bind_flow(self, chase)
	relay = load("res://scripts/visual/relay_visual.gd").new()
	add_child(relay)
	relay.bind_flow(self, self)
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	var control := Control.new()
	control.theme = load("res://scenes/ui/skins/chase_theme.tres")
	layer.add_child(control)
	_caption = Label.new()
	_caption.position = Vector2(24, 20)
	_caption.add_theme_font_size_override("font_size", 27)
	_caption.text = "断线中继  /  三态与接入反馈预览"
	control.add_child(_caption)
	var instructions := Label.new()
	instructions.position = Vector2(24, 490)
	instructions.text = "1 接入左节点   2 接入右节点   P 暂停   R 重开   T 切换模式"
	instructions.add_theme_font_size_override("font_size", 16)
	control.add_child(instructions)

func reset_nodes() -> void:
	relays = [{"id": "relay_01", "position": Vector2(200, 314), "activated": false},
		{"id": "relay_02", "position": Vector2(520, 254), "activated": false}]
	relay_count = 0
	relay_delay_remaining = 0.0

func activate(id: String) -> void:
	for node in relays:
		if node.id == id and not node.activated:
			node.activated = true
			relay_count += 1
			var added := 0.9 if mode == "pursuit" else 0.0
			relay_delay_remaining += added
			relay_activated.emit(id, added, relay_count)
			relay_delay_changed.emit(relay_delay_remaining)

func _process(delta: float) -> void:
	if phase == "running" and relay_delay_remaining > 0.0:
		relay_delay_remaining = maxf(0.0, relay_delay_remaining - delta)
		relay_delay_changed.emit(relay_delay_remaining)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_1:
		activate("relay_01")
	elif event.keycode == KEY_2:
		activate("relay_02")
	elif event.keycode == KEY_P:
		phase = "running" if phase == "paused" else "paused"
		pause_changed.emit(phase == "paused")
	elif event.keycode == KEY_R:
		phase = "running"
		reset_nodes()
		relay.bind_flow(self, self)
		chase_visual.bind_flow(self, chase)
	elif event.keycode == KEY_T:
		mode = "time_trial" if mode == "pursuit" else "pursuit"
		mode_changed.emit(mode)
