extends SceneTree
const OUT := "res://reports/v0.3/art/"
var preview: Node2D
var checks: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for _i in count:
		await process_frame

func check(name: String, passed: bool, actual: Variant = "") -> void:
	checks.append({"check": name, "passed": passed, "actual": actual})
	print(name, ": ", passed, " ", actual)

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "frames"))
	preview = load("res://scenes/visual/relay_preview.tscn").instantiate()
	root.add_child(preview)
	await frames(6)
	check("initial_two_available_nodes", preview.relay.presentation_state().node_states == {"relay_01": "available", "relay_02": "available"})
	await shot("available")
	var initial_clock: float = preview.chase_visual.presentation_state().animation_time
	preview.activate("relay_01")
	check("instant_activation_and_loaded_sound", preview.relay.presentation_state().node_states.relay_01 == "activating" and preview.relay.presentation_state().sound_triggers == 1 and preview.relay.presentation_state().sound_playing)
	check("relay_delay_hud_visible", preview.chase_visual.presentation_state().relay_delay_visible and preview.chase_visual.presentation_state().relay_delay_remaining == 0.9)
	await shot("activating")
	for index in 12:
		await frames(3)
		await shot("frames/relay-%02d" % index)
	check("delay_keeps_wave_rolling_with_fixed_front", preview.chase.front_x == 95 and preview.chase_visual.presentation_state().animation_time > initial_clock + 0.5)
	check("activated_closed_state", preview.relay.presentation_state().node_states.relay_01 == "activated")
	await shot("activated")
	var triggers: int = preview.relay.presentation_state().sound_triggers
	preview.relay_activated.emit("relay_01", 0.9, 1)
	check("duplicate_event_is_silent", preview.relay.presentation_state().sound_triggers == triggers)
	preview.activate("relay_02")
	preview.phase = "paused"
	preview.pause_changed.emit(true)
	var clock: float = preview.relay.presentation_state().animation_time
	var wave_clock: float = preview.chase_visual.presentation_state().animation_time
	var delay: float = preview.relay_delay_remaining
	await shot("pause-a")
	await frames(18)
	await shot("pause-b")
	check("pause_freezes_node_wave_delay_and_audio", preview.relay.presentation_state().animation_time == clock and preview.chase_visual.presentation_state().animation_time == wave_clock and preview.relay_delay_remaining == delay and preview.relay.presentation_state().sound_paused)
	preview.phase = "running"
	preview.pause_changed.emit(false)
	await frames(8)
	check("resume_advances_and_unpauses_sound", preview.relay.presentation_state().animation_time > clock and not preview.relay.presentation_state().sound_paused)
	await frames(70)
	check("delay_and_toast_expire", not preview.chase_visual.presentation_state().relay_delay_visible and not preview.relay.presentation_state().toast_visible)
	preview.phase = "failed"
	preview.run_failed.emit("caught", 4.0, 0.2)
	clock = preview.relay.presentation_state().animation_time
	await frames(10)
	preview.relay_activated.emit("relay_01", 0.9, 2)
	check("failure_freezes_and_rejects_late_feedback", preview.relay.presentation_state().animation_time == clock and not preview.relay.presentation_state().sound_playing and not preview.relay.presentation_state().toast_visible and not preview.chase_visual.presentation_state().relay_delay_visible)
	preview.phase = "running"
	preview.reset_nodes()
	preview.relay.bind_flow(preview, preview)
	preview.chase_visual.bind_flow(preview, preview.chase)
	check("rebind_resets_clock_nodes_delay_and_audio", preview.relay.presentation_state().animation_time == 0 and preview.relay.presentation_state().sound_triggers == 0 and preview.relay.presentation_state().node_states.relay_01 == "available" and not preview.chase_visual.presentation_state().relay_delay_visible)
	preview.mode = "time_trial"
	preview.mode_changed.emit("time_trial")
	preview.activate("relay_01")
	await frames(2)
	check("time_trial_feedback_without_delay", preview.relay.presentation_state().sound_triggers == 1 and preview.relay.presentation_state().toast_visible and not preview.chase_visual.presentation_state().relay_delay_visible and preview.relay_delay_remaining == 0)
	await shot("time-trial")
	preview.phase = "finished"
	preview.run_finished.emit(8, 0, 8)
	clock = preview.relay.presentation_state().animation_time
	await frames(10)
	check("success_freezes_clears_audio_and_toast", preview.relay.presentation_state().animation_time == clock and not preview.relay.presentation_state().sound_playing and not preview.relay.presentation_state().toast_visible)
	for _i in 4:
		preview.relay.bind_flow(preview, preview)
		preview.chase_visual.bind_flow(preview, preview.chase)
	check("rebind_subscription_count", preview.get_signal_connection_list("relay_activated").size() == 1 and preview.get_signal_connection_list("relay_delay_changed").size() == 2)
	var sound: AudioStreamPlayer = preview.relay.get_node("RelayConnect")
	root.remove_child(preview)
	check("exit_disconnects_and_releases_sound", sound.stream == null and not sound.playing and preview.get_signal_connection_list("relay_activated").is_empty())
	preview.free()
	await frames(8)
	await create_timer(0.15).timeout
	var passed := checks.all(func(row): return row.passed)
	var file := FileAccess.open(OUT + "relay-lifecycle.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "godot": Engine.get_version_info().string, "fixture": "Frozen public interface preview; fixed front. Not gameplay or route proof."}, "\t"))
	file.close()
	quit(0 if passed else 1)
