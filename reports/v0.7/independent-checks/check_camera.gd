extends "res://reports/v0.7/independent-checks/check_routes.gd"
## G camera only. Prior full natural/business/tool results remain unchanged.
var camera_runs: Array[Dictionary]=[]
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT_F+"g-"+label+".png")
func view_sample(chunk: Dictionary) -> Dictionary:
	var rect: Rect2=chunk.geometry.platforms[0]
	var transform: Transform2D=app.course.get_global_transform_with_canvas()
	var corner: Vector2=transform*(rect.position+Vector2(chunk.origin,0))
	var far: Vector2=transform*(rect.position+Vector2(chunk.origin+rect.size.x,4))
	var white: Rect2=Rect2(corner,far-corner)
	var feet: Vector2=app.player.get_global_transform_with_canvas()*Vector2(0,15)
	var life: Rect2=app._survival_status.get_global_rect()
	var route: Rect2=app._route_status.get_global_rect()
	return {"elapsed":app.elapsed,"distance":app.run_distance,"player":str(app.player.position),"camera":str(app.camera.position),"feet_canvas":str(feet),"first_white_canvas":str(white),"life_rect":str(life),"route_rect":str(route),"foot_clear":not life.has_point(feet) and not route.has_point(feet),"white_clear":not white.intersects(life) and not white.intersects(route),"white_inside_view":Rect2(0,0,960,540).encloses(white),"health":app.player.health,"grounded":app.player.is_on_floor(),"camera_smoothing_enabled":app.camera.position_smoothing_enabled}
func run() -> void:
	print("V07_G_CAMERA_PID ",OS.get_process_id())
	var before:=source_hashes()
	var records_before:=formal_records()
	check("109_new_camera_candidate_matches_before",before.mismatches.is_empty(),before.version)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size=Vector2i(960,540)
	root.size=Vector2i(960,540)
	if not before.mismatches.is_empty():
		quit(2)
		return
	for seed_value in [404,77,9001]:
		released()
		route_choice="upper"
		presses=0
		route_events.clear()
		app=load("res://scenes/main/main.tscn").instantiate()
		app.record_path=OUT_F+"isolated-camera-%d.json"%seed_value
		root.add_child(app)
		await frames(3)
		app.route_event.connect(on_route)
		app.start_endless(seed_value)
		var wall_begin:=Time.get_ticks_msec()
		var station: Dictionary={}
		var selection: Dictionary={}
		var landing: Dictionary={}
		var neighboring: Array[Dictionary]=[]
		var pause_checked:=false
		for frame in 12000:
			if app.phase!="running":
				break
			step_input()
			await frames(1)
			if station.is_empty():
				for chunk in app.course.chunks:
					if chunk.geometry.has("station"):
						station=chunk
						break
			if station.is_empty():
				continue
			var actual_x: float=app.player.position.x-station.origin
			var first: Rect2=station.geometry.platforms[0]
			var chosen: bool=route_events.any(func(row):return row.kind=="station" and row.data.id==station.id)
			if chosen and selection.is_empty():
				await RenderingServer.frame_post_draw
				selection=view_sample(station)
				await shot("natural-%d-selected-960"%seed_value)
			if actual_x>=first.position.x and actual_x<=first.end.x and app.player.is_on_floor() and absf(app.player.position.y+15-first.position.y)<4:
				await RenderingServer.frame_post_draw
				var sample: Dictionary=view_sample(station)
				neighboring.append(sample)
				if landing.is_empty():
					landing=sample
					await shot("natural-%d-first-landing-960"%seed_value)
			if seed_value==404 and not landing.is_empty() and not pause_checked:
				await tap(KEY_ESCAPE)
				var paused_snapshot: Array=[app.elapsed,app.player.position,app.chase.front_x,app.camera.position,app.world.get_node("SpatialVisual").presentation_state()]
				await shot("camera-pause-a")
				await frames(20)
				await shot("camera-pause-b")
				check("actual_Esc_freezes_new_camera_and_world",app.phase=="paused" and paused_snapshot==[app.elapsed,app.player.position,app.chase.front_x,app.camera.position,app.world.get_node("SpatialVisual").presentation_state()])
				await tap(KEY_ESCAPE)
				pause_checked=true
			if chosen and not landing.is_empty() and actual_x>first.end.x+48:
				break
		released()
		var safe: bool=not selection.is_empty() and not landing.is_empty() and selection.foot_clear and selection.white_clear and landing.foot_clear and landing.white_clear and landing.white_inside_view and neighboring.all(func(row):return row.foot_clear and row.white_clear)
		var result: Dictionary={"seed":seed_value,"strategy":"upper","elapsed":app.elapsed,"wall_seconds":float(Time.get_ticks_msec()-wall_begin)/1000,"health":app.player.health,"hurt":app.player.hurt_count,"phase":app.phase,"score":app.run_score,"breakdown":app.score_breakdown(),"first_station_index":station.get("index",-1),"selection":selection,"landing":landing,"landing_samples":neighboring,"key_presses":presses,"timing":"GPU fixed60 accelerated game time; normal spawn through first station"}
		camera_runs.append(result)
		check("seed%d_natural_first_station_camera_clear"%seed_value,safe,result)
		check("seed%d_unchanged_healthy_station_choice"%seed_value,app.phase=="running" and app.player.health==3 and app.player.hurt_count==0 and route_events.filter(func(row):return row.kind=="station").size()==1 and app.routes.heal_choices==1)
		if seed_value==404:
			await tap(KEY_R)
			await frames(3)
			var feet: Vector2=app.player.get_global_transform_with_canvas()*Vector2(0,15)
			check("actual_R_same_seed_new_camera_safe_and_old_ids_clear",app.phase=="running" and app.run_seed==404 and app.elapsed<1 and feet.y<450 and app.routes.heal_choices==0 and not app.camera.position_smoothing_enabled,{"feet":str(feet),"elapsed":app.elapsed,"camera":str(app.camera.position)})
			await shot("camera-retry-960")
		root.remove_child(app)
		app.free()
		app=null
		await frames(8)
		OS.delay_msec(150)
		var partial:=FileAccess.open(OUT_F+"g-camera-progress.json",FileAccess.WRITE)
		partial.store_string(JSON.stringify(camera_runs,"\t"))
		partial.close()
	var after:=source_hashes()
	check("109_new_camera_candidate_and_records_unchanged",before.files==after.files and after.mismatches.is_empty() and records_before==formal_records())
	var file:=FileAccess.open(OUT_F+"g-camera-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":checks.all(func(row):return row.passed),"checks":checks,"runs":camera_runs,"before":before,"after":after,"records_before":records_before,"records_after":formal_records(),"method":"G camera-only rerun: three upper routes from public start_endless normal spawn, actual Player/SPACE, no position/speed/life/front/clock injection. Same independent controller. GPU fixed60 accelerated, per-run game/wall. Capture actual Course/player canvas transform after frame draw for first station selection/landing, against real life/route HUD Rects. Actual Esc/R. Initial six business routes and old tool evidence retained, not all rerun."},"\t"))
	file.close()
	quit(0 if checks.all(func(row):return row.passed) else 1)
