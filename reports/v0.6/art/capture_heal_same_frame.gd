extends "res://reports/v0.6/art/check_main.gd"
## Only verify the producer's immediate UI sync; preserve original E captures.
func run() -> void:
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size=Vector2i(960,540)
	root.size=Vector2i(960,540)
	app=load("res://scenes/main/main.tscn").instantiate()
	app.record_path=OUT+"isolated-same-frame-record.json"
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
	for _i in 500:
		step_input("heal")
		await frames(1)
		if not station_events.is_empty() or app.phase=="failed":
			break
	# No extra physics frames after the first station event, no manual UI refresh.
	var life: Dictionary=app._survival_status.presentation_state()
	var event_data: Dictionary=station_events[0] if not station_events.is_empty() else {}
	check("first_station_event_frame_life_UI_matches",event_data.get("amount",0)==1 and app.player.health==3 and life.health==3 and life.hurt_count==1 and life.animation_time>1,{"event":event_data,"player_health":app.player.health,"life":life,"elapsed":app.elapsed,"physics_frame":Engine.get_physics_frames()})
	await shot("same-frame-healed-960")
	var source_hash:=FileAccess.get_sha256("res://scripts/level/run_flow.gd")
	key(false)
	root.remove_child(app)
	app.free()
	await frames(8)
	OS.delay_msec(150)
	var file:=FileAccess.open(OUT+"same-frame-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":checks.all(func(row):return row.passed),"checks":checks,"run_flow_sha256":source_hash,"method":"Producer immediate UI fix only: same seeded first-station380/position/2life/gap fixtures as E. Sample first event process frame without extra physics waits or manual UI update. Original E evidence unchanged."},"\t"))
	file.close()
	quit(0 if checks.all(func(row):return row.passed) else 1)
