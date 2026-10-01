extends SceneTree
## Final text-layout capture only, no D/F rule-suite repetition.
const OUT := "res://reports/v0.6/art/"
var checks: Array[Dictionary]=[]
func _initialize() -> void:
	call_deferred("run")
func frames(n: int) -> void:
	for _i in n:
		await physics_frame
		await process_frame
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
func run() -> void:
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size=Vector2i(960,540)
	root.size=Vector2i(960,540)
	var app: Node2D=load("res://scenes/main/main.tscn").instantiate()
	app.record_path=OUT+"isolated-layout-record.json"
	root.add_child(app)
	await frames(3)
	app.start_endless(404)
	app.set_physics_process(false)
	app.player.set_physics_process(false)
	app.course.update_stream(10000,-544)
	var chunk: Dictionary=app.course.chunks.filter(func(row):return row.geometry.has("challenge"))[0]
	app.camera.position_smoothing_enabled=false
	app.camera.position=Vector2(chunk.origin+620,270)
	app.camera.reset_smoothing()
	app.camera.force_update_scroll()
	var platform: Rect2=chunk.geometry.platforms[0]
	app.player.position=Vector2(chunk.origin+380,platform.position.y-16)
	app.routes.active=chunk.id
	app.routes.progress=3
	app.route_state_changed.emit(app.routes.snapshot())
	app.route_event.emit("progress",{"id":chunk.id,"progress":3,"total":3})
	await frames(3)
	await shot("final-challenge-wait-exit-960")
	checks.append({"check":"actual960_route_text_fits","passed":app._route_status.get_global_rect()==Rect2(420,450,280,60) and app._route_status.presentation_state().message.contains("前往出口")})
	app.routes.active=""
	app.route_state_changed.emit(app.routes.snapshot())
	app.route_event.emit("interrupted",{"id":chunk.id,"reason":"missed"})
	await frames(2)
	await shot("final-challenge-interrupted-960")
	root.remove_child(app)
	app.free()
	await frames(6)
	var editor: Control=load("res://scenes/tools/generation_editor.tscn").instantiate()
	root.add_child(editor)
	await frames(4)
	editor.play_draft()
	var trial: Node2D=editor.trial
	trial.set_physics_process(false)
	trial.player.set_physics_process(false)
	trial.routes.active="layout-fixture"
	trial.routes.progress=1
	trial.route_state_changed.emit(trial.routes.snapshot())
	trial.route_event.emit("started",{"id":"layout-fixture"})
	await frames(3)
	await shot("final-tool-active-route-960")
	var hint: Control=trial.ui.get_node("EditorReturnHint")
	checks.append({"check":"actual_tool_hint_life_and_route_bounds_clear","passed":not hint.get_global_rect().intersects(trial._route_status.get_global_rect()) and not trial._survival_status.get_global_rect().intersects(trial._route_status.get_global_rect())})
	editor.stop_trial()
	root.remove_child(editor)
	editor.free()
	await frames(8)
	OS.delay_msec(150)
	var file:=FileAccess.open(OUT+"layout-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":checks.all(func(row):return row.passed),"checks":checks,"method":"Final native text placement at960 in actualMain and tool trial, explicit state/position fixtures. No F/D rule tests; no actual F8 key claim. Exit includes150ms actual mixer cleanup."},"\t"))
	file.close()
	quit(0 if checks.all(func(row):return row.passed) else 1)
