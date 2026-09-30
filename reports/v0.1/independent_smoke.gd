extends SceneTree

var app: Node2D
var events: Dictionary = {}
var audio_on_event: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame


func observe(action: String) -> void:
	events[action] = int(events.get(action, 0)) + 1
	var sound := app.player.get_node_or_null("Visual/Sfx_" + action) as AudioStreamPlayer
	audio_on_event[action] = sound != null and sound.stream != null and sound.playing


func _run() -> void:
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await frames(6)
	var menu_ok: bool = app.phase == "menu" and app.ui.overlay.visible
	app.ui.start_requested.emit()
	await frames(8)
	var visual: Node = app.player.get_node_or_null("Visual")
	var visual_ok: bool = visual != null and app.player.fallback_visual_enabled == false
	app.player.action_triggered.connect(observe)
	Input.action_press("jump")
	await frames(3)
	Input.action_release("jump")
	await frames(95)
	var jump_and_land: bool = int(events.get("jump", 0)) >= 1 and int(events.get("land", 0)) >= 1
	# The wall-jump mechanic is checked in the producer's route; this tests only
	# the public event -> visual/SFX bridge without changing player physics.
	app.player.action_triggered.emit("wall_jump")
	await frames(2)
	app.player.reset_at(Vector2(622, 433))
	await frames(4)
	var real_spike_death: bool = app.deaths == 1 and app.phase == "recovering"
	await frames(22)
	var recovered: bool = app.phase == "running" and not app.player.dead
	app.player.reset_at(Vector2(app.course.finish_x, 430))
	await frames(6)
	var finished: bool = app.phase == "finished" and int(events.get("finish", 0)) == 1
	var result := {
		"menu_ok": menu_ok,
		"visual_attached": visual_ok,
		"real_jump_and_land_events": jump_and_land,
		"real_spike_death_once": real_spike_death,
		"recovered": recovered,
		"goal_event_finished_once": finished,
		"event_counts": events,
		"audio_playing_during_event": audio_on_event,
		"note": "wall_jump event is synthetic for audio bridge; producer route verifies physical wall jump"
	}
	var file := FileAccess.open("res://reports/v0.1/independent_runtime.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  "))
	file.close()
	print("INDEPENDENT_SMOKE ", JSON.stringify(result))
	var passed: bool = menu_ok and visual_ok and jump_and_land and real_spike_death and recovered and finished
	for action in ["jump", "wall_jump", "land", "death", "finish"]:
		passed = passed and bool(audio_on_event.get(action, false))
	quit(0 if passed else 1)
