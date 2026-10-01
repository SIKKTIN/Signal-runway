extends "res://reports/v0.8/independent-checks/check_routes.gd"
const OUT_G := "res://reports/v0.8/independent-checks/g/"
const Spatial := preload("res://scripts/level/spatial_library.gd")
const Skill := preload("res://scripts/level/skill_library.gd")
const Profile := preload("res://scripts/level/generation_profile.gd")
var boundary_runs: Array[Dictionary] = []
var start_on_high := false
var late_280 := false

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT_G+label+".png")

func fixture(speed: int) -> void:
	released()
	key(KEY_SHIFT,false)
	used_windows.clear()
	input_log.clear()
	route_choice = "skill"
	app = load("res://scenes/main/main.tscn").instantiate()
	app.generation_profile = Profile.defaults()
	app.dash_prototype_kind = "relay"
	app.trial_speed = float(speed)
	app.record_path = OUT_G+"isolated-boundary-%d.json"%speed
	root.add_child(app)
	app.start_endless(77)
	var course: Node2D = app.course
	for holder in course._holders.values():
		course.remove_child(holder)
		holder.queue_free()
	course._holders.clear()
	course.chunks.clear()
	course._generated_end = 0.0
	for i in 4:
		var d: Dictionary = Spatial.empty("slope",384,384,32,80)
		Spatial.surface(d,Vector2(0,384),Vector2(1280,384))
		if i==1:
			d = Skill.build("relay",384,64)
			d.connection.upper_to = true
			d.connection.upper_exit_y = 256.0
			d.connection.chain_id = "G-high-fixture"
		elif i==2:
			Spatial.extend_upper(d,256,true,false,"G-high-fixture")
		course._append_chunk({"geometry":d,"index":i,"template_id":"safe_a","stage":0})
	course._sync_geometry()
	course.chunks_changed.emit()
	# Explicit initial geometry, fixed speed, spawn and chase fixture. No mid-run injections.
	app.player.reset_at(Vector2(96,366))
	app._previous_position = app.player.position
	app.chase.reset(96)
	app.chase.set_enabled(true)
	app.dash_prototype_kind = ""
	if start_on_high:
		# Separate disclosed initial high-platform fixture, not a successful relay run.
		app.player.reset_at(Vector2(2656,238))
		app._previous_position = app.player.position
		app.chase.reset(2656)
		app.chase.set_enabled(true)
		app.camera.position = Vector2(3136,270)
	var minimum_top := INF
	var maximum_landed_white := -INF
	var card_overlap := 0
	var life_overlap := 0
	var landings: Array[Dictionary] = []
	var high224_landed := false
	var corridor256_landed := false
	var reached := false
	var captured := false
	var last_floor := ""
	var wall_start := Time.get_ticks_msec()
	for _i in 1800:
		var delay_space := false
		if late_280 and app.player.is_on_floor():
			for chunk in course.chunks:
				var x: float = app.player.position.x-chunk.origin
				for window in chunk.geometry.jump_windows:
					if window.kind=="skill" and absf(app.player.position.y+15-window.from.y)<7 and x>=window.from.x-4 and x<window.from.x+4:
						delay_space = true
		if delay_space:
			# Only delay the actual SPACE key; no body/state/geometry changes.
			key(KEY_SHIFT,false)
		else:
			step_input()
		await frames(1)
		var at: Vector2 = app.player.get_global_transform_with_canvas()*Vector2.ZERO
		var body := Rect2(at-Vector2(10,15),Vector2(20,30))
		minimum_top = minf(minimum_top,body.position.y)
		# Check reserved skill-card region even after the actual prior offer has ended.
		if body.intersects(Rect2(270,128,390,58)):
			card_overlap += 1
		if body.intersects(app._survival_status.get_global_rect()) or body.intersects(app._route_status.get_global_rect()):
			life_overlap += 1
		if app.player.is_on_floor():
			for chunk in course.chunks:
				var x: float = app.player.position.x-chunk.origin
				for rect in chunk.geometry.platforms+chunk.geometry.floors:
					if x>=rect.position.x and x<=rect.end.x and absf(app.player.position.y+15-rect.position.y)<4:
						var top: Vector2 = course.get_global_transform_with_canvas()*Vector2(app.player.position.x,rect.position.y)
						var white := Rect2(top-Vector2(10,0),Vector2(20,4))
						maximum_landed_white = maxf(maximum_landed_white,white.end.y)
						if white.intersects(app._survival_status.get_global_rect()) or white.intersects(app._route_status.get_global_rect()):
							life_overlap += 1
						var floor_id: String = chunk.id+":"+str(rect.position.y)+":"+str(rect.position.x)
						if floor_id!=last_floor:
							landings.append({"id":floor_id,"world_y":rect.position.y,"canvas_white_bottom":white.end.y,"body_top":body.position.y,"camera":str(app.camera.position),"health":app.player.health})
							last_floor = floor_id
						if chunk.index==2 and rect.position.y==224:
							high224_landed = true
						if chunk.index==2 and rect.position.y==256:
							corridor256_landed = true
		if not captured and app.player.position.x>2940 and app.player.position.x<3050 and not app.player.is_on_floor():
			await shot("boundary-%d-high-jump"%speed)
			captured = true
		if app.player.position.x>3940:
			reached = true
			await shot("boundary-%d-return-ground"%speed)
			break
		if app.phase!="running":
			break
	var row := {"speed":speed,"initial_high_fixture":start_on_high,"late_space_to_edge_plus4":late_280,"reached":reached,"health":app.player.health,"hurt_count":app.player.hurt_count,"completed":app.routes.completed,"dash":app.player.dash_snapshot(),"phase":app.phase,"minimum_body_top":minimum_top,"maximum_landed_white_bottom":maximum_landed_white,"card_overlap_frames":card_overlap,"lower_hud_overlap_frames":life_overlap,"high224_landed":high224_landed,"corridor256_landed":corridor256_landed,"landings":landings,"input_log":input_log.duplicate(true),"game_seconds":app.elapsed,"wall_seconds":float(Time.get_ticks_msec()-wall_start)/1000.0}
	boundary_runs.append(row)
	check("boundary_%d_real_chain"%speed,reached and app.player.health==3 and app.player.hurt_count==0 and (start_on_high or (app.routes.completed==1 and app.player.dash_used==2)) and high224_landed and corridor256_landed,row)
	check("boundary_%d_body_and_white_clear"%speed,card_overlap==0 and life_overlap==0 and maximum_landed_white<450,{"minimum_top":minimum_top,"maximum_landed_white":maximum_landed_white,"card_overlap":card_overlap,"lower_hud_overlap":life_overlap})
	released()
	key(KEY_SHIFT,false)
	root.remove_child(app)
	app.free()
	await frames(8)
	OS.delay_msec(150)

func run() -> void:
	print("V08_G_BOUNDARY_PID=",OS.get_process_id())
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(960,540)
	root.size = Vector2i(960,540)
	var before := source_hashes()
	start_on_high = "--high280" in OS.get_cmdline_user_args()
	late_280 = "--late280" in OS.get_cmdline_user_args()
	check("118_new_candidate_before",before.mismatches.is_empty())
	for speed in ([280] if start_on_high or late_280 or "--only280" in OS.get_cmdline_user_args() else [280,330,380]):
		await fixture(speed)
	var after := source_hashes()
	check("118_new_candidate_unchanged",before.files==after.files and after.mismatches.is_empty())
	var passed: bool = checks.all(func(row: Dictionary) -> bool:return row.passed)
	var file := FileAccess.open(OUT_G+("boundary-280-high-results.json" if start_on_high else ("boundary-280-late-results.json" if late_280 else "boundary-results.json")),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"runs":boundary_runs,"method":"Focused gen6 real Main/Player/Course fixture: initial ground384, maxheight64 relay platforms320/288/256, true Spatial.extend_upper corridor256/224/256 and merge384. Initial spawn/chase/fixed280/330/380 are explicit fixtures. --high280 separately starts initially at x2656,y238 on true y256 corridor with initial camera3136/270, proves actual jump/landing224/256 and ground return only, not relay completion. No traversal teleport/resource/speed/front/time changes. Actual synthetic jump/dash windows, landed feet/white4px and reserved card/lower HUD rectangles sampled. GPU fixed60 accelerated. Not natural default seeds or a broad matrix rerun."},"\t"))
	file.close()
	quit(0 if passed else 1)
