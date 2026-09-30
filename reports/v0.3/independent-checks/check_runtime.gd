extends SceneTree
const OUT := "res://reports/v0.3/independent-checks/"
var app: Node2D
var checks: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func tap(code: Key) -> void:
	key(code, true)
	await frames(2)
	key(code, false)
	await frames(2)

func move() -> void:
	key(KEY_D, true)
	await frames(20)
	key(KEY_D, false)
	await frames(10)

func check(name: String, passed: bool, actual: Variant = "", method := "real-keyboard") -> void:
	checks.append({"check": name, "passed": passed, "actual": actual, "method": method})
	print(name, ": ", passed, " ", actual)

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")

func relay() -> Node2D:
	return app.world.get_node("RelayVisual")

func wave() -> Node2D:
	return app.world.get_node("ChaseVisual")

func environment() -> Node2D:
	return app.world.get_node("EnvironmentVisual")

func snapshot() -> Array:
	return [app.elapsed, app.chase.front_x, app.chase.grace_remaining, app.relay_delay_remaining,
		app.player.position, relay().presentation_state().animation_time, wave().presentation_state().animation_time,
		environment().presentation_state().animation_time]

func at(position: Vector2) -> void:
	# Mark position fixture explicitly. Real body/collision and RunFlow process
	# remain enabled; zero-length sweep prevents pretending teleport is travel.
	app.player.reset_at(position)
	app._previous_position = position

func run() -> void:
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await frames(8)
	await shot("menu")
	await tap(KEY_ENTER)
	check("actual_enter_default_new_station", app.phase == "ready" and app.level_id == "relay_station" and app.mode == "pursuit", {"phase": app.phase, "level": app.level_id, "mode": app.mode})
	var initial_front: float = app.chase.front_x
	await frames(60)
	check("idle_safe_before_first_action", app.elapsed == 0 and app.chase.front_x == initial_front and app.relay_count == 0, snapshot())
	await move()
	check("actual_d_starts_grace", app.phase == "running" and app.elapsed > 0.4 and app.chase.grace_remaining > 1.4 and app.chase.front_x == initial_front, snapshot())
	await tap(KEY_ESCAPE)
	var before := snapshot()
	await frames(18)
	check("actual_esc_freezes_startup_grace", app.phase == "paused" and before == snapshot(), snapshot())
	await tap(KEY_R)
	check("actual_r_while_paused_resets", app.phase == "ready" and not paused and app.elapsed == 0 and app.relay_count == 0 and app.relay_delay_remaining == 0 and app.chase.front_x == initial_front, snapshot())
	await move()
	await frames(94)
	check("baseline_chase_started_before_contact", app.phase == "running" and app.chase.grace_remaining == 0 and app.chase.front_x > initial_front, snapshot())
	var front_before_contact: float = app.chase.front_x
	var time_before_contact: float = app.elapsed
	at(app.course.relays[0].position)
	await frames(2)
	app.camera.reset_smoothing()
	check("physical_node_contact_activates_once", app.relay_count == 1 and app.relay_delay_remaining > 0.85 and relay().presentation_state().sound_triggers == 1, {"count": app.relay_count, "delay": app.relay_delay_remaining, "node": relay().presentation_state()}, "position-fixture-real-contact")
	var front_at_contact: float = app.chase.front_x
	var time_at_contact: float = app.elapsed
	var wave_at_contact: float = wave().presentation_state().animation_time
	await frames(20)
	check("overlap_does_not_refresh_or_replay", app.relay_count == 1 and relay().presentation_state().sound_triggers == 1 and app.relay_delay_remaining < 0.60, {"count": app.relay_count, "delay": app.relay_delay_remaining, "triggers": relay().presentation_state().sound_triggers}, "position-fixture-real-contact")
	check("delay_stops_translation_not_clock_or_wave", app.chase.front_x == front_at_contact and app.elapsed > time_at_contact + 0.3 and wave().presentation_state().animation_time > wave_at_contact + 0.3, snapshot(), "position-fixture-real-contact")
	await shot("relay-active")
	await tap(KEY_ESCAPE)
	before = snapshot()
	var audio_position: float = wave().presentation_state().loop_position
	await shot("pause-a")
	await frames(18)
	await shot("pause-b")
	check("actual_esc_freezes_active_delay_and_all_visuals", app.phase == "paused" and before == snapshot() and wave().presentation_state().loop_paused and absf(wave().presentation_state().loop_position - audio_position) < 0.04, {"before": before, "after": snapshot()}, "real-keyboard-after-contact-fixture")
	await tap(KEY_ESCAPE)
	await frames(50)
	check("resume_exhausts_delay_without_backtracking", app.phase == "running" and app.relay_delay_remaining == 0 and app.chase.front_x > front_at_contact and not wave().presentation_state().relay_delay_visible, snapshot(), "real-keyboard-after-contact-fixture")
	var front_without_delay: float = front_before_contact + (app.elapsed - time_before_contact) * app.chase.speed
	var saved_advance: float = front_without_delay - app.chase.front_x
	check("one_relay_avoids_about_243_units", absf(saved_advance - 243.0) < 5, {"actual_front": app.chase.front_x, "baseline_front_without_delay": front_without_delay, "observed_saved_advance": saved_advance, "theoretical_full_delay": app.chase.speed * 0.9}, "contact-fixture-time-budget")
	await tap(KEY_ESCAPE)
	await tap(KEY_R)
	check("r_clears_nodes_and_feedback", app.phase == "ready" and app.relay_count == 0 and app.relay_delay_remaining == 0 and relay().presentation_state().node_states.relay_one == "available" and relay().presentation_state().sound_triggers == 0 and not relay().presentation_state().toast_visible, relay().presentation_state())
	app.return_to_menu()
	await frames(4)
	await tap(KEY_DOWN)
	await tap(KEY_ENTER)
	check("keyboard_enters_station_time_trial", app.mode == "time_trial" and app.level_id == "relay_station" and app.phase == "ready", {"mode": app.mode, "level": app.level_id})
	await move()
	at(app.course.relays[0].position)
	await frames(3)
	check("trial_contact_counts_without_delay", app.relay_count == 1 and app.relay_delay_remaining == 0 and relay().presentation_state().sound_triggers == 1 and not wave().presentation_state().hud_visible, relay().presentation_state(), "position-fixture-real-contact")
	at(Vector2(5536, 433))
	await frames(5)
	check("trial_real_hazard_recovers_same_round", app.phase == "recovering" and app.deaths == 1 and app.relay_count == 1, {"phase": app.phase, "deaths": app.deaths, "relays": app.relay_count}, "position-fixture-real-hazard")
	await frames(24)
	check("trial_recovery_retains_used_node", app.phase == "running" and not app.player.dead and app.relay_count == 1 and relay().presentation_state().node_states.relay_one == "activated", relay().presentation_state(), "position-fixture-real-hazard")
	await tap(KEY_R)
	check("trial_r_creates_new_round", app.phase == "ready" and app.deaths == 0 and app.relay_count == 0 and relay().presentation_state().node_states.relay_one == "available", {"phase": app.phase, "deaths": app.deaths, "relays": app.relay_count})
	await tap(KEY_F2)
	check("actual_f2_uses_lab_bool_and_no_nodes", app.lab_mode and app.course.relays.is_empty() and not environment().presentation_state().station_enabled, {"lab": app.lab_mode, "level": app.level_id})
	await shot("lab")
	app.return_to_menu()
	await frames(4)
	await tap(KEY_ENTER)
	await move()
	at(app.course.relays[0].position)
	await frames(3)
	at(Vector2(2500, 700))
	await frames(4)
	var count_at_failure: int = app.relay_count
	var triggers_at_failure: int = relay().presentation_state().sound_triggers
	app._queue_relay("relay_two")
	app.relay_activated.emit("relay_two", 0.9, 2)
	await frames(8)
	check("failed_round_rejects_late_reward_and_feedback", app.phase == "failed" and app.relay_count == count_at_failure and relay().presentation_state().sound_triggers == triggers_at_failure and not relay().presentation_state().toast_visible and not wave().presentation_state().relay_delay_visible, {"phase": app.phase, "count": app.relay_count, "node": relay().presentation_state()}, "position-and-late-event-fixture")
	await shot("failure")
	await tap(KEY_ENTER)
	check("result_enter_restarts_station", app.phase == "ready" and app.relay_count == 0 and app.level_id == "relay_station" and not app.player.dead, {"phase": app.phase, "count": app.relay_count, "level": app.level_id})
	root.remove_child(app)
	app.free()
	await frames(8)
	await create_timer(0.15).timeout
	var passed := checks.all(func(row): return row.passed)
	var file := FileAccess.open(OUT + "runtime-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": "v0.3.0+8f8f69c021f9", "passed": passed, "checks": checks, "godot": Engine.get_version_info().string, "renderer": RenderingServer.get_video_adapter_name(), "scope": "Actual keyboard paths plus explicitly marked position/contact/event fixtures. No full-route or player-study claims."}, "\t"))
	file.close()
	quit(0 if passed else 1)
