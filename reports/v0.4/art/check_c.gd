extends SceneTree
const OUT := "res://reports/v0.4/art/"
var preview: Node2D
var checks: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for _i in count:
		await process_frame
		await physics_frame

func check(name: String, passed: bool) -> void:
	checks.append({"check": name, "passed": passed})
	print(name, ": ", passed)

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "c-frames"))
	preview = load("res://scenes/visual/endless_art_preview.tscn").instantiate()
	root.add_child(preview)
	await frames(5)
	check("no_physics_objects_added", preview.find_children("*", "CollisionObject2D", true, false).is_empty())
	check("initial_snapshot_has_no_gain_or_record", not preview.hud.presentation_state().gain_visible and not preview.hud.presentation_state().record_visible)
	await shot("c-relay")
	preview.set_template("safe_b")
	await frames(3)
	await shot("c-safe")
	preview.set_template("wall_a")
	await frames(3)
	await shot("c-wall")
	preview.set_template("relay_a")
	preview.gain_demo()
	await frames(3)
	check("relay_feedback_and_record_visible", preview.hud.presentation_state().gain_visible and preview.hud.presentation_state().record_visible)
	await shot("c-gain")
	var record_end: float = preview.hud._record_until
	preview.sample(1001, 9010, 1, 1)
	check("distance_update_does_not_retrigger_record", preview.hud._record_until == record_end)
	preview.set_paused(true)
	await frames(3)
	var clocks: Array = [preview._clock, preview.hud.presentation_state().animation_time, preview.relay.presentation_state().animation_time]
	await shot("c-pause-a")
	await frames(25)
	await shot("c-pause-b")
	check("pause_freezes_all_clocks", clocks == [preview._clock, preview.hud.presentation_state().animation_time, preview.relay.presentation_state().animation_time])
	preview.set_paused(false)
	for index in 12:
		await frames(4)
		await shot("c-frames/motion-%02d" % index)
	await frames(40)
	check("gain_and_record_expire", not preview.hud.presentation_state().gain_visible and not preview.hud.presentation_state().record_visible)
	var module_state: Dictionary = preview.module.presentation_state()
	preview.module.set_world_offset(-25600, 25600)
	var shifted: Dictionary = preview.module.presentation_state()
	check("module_rebase_preserves_absolute_phase", module_state.pattern_offset == shifted.pattern_offset and module_state.phase_offset == shifted.phase_offset and module_state.animation_time == shifted.animation_time)
	preview.module.set_world_offset(0, 0)
	preview.show_result()
	await frames(3)
	await shot("c-result")
	check("result_hides_transient_feedback", preview.hud.presentation_state().resolved and not preview.hud.presentation_state().gain_visible and not preview.hud.presentation_state().record_visible)
	preview.reset_preview()
	check("reset_clears_run_pulses", preview._clock == 0 and not preview.hud.presentation_state().record_announced and preview.hud._pulse_until < 0)
	for _i in 4:
		preview.hud.bind_flow(preview)
	check("rebind_keeps_single_stats_listener", preview.get_signal_connection_list("endless_stats_changed").size() == 1)
	var seed_before: int = preview.run_seed
	preview.module.configure({"id": "fixture:123", "category": "wall", "origin": 1280, "length": 1280})
	check("decoration_never_mutates_seed_or_stats", preview.run_seed == seed_before and preview.run_score == 900)
	root.remove_child(preview)
	check("exit_disconnects_stats_listener", preview.get_signal_connection_list("endless_stats_changed").is_empty())
	preview.free()
	await frames(8)
	await create_timer(0.15).timeout
	var passed := checks.all(func(row): return row.passed)
	var file := FileAccess.open(OUT + "c-runtime.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "renderer": RenderingServer.get_video_adapter_name(), "fixture": "Independent mock snapshots; no physics or score formula test."}, "\t"))
	file.close()
	quit(0 if passed else 1)
