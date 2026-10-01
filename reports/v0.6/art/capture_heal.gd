extends "res://reports/v0.6/art/check_main.gd"
## Targeted final heal/UI synchronization and actual380 at1280; not a whole-suite rerun.
func run() -> void:
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size=Vector2i(960,540)
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main/main.tscn").instantiate()
	app.record_path=OUT+"isolated-heal-record.json"
	root.add_child(app)
	await frames(3)
	app.start_endless(404)
	app.course.update_stream(33000,-544)
	var station: Dictionary=app.course.chunks.filter(func(row):return row.geometry.has("station"))[0]
	app.route_event.connect(on_event)
	app.player.position=Vector2(station.origin-1100,432)
	app.player.health=2
	app.player.hurt_count=1
	app.player.velocity=Vector2(380,0)
	app._previous_position=app.player.position
	app.trial_speed=380
	app.chase.front_x=app.player.position.x-1200
	camera_at(app.player.position+Vector2(180,-162))
	var first_visible := -1.0
	for _i in 500:
		step_input("heal")
		await frames(1)
		var info: Dictionary=world().station_presentation(station.id)
		if first_visible<0 and not info.is_empty() and Rect2(0,0,960,540).encloses(info.preview_rect):
			first_visible=app.elapsed
			await shot("final-380-advance-heal-1280")
		if not station_events.is_empty() or app.phase=="failed":
			break
	var window_seconds: float=app.elapsed-first_visible
	# Root applies route actions deferred after physics UI sync; allow two live frames.
	await frames(2)
	var life: Dictionary=app._survival_status.presentation_state()
	check("actual_heal_syncs_full_UI_without_clock_reset",app.player.health==3 and life.health==3 and life.hurt_count==1 and life.animation_time>1 and hud().presentation_state().message.contains("生命 +1"),life)
	check("actual380_1280_choice_window",first_visible>=0 and window_seconds>=1.2 and station_events[0].kind=="heal",window_seconds)
	await shot("final-380-healed-1280")
	root.size=Vector2i(960,540)
	await frames(2)
	await shot("final-380-healed-960")
	key(false)
	root.remove_child(app)
	app.free()
	await frames(8)
	OS.delay_msec(150)
	var file:=FileAccess.open(OUT+"heal-sync-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":checks.all(func(row):return row.passed),"checks":checks,"station_events":station_events,"scope":"One actual380 station heal approach at1280, explicit seeded start/2life/velocity/gap fixtures; wait2 live frames for deferred root UI synchronization then capture960. No new F or whole E rerun."},"\t"))
	file.close()
	quit(0 if checks.all(func(row):return row.passed) else 1)
