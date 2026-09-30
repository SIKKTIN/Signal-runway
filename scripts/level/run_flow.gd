extends Node2D

signal run_started
signal run_restarted
signal stats_changed(elapsed_seconds: float, deaths: int)
signal run_finished(elapsed_seconds: float, deaths: int, best_seconds: float)
signal pause_changed(paused: bool)
signal mode_changed(mode: String)
signal run_failed(reason: String, elapsed: float, furthest_ratio: float)

const PlayerScene = preload("res://scenes/player/player.tscn")
const CourseScript = preload("res://scripts/level/course.gd")
const InterfaceScript = preload("res://scripts/ui/interface.gd")
const ChaseScript = preload("res://scripts/level/chase_controller.gd")
var phase := "menu"
var mode := "pursuit"
var elapsed := 0.0
var deaths := 0
var best_seconds := -1.0
var best_deaths := 0
var lab_mode := false
var furthest_ratio := 0.0
var failure_reason := ""
var chase_speed := 270.0
var player: CharacterBody2D
var course: Node2D
var camera: Camera2D
var world: Node2D
var ui: CanvasLayer
var chase: Node
var _recovery := 0.0
var _previous_phase := "ready"
var _generation := 0
var _resolution_scheduled := false
var _goal_pending := false
var _failures: Array[String] = []
var _best_by_mode := {"time_trial": {"seconds": -1.0, "deaths": 0}, "pursuit": {"seconds": -1.0, "deaths": 0}}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Resolve the front after the player's current-frame move_and_slide.
	process_physics_priority = 100
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	preload("res://scripts/core/input_bindings.gd").configure()
	ui = InterfaceScript.new()
	ui.name = "Interface"
	add_child(ui)
	ui.start_requested.connect(func(): start_challenge(false, "pursuit"))
	ui.time_trial_requested.connect(func(): start_challenge(false, "time_trial"))
	ui.lab_requested.connect(func(): start_challenge(true, "time_trial"))
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
	chase = ChaseScript.new()
	chase.name = "Chase"
	chase.speed = chase_speed
	world.add_child(chase)
	chase.reset(course.spawn_position.x)
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
	var threat_path := "res://scripts/visual/chase_visual.gd"
	if ResourceLoader.exists(threat_path):
		var threat_visual := Node2D.new()
		threat_visual.name = "ChaseVisual"
		threat_visual.set_script(load(threat_path))
		world.add_child(threat_visual)
		threat_visual.bind_flow(self, chase)

func start_challenge(use_lab: bool = false, selected_mode: String = "") -> void:
	get_tree().paused = false
	_generation += 1
	_resolution_scheduled = false
	_goal_pending = false
	_failures.clear()
	lab_mode = use_lab
	if selected_mode in ["pursuit", "time_trial"]:
		mode = selected_mode
	if use_lab:
		mode = "time_trial"
	elapsed = 0.0
	deaths = 0
	_recovery = 0.0
	furthest_ratio = 0.0
	failure_reason = ""
	phase = "ready"
	_load_best()
	_build_world(use_lab)
	ui.set_mode(mode)
	ui.show_playing()
	ui.set_notice("首次移动或跳跃开始挑战", Color("45dccb"))
	mode_changed.emit(mode)
	pause_changed.emit(false)
	run_started.emit()
	_update_ui()

func restart_challenge() -> void:
	start_challenge(lab_mode, mode)
	run_restarted.emit()

func return_to_menu() -> void:
	get_tree().paused = false
	_generation += 1
	_resolution_scheduled = false
	_goal_pending = false
	_failures.clear()
	phase = "menu"
	chase.set_enabled(false)
	player.reset_at(course.spawn_position)
	player.set_control_enabled(false)
	player.set_physics_process(false)
	camera.position = Vector2(480, 270)
	camera.reset_smoothing()
	pause_changed.emit(false)
	mode_changed.emit(mode)
	ui.show_menu()

func toggle_pause() -> void:
	if phase == "paused":
		phase = _previous_phase
		get_tree().paused = false
		ui.show_playing()
		pause_changed.emit(false)
		if _goal_pending or not _failures.is_empty():
			_schedule_resolution()
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
		start_challenge(true, "time_trial")
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if not player:
		return
	if phase == "ready" and (not is_zero_approx(Input.get_axis("move_left", "move_right")) or Input.is_action_just_pressed("jump")):
		phase = "running"
		ui.set_notice("", Color.WHITE)
		if is_pursuit():
			chase.set_enabled(true)
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
		else:
			furthest_ratio = maxf(furthest_ratio, clampf((player.position.x - course.spawn_position.x) / (course.finish_x - course.spawn_position.x), 0.0, 1.0))
			if player.position.y > 650:
				player.die("fall")
			if is_pursuit() and chase.advance(delta, player.global_position.x - 10.0):
				_queue_failure("caught")
				player.die("caught")
	if phase in ["ready", "running"]:
		camera.position.x = clampf(player.position.x + player.facing * 96.0, 480.0, course.course_length - 480.0)
	_update_ui()

func is_pursuit() -> bool:
	return mode == "pursuit" and not lab_mode

func _on_death(reason: String, _position: Vector2) -> void:
	# Physics contact callbacks can arrive after the pause input. Preserve a
	# queued death rather than leaving a dead body in a live challenge.
	if phase == "paused" and _previous_phase in ["ready", "running"]:
		if is_pursuit():
			_queue_failure(reason)
		else:
			deaths += 1
			_previous_phase = "recovering"
			_recovery = 0.25
		return
	if phase not in ["running", "ready"]:
		return
	if is_pursuit():
		_queue_failure(reason)
	else:
		deaths += 1
		phase = "recovering"
		_recovery = 0.25
		ui.set_notice("撞上尖刺 · 立即重试" if reason == "spike" else "坠入空隙 · 立即重试", Color("ff685c"))

func _queue_failure(reason: String) -> void:
	if phase not in ["ready", "running"] and not (phase == "paused" and _previous_phase in ["ready", "running"]):
		return
	if reason not in _failures:
		_failures.append(reason)
	_schedule_resolution()

func _on_goal(body: Node2D) -> void:
	var active := phase in ["running", "ready"] or (phase == "paused" and _previous_phase in ["running", "ready"])
	if body != player or not active:
		return
	_goal_pending = true
	_schedule_resolution()

func _schedule_resolution() -> void:
	if _resolution_scheduled:
		return
	_resolution_scheduled = true
	call_deferred("_resolve_result", _generation)

func _resolve_result(generation: int) -> void:
	if generation != _generation:
		return
	_resolution_scheduled = false
	if phase == "paused" and _failures.is_empty():
		# A pending goal is retained until resume, with no time advancement.
		return
	if phase not in ["ready", "running", "paused"]:
		_goal_pending = false
		_failures.clear()
		return
	if is_pursuit() and not _failures.is_empty():
		for reason in ["spike", "fall", "caught"]:
			if reason in _failures:
				_finish_failure(reason)
				break
	elif _goal_pending:
		_finish_if_alive()
	_goal_pending = false
	_failures.clear()

func _finish_failure(reason: String) -> void:
	phase = "failed"
	get_tree().paused = false
	failure_reason = reason
	deaths = 1
	chase.set_enabled(false)
	pause_changed.emit(false)
	player.set_control_enabled(false)
	player.set_physics_process(false)
	ui.show_failure(reason, elapsed, furthest_ratio, best_seconds)
	run_failed.emit(reason, elapsed, furthest_ratio)
	_update_ui()

func _finish_if_alive() -> void:
	if phase != "running" or player.dead:
		return
	phase = "finished"
	chase.set_enabled(false)
	player.set_control_enabled(false)
	player.set_physics_process(false)
	player.action_triggered.emit("finish")
	var visual := player.get_node_or_null("Visual")
	if visual and visual.has_method("set_state"):
		visual.set_state("finish")
	if not lab_mode and (best_seconds < 0.0 or elapsed < best_seconds or (is_equal_approx(elapsed, best_seconds) and deaths < best_deaths)):
		best_seconds = elapsed
		best_deaths = deaths
		_best_by_mode[mode] = {"seconds": best_seconds, "deaths": best_deaths}
	ui.show_result(elapsed, deaths, best_seconds, lab_mode)
	run_finished.emit(elapsed, deaths, best_seconds)

func _load_best() -> void:
	best_seconds = float(_best_by_mode[mode].seconds)
	best_deaths = int(_best_by_mode[mode].deaths)

func _update_ui() -> void:
	ui.update_stats(elapsed, deaths, best_seconds, furthest_ratio if is_pursuit() else player.position.x / course.finish_x, course.section_at(player.position.x), lab_mode)
	stats_changed.emit(elapsed, deaths)
