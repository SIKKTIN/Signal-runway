extends SceneTree

var checks: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("_run")


func frames(count: int) -> void:
	for index in range(count):
		await process_frame


func check(label: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"check": label, "passed": passed, "detail": detail})
	print(label, " ", passed, " ", detail)


func _run() -> void:
	var preview: Node2D = load("res://scenes/visual/chase_preview.tscn").instantiate()
	root.add_child(preview)
	await frames(12)
	var visual: Node2D = preview.presentation
	var chase: Node = preview.chase
	chase.front_x = 222.0
	chase.gap_px = 546.0
	chase.warning_level = "urgent"
	chase.grace_remaining = 0.0
	visual.bind_flow(preview, chase)
	var state: Dictionary = visual.presentation_state()
	check("initial_properties_without_event", state.front_x == 222.0 and state.gap_px == 546.0 and state.warning_level == "urgent")
	var loop := visual.get_node("ThreatLoop") as AudioStreamPlayer
	var cue := visual.get_node("WarningCue") as AudioStreamPlayer
	var caught := visual.get_node("CaughtCue") as AudioStreamPlayer
	check("single_loop_and_audio_loaded", loop.stream is AudioStreamWAV and loop.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and loop.playing and visual.get_child_count() == 4)
	await frames(6)
	var loop_before: float = loop.get_playback_position()
	var cue_before: float = cue.get_playback_position()
	for index in range(30):
		chase.threat_updated.emit(222.0, 546.0, "urgent", 0.0)
	await frames(2)
	check("duplicate_rank_does_not_restart", loop.get_playback_position() >= loop_before and cue.get_playback_position() >= cue_before,
		{"loop_before": loop_before, "loop_after": loop.get_playback_position(), "cue_before": cue_before, "cue_after": cue.get_playback_position()})
	preview.pause_changed.emit(true)
	var clock_before: float = visual.presentation_state().animation_time
	await frames(8)
	state = visual.presentation_state()
	check("pause_freezes_visual_and_loop", state.loop_paused and state.animation_time == clock_before and not cue.playing)
	preview.pause_changed.emit(false)
	await frames(2)
	state = visual.presentation_state()
	check("resume_loop", state.loop_playing and not state.loop_paused)
	preview.mode = "time_trial"
	preview.mode_changed.emit("time_trial")
	state = visual.presentation_state()
	check("time_trial_stops_and_hides", not state.loop_playing and not state.hud_visible and state.mode == "time_trial")
	preview.mode = "pursuit"
	preview.mode_changed.emit("pursuit")
	preview.phase = "failed"
	chase.sample(222.0, 546.0, "stopped")
	preview.run_failed.emit("caught", 22.0, .4)
	await frames(3)
	var caught_before: float = caught.get_playback_position()
	preview.run_failed.emit("caught", 22.0, .4)
	await frames(2)
	state = visual.presentation_state()
	check("result_stops_loop_and_caught_once", not state.loop_playing and not state.hud_visible and caught.playing and caught.get_playback_position() >= caught_before)
	preview.run_finished.emit(40.0, 0, 40.0)
	check("success_stops_all_audio", not loop.playing and not cue.playing and not caught.playing)
	preview.phase = "menu"
	visual.bind_flow(preview, chase)
	state = visual.presentation_state()
	check("menu_initial_state_silent", not state.loop_playing and not state.hud_visible)
	preview.phase = "ready"
	chase.sample(-500.0, 1268.0, "grace", 2.0)
	await frames(2)
	state = visual.presentation_state()
	check("restart_grace_resets_result", not state.resolved and state.hud_visible and not state.loop_playing and not state.loop_paused)
	for index in range(5):
		visual.bind_flow(preview, chase)
	check("rebind_has_one_subscription", chase.get_signal_connection_list("threat_updated").size() == 1)
	check("failure_reasons_have_distinct_icons", visual.failure_presentation("spike").icon_path != visual.failure_presentation("caught").icon_path)
	chase.sample(200.0, 568.0, "near")
	await frames(2)
	root.remove_child(preview)
	check("exit_stops_and_releases_streams", not loop.playing and not caught.playing and loop.stream == null and cue.stream == null and caught.stream == null)
	preview.free()
	await frames(10)
	await create_timer(.12).timeout
	var passed := true
	for row in checks:
		passed = passed and bool(row.passed)
	var file := FileAccess.open("res://reports/v0.2/art/lifecycle-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "checks": checks}, "  "))
	file.close()
	quit(0 if passed else 1)
