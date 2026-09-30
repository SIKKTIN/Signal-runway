extends Node2D

signal run_started
signal run_restarted
signal stats_changed(elapsed_seconds: float, deaths: int)
signal run_finished(elapsed_seconds: float, deaths: int, best_seconds: float)
signal pause_changed(paused: bool)

const PlayerScene = preload("res://scenes/player/player.tscn")
const CourseScript = preload("res://scripts/level/course.gd")
const InterfaceScript = preload("res://scripts/ui/interface.gd")
var phase := "menu"
var elapsed := 0.0
var deaths := 0
var best_seconds := -1.0
var best_deaths := 0
var lab_mode := false
var player: CharacterBody2D
var course: Node2D
var camera: Camera2D
var world: Node2D
var ui: CanvasLayer
var _recovery := 0.0
var _previous_phase := "ready"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	preload("res://scripts/core/input_bindings.gd").configure()
	ui = InterfaceScript.new()
	ui.name = "Interface"
	add_child(ui)
	ui.start_requested.connect(func(): start_challenge(false))
	ui.lab_requested.connect(func(): start_challenge(true))
	ui.resume_requested.connect(toggle_pause)
	ui.restart_requested.connect(restart_challenge)
	ui.menu_requested.connect(return_to_menu)
	_build_world(false)
	player.set_control_enabled(false)
	ui.show_menu()

func _build_world(use_lab: bool) -> void:
	if world:
		remove_child(world)
		world.queue_free()
	world = Node2D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	move_child(world, 0)
	course = CourseScript.new()
	course.name = "Course"
	course.lab_mode = use_lab
	world.add_child(course)
	player = PlayerScene.instantiate()
	player.name = "Player"
	world.add_child(player)
	player.reset_at(course.spawn_position)
	player.died.connect(_on_death)
	course.goal_reached.connect(_on_goal)
	camera = Camera2D.new()
	camera.name = "FollowCamera"
	camera.position = Vector2(480, 270)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	world.add_child(camera)
	camera.make_current()
	_install_presentation()

func _install_presentation() -> void:
	var visual_path := "res://scripts/visual/player_visual.gd"
	if ResourceLoader.exists(visual_path):
		var visual := Node2D.new()
		visual.name = "Visual"
		visual.set_script(load(visual_path))
		player.add_child(visual)
		player.fallback_visual_enabled = false
		player.queue_redraw()
	# Presentation can connect to the player's public signals in its own _ready.
	var audio_path := "res://scripts/visual/run_audio.gd"
	if ResourceLoader.exists(audio_path):
		var audio := Node.new()
		audio.name = "RunAudio"
		audio.set_script(load(audio_path))
		world.add_child(audio)
		if audio.has_method("bind_player"):
			audio.bind_player(player)

func start_challenge(use_lab: bool = false) -> void:
	get_tree().paused = false
	lab_mode = use_lab
	_build_world(use_lab)
	elapsed = 0.0
	deaths = 0
	phase = "ready"
	ui.show_playing()
	ui.set_notice("首次移动或跳跃开始计时", Color("45dccb"))
	run_started.emit()
	_update_ui()

func restart_challenge() -> void:
	start_challenge(lab_mode)
	run_restarted.emit()

func return_to_menu() -> void:
	get_tree().paused = false
	phase = "menu"
	player.reset_at(course.spawn_position)
	player.set_control_enabled(false)
	camera.position = Vector2(480, 270)
	camera.reset_smoothing()
	ui.show_menu()

func toggle_pause() -> void:
	if phase == "paused":
		phase = _previous_phase
		get_tree().paused = false
		ui.show_playing()
		pause_changed.emit(false)
	elif phase in ["ready", "running", "recovering"]:
		_previous_phase = phase
		phase = "paused"
		get_tree().paused = true
		ui.show_pause()
		pause_changed.emit(true)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart") and phase != "menu":
		restart_challenge()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("test_room"):
		start_challenge(true)
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if not player:
		return
	if phase == "ready" and (not is_zero_approx(Input.get_axis("move_left", "move_right")) or Input.is_action_just_pressed("jump")):
		phase = "running"
		ui.set_notice("", Color.WHITE)
	if phase in ["running", "recovering"]:
		elapsed += delta
		if phase == "recovering":
			_recovery -= delta
			if _recovery <= 0:
				player.reset_at(course.spawn_position)
				camera.position = Vector2(480, 270)
				camera.reset_smoothing()
				phase = "running"
				ui.set_notice("已回到起点 · 本轮计时继续", Color("607987"))
		elif player.position.y > 650:
			player.die("fall")
	if phase in ["ready", "running"]:
		camera.position.x = clampf(player.position.x + player.facing * 96.0, 480.0, course.course_length - 480.0)
	_update_ui()

func _on_death(reason: String, _position: Vector2) -> void:
	if phase not in ["running", "ready"]:
		return
	deaths += 1
	phase = "recovering"
	_recovery = 0.25
	ui.set_notice("撞上尖刺 · 立即重试" if reason == "spike" else "坠入空隙 · 立即重试", Color("ff685c"))

func _on_goal(body: Node2D) -> void:
	if body == player:
		call_deferred("_finish_if_alive")

func _finish_if_alive() -> void:
	if phase != "running" or player.dead:
		return
	phase = "finished"
	player.set_control_enabled(false)
	player.action_triggered.emit("finish")
	var visual := player.get_node_or_null("Visual")
	if visual and visual.has_method("set_state"):
		visual.set_state("finish")
	if not lab_mode and (best_seconds < 0.0 or elapsed < best_seconds or (is_equal_approx(elapsed, best_seconds) and deaths < best_deaths)):
		best_seconds = elapsed
		best_deaths = deaths
	ui.show_result(elapsed, deaths, best_seconds, lab_mode)
	run_finished.emit(elapsed, deaths, best_seconds)

func _update_ui() -> void:
	ui.update_stats(elapsed, deaths, best_seconds, player.position.x / course.finish_x, course.section_at(player.position.x), lab_mode)
	stats_changed.emit(elapsed, deaths)
