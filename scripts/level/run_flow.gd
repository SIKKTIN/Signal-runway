extends Node2D

signal run_started
signal run_restarted
signal stats_changed(elapsed_seconds: float, deaths: int)
signal run_finished(elapsed_seconds: float, deaths: int, best_seconds: float)
signal pause_changed(paused: bool)
signal mode_changed(mode: String)
signal run_failed(reason: String, elapsed: float, furthest_ratio: float)
signal relay_activated(relay_id: String, added_delay: float, activated_count: int)
signal relay_delay_changed(remaining: float)
signal endless_stats_changed(score: int, distance: float, count: int, stage: int)
signal world_shifted(distance: float)
signal route_event(kind: String, data: Dictionary)
signal route_state_changed(state: Dictionary)
const RouteChallenge = preload("res://scripts/level/route_challenge.gd")
var routes := RouteChallenge.new()
var _feature_from := Vector2.ZERO
var _feature_to := Vector2.ZERO
var _feature_pending := false
var _feature_damaged := false

const PlayerScene = preload("res://scenes/player/player.tscn")
const CourseScript = preload("res://scripts/level/course.gd")
const InterfaceScript = preload("res://scripts/ui/interface.gd")
const ChaseScript = preload("res://scripts/level/chase_controller.gd")
const EndlessCourseScript = preload("res://scripts/level/endless_course.gd")
const GenerationReplay = preload("res://scripts/tools/generation_replay.gd")
const EndlessRecordScript = preload("res://scripts/level/endless_record.gd")
const GenerationProfile = preload("res://scripts/level/generation_profile.gd")
var generation_profile: Dictionary = {}
var generation_notice := ""
var _generation_profile_override := false
var _generation_notice_label: Label
var phase := "menu"
var mode := "pursuit"
var level_id := "level01"
var relay_count := 0
var relay_prototype := false
var endless_prototype := false
var endless_test_sequence: Array[String] = []
var run_seed := 1
var run_distance := 0.0
var run_score := 0
var difficulty_stage := 0
var catchup_bonus := 0.0
var speed_distance_base := 0.0
var target_run_speed := 280.0
var trial_speed := 0.0
var _survival_status: Control
var _route_status: Control
var safe_points: Array[Dictionary] = []
var fall_recovery_remaining := 0.0
var _grounded_frames := 0
var relay_delay_chunks: Dictionary = {}
var best_score := 0
var new_record := false
var record_path := EndlessRecordScript.DEFAULT_PATH
var endless_record := EndlessRecordScript.new()
var relay_delay_remaining: float:
	get:
		return float(chase.relay_remaining) if is_instance_valid(chase) else 0.0
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
var _relay_pending: Array[String] = []
var _previous_position := Vector2.ZERO
var _best_by_mode := {"time_trial": {"seconds": -1.0, "deaths": 0}, "pursuit": {"seconds": -1.0, "deaths": 0}}
var _best_by_level: Dictionary = {}

func _ready() -> void:
	_generation_profile_override = not generation_profile.is_empty()
	if generation_profile.is_empty():
		var loaded := GenerationProfile.load_profile()
		generation_profile = loaded.profile
		generation_notice = "生成配置不可用，已回退内置默认" if loaded.fallback else ""
	endless_record.expected_rules_revision = 7
	reload_endless_record()
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
	ui.start_requested.connect(func(): start_challenge(false, "pursuit", ui.selected_level))
	ui.time_trial_requested.connect(func(): start_challenge(false, "time_trial", ui.selected_level))
	ui.lab_requested.connect(func(): start_challenge(true, "time_trial"))
	ui.resume_requested.connect(toggle_pause)
	ui.restart_requested.connect(restart_challenge)
	ui.menu_requested.connect(return_to_menu)
	ui.endless_requested.connect(func(): start_endless())
	ui.new_seed_requested.connect(func(): start_endless())
	_build_world(false)
	player.set_control_enabled(false)
	ui.show_menu()
	_show_generation_notice()

func _show_generation_notice() -> void:
	if not is_instance_valid(_generation_notice_label):
		_generation_notice_label = Label.new()
		_generation_notice_label.position = Vector2(24, 508)
		_generation_notice_label.add_theme_color_override("font_color", Color("ffc95c"))
		ui.add_child(_generation_notice_label)
	_generation_notice_label.text = generation_notice
	_generation_notice_label.visible = not generation_notice.is_empty()

func _build_world(use_lab: bool) -> void:
	if world:
		remove_child(world)
		world.queue_free()
	world = Node2D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	move_child(world, 0)
	course = EndlessCourseScript.new() if is_endless() else CourseScript.new()
	course.name = "Course"
	course.lab_mode = use_lab
	course.level_id = level_id
	course.relay_prototype = relay_prototype
	if is_endless():
		course.generation_profile = generation_profile.duplicate(true)
		course.run_seed = run_seed
		course.prototype = endless_prototype
		course.test_sequence = endless_test_sequence
	world.add_child(course)
	player = PlayerScene.instantiate()
	player.name = "Player"
	world.add_child(player)
	player.reset_at(course.spawn_position)
	player.auto_run = is_endless()
	player.health_enabled = is_endless()
	if is_endless() and generation_profile.generator_revision==5:
		player.floor_snap_length=16.0
		player.floor_constant_speed=true
	player.damage_taken.connect(_on_damage_taken)
	_previous_position = player.position
	player.died.connect(_on_death)
	course.goal_reached.connect(_on_goal)
	camera = Camera2D.new()
	camera.name = "FollowCamera"
	camera.position = Vector2(480, 270)
	camera.position_smoothing_enabled = not (is_endless() and generation_profile.generator_revision==5)
	camera.position_smoothing_speed = 8.0
	world.add_child(camera)
	camera.make_current()
	chase = ChaseScript.new()
	chase.name = "Chase"
	chase.speed = chase_speed
	world.add_child(chase)
	chase.relay_delay_changed.connect(func(remaining: float): relay_delay_changed.emit(remaining))
	chase.reset(course.spawn_position.x)
	_install_presentation()

func _install_presentation() -> void:
	if is_instance_valid(_route_status):
		_route_status.queue_free()
		_route_status=null
	if is_instance_valid(_survival_status):
		_survival_status.queue_free()
		_survival_status = null
	if is_endless() and ResourceLoader.exists("res://scenes/ui/v05_status.tscn"):
		_survival_status = load("res://scenes/ui/v05_status.tscn").instantiate()
		_survival_status.enable_hurt_audio = true
		ui.add_child(_survival_status)
	ui.external_endless_hud = false
	if is_endless():
		if generation_profile.generator_revision==5 and ResourceLoader.exists("res://scripts/visual/spatial_visual.gd"):
			var spatial_visual: Node2D=load("res://scripts/visual/spatial_visual.gd").new()
			spatial_visual.name="SpatialVisual"
			world.add_child(spatial_visual)
			spatial_visual.bind_flow(self,course)
		if generation_profile.generator_revision>=4 and ResourceLoader.exists("res://scripts/visual/route_visual.gd"):
			var route_visual: Node2D=load("res://scripts/visual/route_visual.gd").new()
			route_visual.name="RouteVisual"
			world.add_child(route_visual)
			route_visual.bind_flow(self,course)
		if generation_profile.generator_revision>=4 and ResourceLoader.exists("res://scenes/ui/v06_route_status.tscn"):
			_route_status=load("res://scenes/ui/v06_route_status.tscn").instantiate()
			ui.add_child(_route_status)
			_route_status.bind_flow(self)
		for pair in [["endless_world_visual", "EndlessWorldVisual"], ["endless_hud_visual", "EndlessHUDVisual"]]:
			var path: String = "res://scripts/visual/" + pair[0] + ".gd"
			if ResourceLoader.exists(path):
				var presentation: Node = load(path).new()
				presentation.name = pair[1]
				world.add_child(presentation)
				if pair[0] == "endless_world_visual":
					presentation.bind_flow(self, course)
				else:
					presentation.bind_flow(self)
					ui.external_endless_hud = true
	var relay_path := "res://scripts/visual/relay_visual.gd"
	if ResourceLoader.exists(relay_path):
		var relay_visual := Node2D.new()
		relay_visual.name = "RelayVisual"
		relay_visual.set_script(load(relay_path))
		world.add_child(relay_visual)
		relay_visual.bind_flow(self, course)
		course.fallback_relays_enabled = false
		course.queue_redraw()
	var environment_path := "res://scripts/visual/environment_visual.gd"
	if ResourceLoader.exists(environment_path):
		var environment := Node2D.new()
		environment.name = "EnvironmentVisual"
		environment.z_index = -10
		environment.set_script(load(environment_path))
		world.add_child(environment)
		environment.bind_flow(self, camera, course)
		course.dynamic_environment_enabled = true
		course.queue_redraw()
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

func start_challenge(use_lab: bool = false, selected_mode: String = "", selected_level: String = "") -> void:
	get_tree().paused = false
	_generation += 1
	_resolution_scheduled = false
	_goal_pending = false
	_failures.clear()
	_relay_pending.clear()
	relay_count = 0
	lab_mode = use_lab
	if selected_level in ["level01", "relay_station", "endless"]:
		level_id = selected_level
	if selected_mode in ["pursuit", "time_trial"]:
		mode = selected_mode
	if use_lab:
		mode = "time_trial"
	elapsed = 0.0
	deaths = 0
	_recovery = 0.0
	furthest_ratio = 0.0
	failure_reason = ""
	run_distance = 0.0
	run_score = 0
	difficulty_stage = 0
	catchup_bonus = 0.0
	speed_distance_base = 0.0
	target_run_speed = 280.0
	new_record = false
	safe_points.clear()
	fall_recovery_remaining = 0.0
	_grounded_frames = 0
	relay_delay_chunks.clear()
	routes.reset()
	_feature_pending=false
	_feature_damaged=false
	phase = "ready"
	_load_best()
	_build_world(use_lab)
	ui.set_mode(mode)
	ui.set_course("lab" if lab_mode else level_id, course.section_names)
	ui.show_playing()
	ui.set_notice("首次移动或跳跃开始挑战", Color("45dccb"))
	mode_changed.emit(mode)
	pause_changed.emit(false)
	run_started.emit()
	if is_endless():
		phase = "running"
		chase.set_enabled(true)
		ui.set_notice("自动奔跑 · 跳跃选择路线", Color("45dccb"))
	_update_ui()

func start_endless(seed_value: int = -1) -> void:
	if not _generation_profile_override:
		var loaded := GenerationProfile.load_profile()
		generation_profile = loaded.profile
		generation_notice = "生成配置不可用，已回退内置默认" if loaded.fallback else ""
		_show_generation_notice()
	if seed_value < 0:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var next_seed := run_seed
		while next_seed == run_seed:
			next_seed = rng.randi_range(1, 2147483646)
		run_seed = next_seed
	else:
		run_seed = seed_value
	start_challenge(false, "pursuit", "endless")

func is_endless() -> bool:
	return level_id == "endless" and not lab_mode

func reload_endless_record() -> void:
	endless_record.load_from(record_path)
	best_score = int(endless_record.best.score)

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
	_relay_pending.clear()
	if level_id != "endless":
		ui.selected_level = level_id
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
		if _goal_pending or not _failures.is_empty() or not _relay_pending.is_empty():
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
				_previous_position = player.position
				camera.position = Vector2(480, 270)
				camera.reset_smoothing()
				phase = "running"
				ui.set_notice("已回到起点 · 本轮计时继续", Color("607987"))
		else:
			if is_endless():
				run_distance = maxf(run_distance, player.position.x + course.total_offset - course.spawn_position.x)
				target_run_speed = trial_speed if trial_speed > 0 else 280.0 + 100.0 * clampf((run_distance - speed_distance_base) / 50000.0, 0, 1)
				player.move_speed = target_run_speed
				if fall_recovery_remaining > 0:
					fall_recovery_remaining = maxf(0, fall_recovery_remaining - delta)
					player.invulnerable_remaining = maxf(0, player.invulnerable_remaining - delta)
					if fall_recovery_remaining <= 0:
						_restore_safe_point()
				elif not player.dead:
					_record_safe_point()
				update_endless_pressure(delta)
				run_score = total_score()
			else:
				furthest_ratio = maxf(furthest_ratio, clampf((player.position.x - course.spawn_position.x) / (course.finish_x - course.spawn_position.x), 0.0, 1.0))
			if player.position.y > 650:
				if is_endless():
					_handle_endless_fall()
				else:
					player.die("fall")
			if is_pursuit() and chase.advance(delta, player.global_position.x - 10.0):
				_queue_failure("caught")
				player.die("caught")
			if not player.dead and _failures.is_empty():
				if is_endless() and course.streaming and generation_profile.generator_revision>=4 and fall_recovery_remaining<=0:
					_feature_from=_previous_position+Vector2(course.total_offset,0)
					_feature_to=player.position+Vector2(course.total_offset,0)
					_feature_pending=true
					_schedule_resolution()
				for relay_id in course.relay_candidates(_previous_position, player.position):
					_queue_relay(relay_id)
			if is_endless() and not player.dead and _failures.is_empty():
				course.update_stream(player.position.x, chase.front_x)
				var active_ids := {}
				for chunk in course.chunks:
					active_ids[chunk.id] = true
				for id in relay_delay_chunks.keys():
					if not active_ids.has(id):
						relay_delay_chunks.erase(id)
				if course.streaming and player.position.x >= course.REBASE_AT:
					_shift_endless_world(course.REBASE_BY)
	if phase in ["ready", "running"]:
		if is_endless() and generation_profile.generator_revision==5:
			# Smooth world movement while keeping landings above the survival HUD.
			var blend:=1.0-exp(-8.0*delta)
			camera.position.x=lerpf(camera.position.x,maxf(player.position.x+180,480),blend)
			camera.position.y=lerpf(camera.position.y,clampf(player.position.y-130,270,420),blend)
			# 412 center +15 feet +15 maximum next-frame fall leaves HUD450 clear.
			camera.position.y=maxf(camera.position.y,clampf(player.position.y-142,270,420))
		else:
			camera.position.x = maxf(player.position.x + 180.0, 480.0) if is_endless() else clampf(player.position.x + player.facing * 96.0, 480.0, course.course_length - 480.0)
			if is_endless():
				camera.position.y = clampf(player.position.y-163,270,420)
	_update_ui()
	_previous_position = player.position

func _shift_endless_world(distance: float) -> void:
	course.shift_world(distance)
	player.position.x -= distance
	_previous_position.x -= distance
	camera.position.x -= distance
	camera.reset_smoothing()
	chase.front_x -= distance
	chase._previous_player_left -= distance
	chase.advance(0, player.position.x - 10)
	world_shifted.emit(distance)

func update_endless_pressure(delta: float) -> void:
	difficulty_stage = mini(3,int(elapsed/30.0))
	var gap_now: float = player.position.x-10-chase.front_x
	var target_bonus := clampf((gap_now-1400)/60,0,14) if difficulty_stage==3 else 0.0
	catchup_bonus = move_toward(catchup_bonus,target_bonus,8*delta)
	var target := (270+difficulty_stage*4+catchup_bonus)*target_run_speed/280
	chase.speed = move_toward(chase.speed,target,(300.0 if target<chase.speed else 80.0)*delta)

func _queue_relay(relay_id: String) -> void:
	if phase not in ["ready", "running"] or player.dead or not _failures.is_empty():
		return
	if relay_id not in _relay_pending:
		_relay_pending.append(relay_id)
	_schedule_resolution()

func _activate_pending_relays() -> void:
	for relay_id in _relay_pending:
		if course.activate_relay(relay_id):
			if is_endless() and generation_profile.generator_revision>=4:
				routes.node(relay_id)
			relay_count += 1
			var added := 0.9 if is_pursuit() else 0.0
			if is_endless():
				var chunk_id := relay_id.get_slice(":",0)+":"+relay_id.get_slice(":",1)
				added = 0.0 if relay_delay_chunks.has(chunk_id) else 0.9
				relay_delay_chunks[chunk_id] = true
			if added > 0.0:
				chase.add_relay_delay(added)
			if is_endless():
				_update_ui()
			relay_activated.emit(relay_id, added, relay_count)

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

func _on_damage_taken(reason: String, _health: int) -> void:
	_feature_damaged=true
	routes.interrupt("damage")
	speed_distance_base = run_distance
	target_run_speed = 280.0
	trial_speed = 0.0
	ui.set_notice("受伤 · 生命 %d/3 · 速度重新积累" % player.health, Color("ff685c"))

func _record_safe_point() -> void:
	_grounded_frames = _grounded_frames + 1 if player.is_on_floor() else 0
	safe_points = safe_points.filter(func(p): return course.safe_point_exists(p) and p.global_point.x - course.total_offset > chase.front_x + 12)
	if _grounded_frames < 2:
		return
	var saved: Dictionary = course.safe_surface(player.position)
	if not saved.is_empty():
		if safe_points.is_empty() or saved.global_point.x - safe_points.back().global_point.x > 64:
			safe_points.append(saved)
			if safe_points.size() > 32:
				safe_points.pop_front()

func _handle_endless_fall() -> void:
	if player.dead or fall_recovery_remaining > 0:
		return
	player.take_damage("fall")
	if player.dead:
		return
	fall_recovery_remaining = 0.25
	player.control_enabled = false
	player.set_physics_process(false)
	_relay_pending.clear()
	_grounded_frames = 0

func _restore_safe_point() -> void:
	var original_x: float = player.position.x + course.total_offset
	for i in range(safe_points.size()-1,-1,-1):
		var saved := safe_points[i]
		if not course.safe_point_exists(saved) or saved.global_point.x > original_x:
			continue
		var local: Vector2 = saved.global_point - Vector2(course.total_offset,0)
		if local.x - 10 <= chase.front_x:
			player.die("caught")
			return
		player.recover_at(local)
		camera.position.y = clampf(local.y-(130 if generation_profile.generator_revision==5 else 163),270,420)
		camera.reset_smoothing()
		_previous_position = local
		return
	player.die("unrecoverable")

func _queue_failure(reason: String) -> void:
	if phase not in ["ready", "running"] and not (phase == "paused" and _previous_phase in ["ready", "running"]):
		return
	if reason not in _failures:
		_failures.append(reason)
	_schedule_resolution()

func _on_goal(body: Node2D) -> void:
	if is_endless():
		return
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
		_relay_pending.clear()
		return
	if is_pursuit() and not _failures.is_empty():
		for reason in (["caught", "health", "unrecoverable", "spike", "fall"] if is_endless() else ["spike", "fall", "caught"]):
			if reason in _failures:
				_finish_failure(reason)
				break
	elif _goal_pending:
		_finish_if_alive()
	elif not player.dead:
		if _feature_pending:
			routes.begin_step(_feature_from,_feature_to,course.chunks,course.total_offset,_feature_damaged)
		_activate_pending_relays()
		if _feature_pending:
			for action in routes.end_step(course.chunks,course.total_offset,player.health):
				if action.kind=="heal":
					player.health=mini(3,player.health+int(action.amount))
					ui.set_notice("生命已满" if action.amount==0 else "恢复站 · 生命 +1",Color("7ee6cf"))
				else:
					ui.set_notice("恢复站 · 积分 +%d"%action.amount,Color("ffd166"))
			_flush_route_events()
			_update_ui()
	_feature_pending=false
	_feature_damaged=false
	_goal_pending = false
	_failures.clear()
	_relay_pending.clear()

func _finish_failure(reason: String) -> void:
	routes.interrupt("terminal")
	_flush_route_events()
	phase = "failed"
	get_tree().paused = false
	failure_reason = reason
	deaths = 1
	chase.set_enabled(false)
	pause_changed.emit(false)
	player.set_control_enabled(false)
	player.set_physics_process(false)
	ui.set_relay_count(relay_count)
	if is_endless():
		run_score=total_score()
		if record_path==EndlessRecordScript.DEFAULT_PATH:
			GenerationReplay.save(GenerationReplay.make(run_seed,generation_profile,player.position.x+course.total_offset,reason))
		new_record = endless_record.consider(record_path, run_score, run_distance, relay_count, run_seed, {"rules_revision":7,"generator_revision":generation_profile.generator_revision,"profile_fingerprint":GenerationProfile.fingerprint(generation_profile),"score_breakdown":score_breakdown()})
		best_score = int(endless_record.best.score)
		ui.show_endless_result(reason, elapsed, run_score, run_distance, relay_count, run_seed, best_score, new_record, endless_record.status,score_breakdown())
	else:
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
		_scores()[mode] = {"seconds": best_seconds, "deaths": best_deaths}
	ui.set_relay_count(relay_count)
	ui.show_result(elapsed, deaths, best_seconds, lab_mode)
	run_finished.emit(elapsed, deaths, best_seconds)

func _load_best() -> void:
	best_seconds = float(_scores()[mode].seconds)
	best_deaths = int(_scores()[mode].deaths)

func _scores() -> Dictionary:
	if level_id == "level01":
		return _best_by_mode
	if not _best_by_level.has(level_id):
		_best_by_level[level_id] = {"pursuit": {"seconds": -1.0, "deaths": 0}, "time_trial": {"seconds": -1.0, "deaths": 0}}
	return _best_by_level[level_id]

func _update_ui() -> void:
	ui.set_relay_count(relay_count)
	if is_endless():
		if is_instance_valid(_survival_status):
			_survival_status.visible = phase in ["running","paused"]
			_survival_status.set_feedback_active(phase in ["running","paused"])
			_survival_status.update_state(player.health,target_run_speed,player.velocity.x,player.invulnerable_remaining>0,player.hurt_count)
		run_score = total_score()
		ui.update_endless(elapsed, run_score, run_distance, relay_count, difficulty_stage, best_score)
		endless_stats_changed.emit(run_score, run_distance, relay_count, difficulty_stage)
	else:
		ui.update_stats(elapsed, deaths, best_seconds, furthest_ratio if is_pursuit() else player.position.x / course.finish_x, course.section_at(player.position.x), lab_mode)
	stats_changed.emit(elapsed, deaths)

func total_score() -> int:
	return int(floor(run_distance/10.0))+relay_count*100+routes.combo_score+routes.station_score
func score_breakdown() -> Dictionary:
	return {"distance":int(floor(run_distance/10.0)),"nodes":relay_count*100,"combo":routes.combo_score,"station":routes.station_score,"completed":routes.completed,"heal_choices":routes.heal_choices,"score_choices":routes.score_choices}
func _flush_route_events() -> void:
	for event in routes.events:
		route_event.emit(event.kind,event.data)
	routes.events.clear()
	route_state_changed.emit(routes.snapshot())
