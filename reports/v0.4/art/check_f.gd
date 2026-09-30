extends SceneTree
## Production-scene visual fixtures; no claim of ordinary-input routes.
const OUT := "res://reports/v0.4/art/"
var app: Node2D
var checks: Array[Dictionary] = []
var max_modules := 0
var max_relays := 0
var rebase_count := 0

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame

func check(name: String, passed: bool, actual: Variant = "") -> void:
	checks.append({"check": name, "passed": passed, "actual": actual})
	print(name, ": ", passed, " ", actual)

func component(name: String) -> Node:
	return app.world.get_node(name)

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")

func fixture() -> void:
	app.set_physics_process(false)
	app.player.set_physics_process(false)
	app.camera.position_smoothing_enabled = false
	app.camera.position = Vector2(480, 270)
	app.camera.reset_smoothing()

func clocks() -> Array:
	return [component("EndlessWorldVisual").presentation_state().animation_time,
		component("EnvironmentVisual").presentation_state().animation_time,
		component("RelayVisual").presentation_state().animation_time,
		component("ChaseVisual").presentation_state().animation_time,
		component("EndlessHUDVisual").presentation_state().animation_time]

func freeze_visuals(value: bool) -> void:
	for name in ["EndlessWorldVisual", "EnvironmentVisual", "RelayVisual", "ChaseVisual", "EndlessHUDVisual"]:
		component(name).set_process(not value)
	app.player.get_node("Visual").set_process(not value)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "f-frames"))
	app = load("res://scenes/main/main.tscn").instantiate()
	app.record_path = OUT + "fixture-record.json"
	root.add_child(app)
	await frames(4)
	app.start_endless(43127)
	fixture()
	await frames(4)
	check("production_components_and_old_hud_visibility", app.world.has_node("EndlessWorldVisual") and app.world.has_node("EndlessHUDVisual") and not app.ui.hud.visible)
	check("one_decoration_per_active_chunk", component("EndlessWorldVisual").presentation_state().module_count == app.course.chunks.size())
	var geometry_before: PackedByteArray = var_to_bytes([app.course.chunks, app.course.floors, app.course.walls, app.course.spikes, app.course.gaps, app.course.relays])
	var index_before: int = app.course.generator.index
	component("EndlessWorldVisual").bind_flow(app, app.course)
	component("RelayVisual").bind_flow(app, app.course)
	component("EndlessHUDVisual").bind_flow(app)
	check("presentation_rebind_preserves_seed_geometry_generator", app.run_seed == 43127 and app.course.generator.index == index_before and geometry_before == var_to_bytes([app.course.chunks, app.course.floors, app.course.walls, app.course.spikes, app.course.gaps, app.course.relays]))
	await shot("f-running")
	app.catchup_bonus = 14
	app.chase.speed = 296
	app.chase.front_x = 95
	app.chase.grace_remaining = 0
	app.chase.advance(0, 728)
	await frames(3)
	check("catchup_title_speed_and_gap", component("ChaseVisual")._hud_title.text == "远距追速" and component("ChaseVisual")._hud_detail.text.contains("296"))
	await shot("f-catchup")
	app.chase.add_relay_delay(0.9)
	await frames(2)
	await shot("f-catchup-delay")
	app.toggle_pause()
	await frames(3)
	var paused_clocks := clocks()
	await shot("f-pause-a")
	await frames(24)
	await shot("f-pause-b")
	check("pause_freezes_all_five_visual_clocks", clocks() == paused_clocks)
	app.toggle_pause()
	for index in 10:
		await frames(4)
		await shot("f-frames/motion-%02d" % index)
	check("resume_advances_all_five_visual_clocks", clocks()[0] > paused_clocks[0] and clocks()[3] > paused_clocks[3])
	# Place every coordinate together then freeze; compare an actual world shift.
	app.player.position = Vector2(34500, 430)
	app.chase.front_x = 34280
	app.chase.advance(0, 34490)
	app.course.update_stream(34500, 34280)
	app.camera.position = Vector2(34500, 270)
	app.camera.reset_smoothing()
	app.run_distance = 34404
	app._update_ui()
	await frames(4)
	freeze_visuals(true)
	await frames(2)
	await shot("f-rebase-before")
	var before_clocks := clocks()
	var modules_before: Dictionary = component("EndlessWorldVisual").presentation_state().modules
	var anchors_before := {}
	for id in component("EndlessWorldVisual")._modules:
		var module: Node2D = component("EndlessWorldVisual")._modules[id]
		anchors_before[id] = module.get_global_transform_with_canvas() * Vector2.ZERO
	app._shift_endless_world(25600)
	await frames(3)
	await shot("f-rebase-after")
	var modules_after: Dictionary = component("EndlessWorldVisual").presentation_state().modules
	var stable := modules_before.size() == modules_after.size()
	for id in modules_before:
		stable = stable and modules_after.has(id) and modules_before[id].pattern_offset == modules_after[id].pattern_offset and modules_before[id].phase_offset == modules_after[id].phase_offset
		var module: Node2D = component("EndlessWorldVisual")._modules[id]
		stable = stable and anchors_before[id].distance_to(module.get_global_transform_with_canvas() * Vector2.ZERO) < 0.01
	check("rebase_preserves_visual_clocks_and_module_phases", clocks() == before_clocks and stable)
	check("rebase_updates_environment_chase_offsets", component("EnvironmentVisual").presentation_state().world_offset == 25600 and component("ChaseVisual").presentation_state().world_offset == 25600)
	# Repeated complete production snapshots, not a 30-minute gameplay test.
	var bounded := true
	for index in 120:
		app.player.position.x += 1280
		app.chase.front_x = app.player.position.x - 300
		app.chase.advance(0, app.player.position.x - 10)
		app.course.update_stream(app.player.position.x, app.chase.front_x)
		if app.player.position.x >= 32768:
			app._shift_endless_world(25600)
			rebase_count += 1
		for entry in app.course.relays:
			if app.course.activate_relay(entry.id):
				app.relay_count += 1
				app.relay_activated.emit(entry.id, 0.9, app.relay_count)
		var relay_state: Dictionary = component("RelayVisual").presentation_state()
		var module_count: int = component("EndlessWorldVisual").presentation_state().module_count
		max_modules = maxi(max_modules, module_count)
		max_relays = maxi(max_relays, relay_state.node_count)
		bounded = bounded and module_count == app.course.chunks.size() and relay_state.node_count == app.course.relays.size() and relay_state.activated_count <= relay_state.node_count and relay_state.pulse_count <= relay_state.node_count
		if index % 20 == 0:
			await frames(2)
	check("120_stream_snapshots_keep_all_caches_bounded", bounded, {"max_modules": max_modules, "max_relays": max_relays, "rebases": rebase_count})
	var relay_visual := component("RelayVisual")
	if not app.course.relays.is_empty():
		var sound_count: int = relay_visual.presentation_state().sound_triggers
		app.relay_activated.emit(app.course.relays[0].id, 0.9, app.relay_count)
		app.relay_activated.emit("retired:unknown", 0.9, app.relay_count)
		check("duplicate_and_retired_relays_are_silent", sound_count == relay_visual.presentation_state().sound_triggers)
	freeze_visuals(false)
	app._update_ui()
	app.player.die("caught")
	await frames(5)
	var ended := clocks()
	await frames(20)
	check("failure_freezes_visuals_and_hides_transients", ended == clocks() and not component("EndlessHUDVisual").presentation_state().gain_visible and not component("RelayVisual").presentation_state().toast_visible)
	await shot("f-result")
	app.restart_challenge()
	fixture()
	check("same_seed_restart_resets_visuals_and_offsets", app.run_seed == 43127 and clocks() == [0.0,0.0,0.0,0.0,0.0] and app.course.total_offset == 0)
	app.return_to_menu()
	await frames(3)
	check("menu_hides_endless_hud", not component("EndlessHUDVisual").presentation_state().hud_visible)
	# The station branch types are pictured through the actual main installer.
	app.endless_test_sequence.assign(["relay_b", "relay_a", "rhythm_a"])
	app.start_endless(43127)
	fixture()
	app.player.reset_at(Vector2(738, 430))
	app.player.set_physics_process(false)
	app.chase.grace_remaining = 0
	app.chase.front_x = 95
	app.chase.advance(0, 728)
	await frames(3)
	await shot("f-relay-available")
	var id: String = app.course.relays[0].id
	app._queue_relay(id)
	await frames(3)
	app._update_ui()
	await frames(2)
	check("production_relay_pulse_and_score_feedback", component("RelayVisual").presentation_state().node_states[id] == "activating" and component("EndlessHUDVisual").presentation_state().gain_visible)
	await shot("f-relay-activating")
	await frames(30)
	await shot("f-relay-activated")
	check("production_relay_settles_and_uses_total_count", component("RelayVisual").presentation_state().node_states[id] == "activated" and component("RelayVisual")._toast_text.text.contains("累计 1"))
	app.endless_test_sequence.clear()
	app.start_challenge(false, "time_trial", "relay_station")
	fixture()
	await frames(3)
	check("fixed_station_retains_hud_and_environment", not app.world.has_node("EndlessWorldVisual") and not app.world.has_node("EndlessHUDVisual") and app.ui.hud.visible and component("EnvironmentVisual").presentation_state().station_enabled)
	await shot("f-fixed-station")
	app.start_challenge(true, "time_trial")
	fixture()
	await frames(3)
	check("lab_retains_original_visibility", app.lab_mode and not app.world.has_node("EndlessHUDVisual") and not component("EnvironmentVisual").presentation_state().station_enabled)
	root.remove_child(app)
	check("exit_disconnects_world_shifted", app.get_signal_connection_list("world_shifted").is_empty())
	app.free()
	await frames(8)
	await create_timer(0.15).timeout
	var passed := checks.all(func(row): return row.passed)
	var file := FileAccess.open(OUT + "f-runtime.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "renderer": RenderingServer.get_video_adapter_name(), "fixture": "Fixed production scene and manual public-state snapshots; no ordinary input route or score proof."}, "\t"))
	file.close()
	quit(0 if passed else 1)
