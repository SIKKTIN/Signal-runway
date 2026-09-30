extends SceneTree
const OUT := "res://reports/v0.3/art/"
var checks: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for _i in count:
		await process_frame

func check(label: String, passed: bool, actual: Variant = "") -> void:
	checks.append({"check": label, "passed": passed, "actual": actual})
	print(label, ": ", passed, " ", actual)

func run() -> void:
	var app: Node2D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await frames(4)
	app.start_challenge(false, "pursuit", "relay_station")
	app.set_physics_process(false)
	app.player.set_physics_process(false)
	app.phase = "running"
	await frames(2)
	var relay: Node2D = app.world.get_node("RelayVisual")
	var wave: Node2D = app.world.get_node("ChaseVisual")
	var first_id: String = app.course.relays[0].id
	app._queue_relay(first_id)
	await frames(2)
	check("root_public_activation_reaches_presentation", app.relay_count == 1 and relay.presentation_state().sound_triggers == 1 and relay.presentation_state().node_states[first_id] == "activating")
	check("root_delay_event_reaches_hud", is_equal_approx(app.relay_delay_remaining, 0.9) and wave.presentation_state().relay_delay_visible)
	wave.bind_flow(app, app.chase)
	check("late_bind_reads_existing_delay", is_equal_approx(wave.presentation_state().relay_delay_remaining, 0.9) and wave.presentation_state().relay_delay_visible)
	app.start_challenge(false, "time_trial", "relay_station")
	app.player.set_physics_process(false)
	app.phase = "running"
	first_id = app.course.relays[0].id
	app._queue_relay(first_id)
	await frames(2)
	relay = app.world.get_node("RelayVisual")
	wave = app.world.get_node("ChaseVisual")
	check("root_trial_counts_without_delay", app.relay_count == 1 and app.relay_delay_remaining == 0 and relay.presentation_state().sound_triggers == 1 and not wave.presentation_state().relay_delay_visible)
	app.start_challenge(true, "time_trial")
	await frames(4)
	check("lab_boolean_compatible", app.lab_mode and app.world.has_node("RelayVisual") and app.world.get_node("RelayVisual").presentation_state().node_states.is_empty())
	root.remove_child(app)
	app.free()
	await frames(8)
	await create_timer(0.15).timeout
	var passed := checks.all(func(row): return row.passed)
	var file := FileAccess.open(OUT + "relay-root.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "fixture": "Formal RunFlow event candidates and late bind; no route/collision proof. Shared layout under development."}, "\t"))
	file.close()
	quit(0 if passed else 1)
