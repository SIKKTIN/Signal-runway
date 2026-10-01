extends SceneTree
## F presentation integration only; camera, location and speed fixtures are explicit.
const OUT := "res://reports/v0.5/art/"
var app: Node2D
var checks: Array[Dictionary] = []
var samples: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func frames(count: int, sync_ui: bool = true) -> void:
	for _i in count:
		await physics_frame
		await process_frame
		if sync_ui and is_instance_valid(app):
			app._update_ui()

func check(label: String, passed: bool, actual: Variant = "") -> void:
	checks.append({"check":label,"passed":passed,"actual":actual})
	print(label, ": ", passed)

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + label + ".png")

func status() -> Control:
	return app._survival_status

func camera_at(at: Vector2) -> void:
	app.camera.position_smoothing_enabled = false
	app.camera.position = at
	app.camera.reset_smoothing()
	app.camera.force_update_scroll()

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2, false)
	event = InputEventKey.new()
	event.keycode = code
	Input.parse_input_event(event)
	await frames(2, false)

func contact(spike: Rect2) -> void:
	# Move to an actual generated hazard approach; real Area/body physics do the injury.
	app.player.position = Vector2(spike.position.x - 56, spike.position.y + 2)
	app.player.velocity = Vector2(280, 0)
	app.player.move_speed = 280
	app.player.set_physics_process(true)
	var previous: int = app.player.health
	for _i in 24:
		await frames(1)
		if app.player.health < previous:
			break
	app.player.set_physics_process(false)
	app._update_ui()

func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(960,540)
	root.size = Vector2i(1280,720)
	app = load("res://scenes/main/main.tscn").instantiate()
	app.record_path = OUT + "temporary-record.json"
	root.add_child(app)
	await frames(4, false)
	app.start_endless(404)
	app.set_physics_process(false)
	app.player.set_physics_process(false)
	camera_at(Vector2(480,270))
	await frames(3)
	check("actual_Main_installs_status_and_v05_textures", status().enable_hurt_audio and app.course.streaming and app.generation_notice.is_empty() and app.course._textures.terrain_platform.resource_path.ends_with("v05/platform_cap.svg") and app.course._textures.terrain_solid.resource_path.ends_with("v05/ground_side.svg"))
	check("initial_real_snapshot_full_and_silent", status().presentation_state().health == 3 and status().presentation_state().hurt_pulses == 0)
	check("status_bounds_leave_floor_and_F8_space", status().get_global_rect() == Rect2(24,450,380,60) and status().mouse_filter == Control.MOUSE_FILTER_IGNORE)
	await shot("main-full-1280")
	# Generate more of the real seed without changing geometry/RNG or claiming route play.
	app.course.update_stream(14000, -544)
	var geometry_matches := true
	var types: Dictionary = {}
	for chunk in app.course.chunks:
		var d: Dictionary = chunk.geometry
		var bodies: Array[Rect2] = []
		bodies.assign(d.floors + d.walls + d.platforms)
		var solids: Array[Rect2] = []
		for child in app.course._holders[chunk.id].get_children():
			if child is StaticBody2D:
				var collider: CollisionShape2D = child.get_child(0)
				solids.append(Rect2(child.position-collider.shape.size/2,collider.shape.size))
		geometry_matches = geometry_matches and var_to_bytes(solids) == var_to_bytes(bodies)
		if not d.get("vertical", false) or types.has(d.structure):
			continue
		types[d.structure] = true
		app.player.position = Vector2(chunk.origin+190,430)
		if d.structure == "下沉回升":
			var low: Rect2 = d.floors[2]
			app.player.position = Vector2(chunk.origin+low.get_center().x,low.position.y-16)
		camera_at(Vector2(chunk.origin+620,clampf(app.player.position.y-163,270,420)))
		await frames(3)
		var label: String = "main-geometry-%02d-1280" % samples.size()
		await shot(label)
		samples.append({"image":label+".png","chunk":chunk.id,"structure":d.structure,"variant":d.variant,"parameters":d.parameters,"fixture":"Camera/player position on actual seed404 geometry; no route completion claim."})
	check("render_snapshot_and_actual_static_body_rectangles_match", geometry_matches)
	check("actual_generated_vertical_samples_present", samples.size() >= 3, samples)
	# Distinct actual/target speed display is a read-only injected snapshot fixture.
	app.target_run_speed = 350
	app.player.velocity.x = 330
	await frames(2)
	check("actual_and_target_fields_remain_distinct", status().presentation_state().actual_speed == 330 and status().presentation_state().target_speed == 350)
	await shot("main-accelerating-1280")
	var spike: Rect2 = app.course.spikes[0]
	camera_at(Vector2(maxf(480,spike.position.x+100),270))
	await contact(spike)
	var hurt: Dictionary = status().presentation_state()
	var cue: AudioStreamPlayer = status().get_node("OptionalHurtCue")
	check("actual_generated_spike_triggers_one_cue_and_life_display", app.player.health == 2 and hurt.health == 2 and hurt.invulnerable and hurt.hurt_pulses == 1 and cue.playing, hurt)
	for _i in 5:
		app._update_ui()
	check("repeated_real_UI_sync_does_not_repeat_cue", status().presentation_state().hurt_pulses == 1)
	await shot("main-hurt-1280")
	app.toggle_pause()
	app._update_ui()
	await frames(2)
	var before: Dictionary = status().presentation_state()
	await shot("main-paused-a")
	await frames(20)
	await shot("main-paused-b")
	var after: Dictionary = status().presentation_state()
	check("Main_pause_preserves_pulse_clock_and_audio", before.feedback_active and before.hurt_remaining > 0 and before.hurt_remaining == after.hurt_remaining and before.animation_time == after.animation_time and cue.stream_paused)
	app.toggle_pause()
	app._update_ui()
	await frames(2)
	check("Main_resume_continues_hurt_pulse", status().presentation_state().hurt_remaining > 0 and status().presentation_state().hurt_remaining < before.hurt_remaining and not cue.stream_paused)
	root.size = Vector2i(960,540)
	await frames(2)
	await shot("main-hurt-960")
	await frames(42)
	check("local_pulse_expires_once", status().presentation_state().hurt_remaining == 0 and status().presentation_state().hurt_pulses == 1)
	# Separate second-contact fixture clears invulnerability, not a timing-rule test.
	app.player.invulnerable_remaining = 0
	app.player.position = Vector2(spike.position.x-120,430)
	await frames(3)
	await contact(spike)
	check("one_life_uses_numeric_and_empty_heart_shapes", status().presentation_state().health == 1 and status().presentation_state().hurt_pulses == 2)
	await shot("main-low-960")
	app.player.die("caught")
	await frames(4)
	check("actual_result_hides_status_and_stops_cue", app.phase == "failed" and not status().visible and not cue.playing and not status().presentation_state().feedback_active)
	await shot("main-result-960")
	app.restart_challenge()
	app.set_physics_process(false)
	app.player.set_physics_process(false)
	app._update_ui()
	check("restart_full_life_without_stale_hurt", status().presentation_state().health == 3 and status().presentation_state().hurt_pulses == 0)
	app.return_to_menu()
	app._update_ui()
	check("menu_hides_status_and_stops_cue", not status().visible and not status().get_node("OptionalHurtCue").playing)
	root.remove_child(app)
	app.free()
	app = null
	# Only F8 layout/return appearance; D functional suite belongs to producer.
	var editor := preload("res://scripts/tools/generation_editor.gd").new()
	editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(editor)
	await frames(3, false)
	editor.set_draft(preload("res://scripts/level/generation_profile.gd").defaults())
	editor.play_draft()
	await frames(10, false)
	check("tool_trial_installs_status", is_instance_valid(editor.trial._survival_status))
	await shot("main-tool-960")
	await key(KEY_F8)
	check("actual_F8_returns_to_editor", not is_instance_valid(editor.trial) and editor.preview.visible)
	root.remove_child(editor)
	editor.free()
	await frames(8, false)
	await create_timer(.15).timeout
	if FileAccess.file_exists(OUT+"temporary-record.json"):
		DirAccess.remove_absolute(OUT+"temporary-record.json")
	var passed: bool = checks.all(func(row): return row.passed)
	var file := FileAccess.open(OUT+"main-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"samples":samples,"seed":404,"renderer":RenderingServer.get_video_adapter_name(),"scope":"F presentation integration on actual Main. Fixed camera, disabled root clock/physics, location and target/velocity fixtures. Hurt via actual generated spike overlap; second fixture resets invulnerability. Tool F8 is synthetic Input.parse_input_event. No human input/route/recovery/acceleration-rule/audio-listening claim. G awaits final frozen build."},"\t"))
	file.close()
	quit(0 if passed else 1)
