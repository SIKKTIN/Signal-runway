extends SceneTree
## E only: real Main geometry, labelled camera/start fixtures, one 380 traversal.
const OUT := "res://reports/v0.7/art/"
var app: Node2D
var checks: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var held := false
var held_frames := 0

func _initialize() -> void:
	call_deferred("run")
func frames(n: int) -> void:
	for _i in n:
		await physics_frame
		await process_frame
func check(label: String,value: bool,actual: Variant="") -> void:
	checks.append({"check":label,"passed":value,"actual":actual})
	print(label,": ",value)
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
func key(code: Key,down: bool) -> void:
	var event:=InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=down
	Input.parse_input_event(event)
func ground_y(d: Dictionary,x: float) -> float:
	return preload("res://scripts/visual/spatial_visual.gd").ground_y(d,x)
func freeze() -> void:
	app.set_physics_process(false)
	app.player.set_physics_process(false)
func camera(at: Vector2) -> void:
	app.camera.position_smoothing_enabled=false
	app.camera.position=at
	app.camera.reset_smoothing()
	app.camera.force_update_scroll()
func visuals() -> Array:
	return [app.world.get_node("SpatialVisual"),app.world.get_node("EndlessWorldVisual"),app.world.get_node("RouteVisual")]
func run() -> void:
	print("V07_E_PID ",OS.get_process_id())
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size=Vector2i(960,540)
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main/main.tscn").instantiate()
	app.record_path=OUT+"isolated-art-record.json"
	root.add_child(app)
	await frames(4)
	app.start_endless(404)
	freeze()
	await frames(3)
	check("actual_Main_installs_v5_identity_spatial_visual",app.generation_profile.generator_revision==5 and app.world.has_node("SpatialVisual") and visuals()[0].transform==Transform2D.IDENTITY)
	var found: Dictionary={}
	var bridge_index: int=-1
	var upper_index: int=-1
	for index in range(2,40):
		app.course.update_stream(index*1280+640,index*1280-700)
		await frames(2)
		var chunk: Dictionary=app.course.chunks.filter(func(row):return row.index==index)[0]
		var d: Dictionary=chunk.geometry
		var case_name: String=str(d.spatial_id)
		if d.has("challenge"):
			case_name="challenge"
		elif d.has("station"):
			case_name="station"
		elif d.connection.upper_from:
			case_name="upper-continue" if d.connection.upper_to else "upper-merge"
		if found.has(case_name):
			continue
		found[case_name]=index
		if case_name=="bridge":
			bridge_index=index
		if case_name=="challenge":
			upper_index=index
		var original: String=JSON.stringify(d)
		var y: float=ground_y(d,96)
		app.player.reset_at(Vector2(chunk.origin+96,y-16))
		app.phase="running"
		app.target_run_speed=380
		app.trial_speed=380
		app._update_ui()
		var camera_y: float=clampf(y-16-163,270,420)
		camera(Vector2(chunk.origin+640,camera_y))
		for size in [Vector2i(1280,720),Vector2i(960,540)]:
			root.size=size
			await frames(3)
			await shot(case_name+"-"+str(size.x))
			shots.append({"case":case_name,"index":index,"size":str(size),"entry":d.connection.entry_y,"exit":d.connection.exit_y,"camera_y":camera_y,"connection":d.connection,"geometry":d,"spatial":visuals()[0].presentation_state()})
		check(case_name+"_actual_geometry_is_read_only",JSON.stringify(chunk.geometry)==original)
		if case_name=="basin":
			await shot("pause-a")
			key(KEY_ESCAPE,true)
			await frames(2)
			key(KEY_ESCAPE,false)
			await frames(2)
			var paused_state: Array=visuals().map(func(v):return v.presentation_state())
			await shot("paused-a")
			await frames(20)
			await shot("paused-b")
			check("actual_Esc_freezes_all_spatial_and_route_clocks",app.phase=="paused" and paused_state==visuals().map(func(v):return v.presentation_state()))
			key(KEY_ESCAPE,true)
			await frames(2)
			key(KEY_ESCAPE,false)
			await frames(2)
		if found.has_all(["slope","terrace","bridge","basin","challenge","upper-merge","station"]):
			break
	check("actual_seed_covers_four_shapes_and_upper_merge",found.has_all(["slope","terrace","bridge","basin","challenge","upper-merge"]),found)
	check("spatial_live_ids_match_recycled_course",visuals()[0].presentation_state().ids==app.course.chunks.map(func(row):return row.id),visuals()[0].presentation_state())
	var signal_count: int=app.course.get_signal_connection_list("chunks_changed").size()
	for _i in 3:
		visuals()[0].bind_flow(app,app.course)
	check("rebind_does_not_duplicate_spatial_listeners",signal_count==app.course.get_signal_connection_list("chunks_changed").size())
	# Fresh Main retry clears old world and snapshots. No gameplay traversal claim yet.
	var previous_visual: Node=visuals()[0]
	app.start_endless(404)
	freeze()
	await frames(4)
	check("new_run_replaces_world_and_clears_old_ids",not is_instance_valid(previous_visual) and visuals()[0].presentation_state().chunks==app.course.chunks.size() and visuals()[0].presentation_state().animation_time<.5)
	await traversal(bridge_index,false,"bridge")
	await traversal(upper_index,true,"upper-chain")
	var sources: Dictionary={}
	for path in ["scripts/visual/spatial_visual.gd","scripts/visual/endless_module_visual.gd","scripts/visual/route_visual.gd","scripts/level/run_flow.gd","scripts/level/endless_course.gd","scripts/level/spatial_library.gd","scripts/level/spatial_generator.gd"]:
		sources[path]=FileAccess.get_sha256("res://"+path)
	root.remove_child(app)
	app.free()
	await frames(8)
	OS.delay_msec(150)
	var passed: bool=checks.all(func(row):return row.passed)
	var file:=FileAccess.open(OUT+"main-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"shots":shots,"sources":sources,"renderer":RenderingServer.get_video_adapter_name(),"method":"E actual Main default5; frozen snapshots use explicit stream position/player/camera/380 UI fixtures, no F natural-route claim. Then fresh actual Main bridge and challenge+next-chain traversals at explicit selected seed chunk and speed380. During traversal real Player/SPACE physics, no position/health/front/clock injection. GPU fixed60 accelerates game time. Actual Esc and retry cleanup. No human experience claim."},"\t"))
	file.close()
	quit(0 if passed else 1)

func step(upper: bool) -> void:
	held_frames+=1
	if held and held_frames>4 and app.player.velocity.y>=0:
		key(KEY_SPACE,false)
		held=false
	if held or not app.player.is_on_floor():
		return
	for chunk in app.course.chunks:
		var x: float=app.player.position.x-chunk.origin
		if x<0 or x>1280:
			continue
		for window in chunk.geometry.jump_windows:
			if window.kind!="primary" and not upper:
				continue
			var a: Vector2=window.from
			var b: Vector2=window.to
			var lead: float=24 if b.x>a.x+8 else 60
			if x>=a.x-lead and x<a.x+8 and absf(app.player.position.y+15-a.y)<7:
				key(KEY_SPACE,true)
				held=true
				held_frames=0
				return

func traversal(index: int,upper: bool,label: String) -> void:
	app.start_endless(404)
	freeze()
	app.course.update_stream(index*1280+640,index*1280-900)
	await frames(3)
	var chunk: Dictionary=app.course.chunks.filter(func(row):return row.index==index)[0]
	var entry: float=ground_y(chunk.geometry,96)
	app.player.reset_at(Vector2(chunk.origin+96,entry-16))
	app._previous_position=app.player.position
	app.run_distance=index*1280
	app.chase.reset(app.player.position.x)
	app.chase.set_enabled(true)
	app.trial_speed=380
	app.camera.position_smoothing_enabled=true
	camera(Vector2(chunk.origin+360,clampf(entry-16-163,270,420)))
	app.set_physics_process(true)
	app.player.set_physics_process(true)
	var start: float=index*1280+96
	var goal: float=(index+(2 if upper else 1))*1280-80
	var samples: Array[Dictionary]=[]
	var midpoint_shot:=false
	var seam_shot:=false
	for frame in 1100:
		if app.phase!="running":
			break
		step(upper)
		await frames(1)
		var global_x: float=app.player.position.x+app.course.total_offset
		if frame%30==0:
			samples.append({"x":global_x,"y":app.player.position.y,"speed":app.player.velocity.x,"camera_y":app.camera.position.y,"health":app.player.health})
		if not midpoint_shot and global_x>start+440:
			root.size=Vector2i(1280,720)
			await frames(2)
			await shot("moving-380-"+label+"-1280")
			midpoint_shot=true
		if upper and not seam_shot and global_x>(index+1)*1280+100:
			root.size=Vector2i(960,540)
			await frames(2)
			await shot("moving-380-upper-seam-960")
			seam_shot=true
		if global_x>goal:
			break
	key(KEY_SPACE,false)
	held=false
	freeze()
	check("actual_380_"+label+"_reaches_target_with_clear_health",app.phase=="running" and app.player.position.x+app.course.total_offset>goal and app.player.health==3,{"start":start,"goal":goal,"elapsed":app.elapsed,"position":str(app.player.position),"offset":app.course.total_offset,"health":app.player.health,"completed":app.routes.completed,"samples":samples})
