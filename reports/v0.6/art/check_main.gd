extends SceneTree
## E presentation: labelled snapshots/events, plus actual380 station approaches.
const OUT := "res://reports/v0.6/art/"
var app: Node2D
var checks: Array[Dictionary] = []
var approaches: Array[Dictionary] = []
var station_events: Array[Dictionary] = []
var held := false
var hold_frames := 0

func _initialize() -> void:
	call_deferred("run")
func frames(n: int) -> void:
	for _i in n:
		await physics_frame
		await process_frame
func check(label: String, passed: bool, actual: Variant = "") -> void:
	checks.append({"check":label,"passed":passed,"actual":actual})
	print(label,": ",passed)
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
func hud() -> Control:
	return app._route_status
func world() -> Node2D:
	return app.world.get_node("RouteVisual")
func camera_at(at: Vector2) -> void:
	app.camera.position_smoothing_enabled=false
	app.camera.position=at
	app.camera.reset_smoothing()
	app.camera.force_update_scroll()
func snapshot(active: String, progress: int) -> void:
	app.routes.active=active
	app.routes.progress=progress
	app.route_state_changed.emit(app.routes.snapshot())
func event(kind: String, data: Dictionary) -> void:
	app.route_event.emit(kind,data)
func key(down: bool) -> void:
	var value:=InputEventKey.new()
	value.keycode=KEY_SPACE
	value.physical_keycode=KEY_SPACE
	value.pressed=down
	Input.parse_input_event(value)
func on_event(kind: String, data: Dictionary) -> void:
	if kind=="station":
		station_events.append(data.duplicate(true))
func step_input(choice: String) -> void:
	hold_frames+=1
	if held and hold_frames>4 and app.player.velocity.y>=0:
		key(false)
		held=false
	if held or not app.player.is_on_floor():
		return
	var jump:=false
	for chunk in app.course.chunks:
		var x: float=app.player.position.x-chunk.origin
		if x<0 or x>chunk.length:
			continue
		var d: Dictionary=chunk.geometry
		var path: Array=d.floors.duplicate()
		if choice=="heal" and d.has("station"):
			path=[Rect2(0,448,288,160)]+d.platforms+[Rect2(976,448,304,160)]
		for i in path.size()-1:
			var rect: Rect2=path[i]
			if absf(app.player.position.y+15-rect.position.y)>4 or x<rect.position.x-10 or x>rect.end.x+10:
				continue
			var next: Rect2=path[i+1]
			var rise: bool=next.position.y<rect.position.y
			var gap: float=next.position.x-rect.end.x
			var needed: bool=rise or (gap>1 and next.position.y<=rect.position.y) or gap>48
			var lead: float=60 if gap<=1 and rise else 28
			jump=needed and x>=rect.end.x-lead
			break
	if jump:
		key(true)
		held=true
		hold_frames=0

func run() -> void:
	print("E_ART_PID ",OS.get_process_id())
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size=Vector2i(960,540)
	root.size=Vector2i(1280,720)
	app=load("res://scenes/main/main.tscn").instantiate()
	app.record_path=OUT+"isolated-record.json"
	root.add_child(app)
	await frames(4)
	app.start_endless(404)
	app.set_physics_process(false)
	app.player.set_physics_process(false)
	app.course.update_stream(33000,-544)
	await frames(3)
	check("actual_Main_installs_revision4_presentation",app.generation_profile.generator_revision==4 and is_instance_valid(hud()) and world().transform==Transform2D.IDENTITY and hud().get_global_rect()==Rect2(420,450,280,60))
	check("initial_bind_silent_and_hidden",not hud().visible and hud().presentation_state().sound_triggers==0)
	var challenge: Dictionary=app.course.chunks.filter(func(row):return row.geometry.has("challenge"))[0]
	var station: Dictionary=app.course.chunks.filter(func(row):return row.geometry.has("station"))[0]
	camera_at(Vector2(challenge.origin+620,270))
	app.player.position=Vector2(challenge.origin+180,432)
	snapshot(challenge.id,0)
	event("started",{"id":challenge.id})
	await frames(3)
	await shot("challenge-entry-1280")
	check("actual_three_ordered_markers_and_entry_exit",challenge.geometry.challenge.order.size()==3 and world().presentation_state().features>0)
	snapshot(challenge.id,3)
	event("progress",{"id":challenge.id,"progress":3,"total":3})
	await frames(3)
	await shot("challenge-wait-exit-1280")
	check("three_nodes_wait_for_real_exit_event",hud().presentation_state().message.contains("前往出口") and hud().presentation_state().sound_triggers==0)
	snapshot("",0)
	event("completed",{"id":challenge.id,"bonus":challenge.geometry.challenge.bonus})
	await frames(2)
	check("completion_uses_actual_bonus_one_cue",hud().presentation_state().message.contains(str(challenge.geometry.challenge.bonus)) and hud().presentation_state().sound_triggers==1 and hud().presentation_state().audio_playing)
	for _i in 5:
		event("completed",{"id":challenge.id,"bonus":challenge.geometry.challenge.bonus})
	check("repeated_completion_deduplicated",hud().presentation_state().sound_triggers==1)
	await shot("challenge-complete-1280")
	app.toggle_pause()
	await frames(3)
	var paused_hud: Dictionary=hud().presentation_state()
	var paused_world: Dictionary=world().presentation_state()
	await shot("paused-a")
	await frames(20)
	await shot("paused-b")
	check("pause_preserves_world_clock_and_feedback",paused_hud==hud().presentation_state() and paused_world==world().presentation_state() and hud().get_node("RouteEventCue").stream_paused)
	app.toggle_pause()
	await frames(3)
	check("resume_continues_without_new_cue",hud().presentation_state().remaining<paused_hud.remaining and hud().presentation_state().sound_triggers==1)
	var connections: int=app.get_signal_connection_list("route_event").size()
	for _i in 4:
		hud().bind_flow(app)
		world().bind_flow(app,app.course)
	check("rebind_no_listener_duplicates_or_historical_cue",app.get_signal_connection_list("route_event").size()==connections and hud().presentation_state().sound_triggers==0)
	snapshot(challenge.id,1)
	event("started",{"id":challenge.id})
	snapshot("",0)
	event("interrupted",{"id":challenge.id,"reason":"lower"})
	await frames(2)
	await shot("challenge-interrupted-1280")
	check("interruption_preserves_node_score_message",hud().presentation_state().message.contains("节点分保留") and hud().presentation_state().sound_triggers==0)
	var life: Control=app._survival_status
	life.update_state(2,300,300,true,1)
	await frames(3)
	var before_heal: Dictionary=life.presentation_state()
	life.update_state(3,300,300,true,1)
	check("healing_full_does_not_reset_existing_hurt_clock",life.presentation_state().animation_time==before_heal.animation_time and life.presentation_state().hurt_pulses==before_heal.hurt_pulses and life.presentation_state().hurt_remaining==before_heal.hurt_remaining)
	camera_at(Vector2(station.origin+320,270))
	app.player.position=Vector2(station.origin+180,432)
	app.player.health=3
	await frames(3)
	await shot("station-full-1280")
	app.player.health=2
	root.size=Vector2i(960,540)
	await frames(3)
	await shot("station-need-heal-960")
	check("two_choice_preview_bounds_and_full_state",Rect2(0,0,960,540).encloses(world().station_presentation(station.id).preview_rect) and not world().station_presentation(station.id).full)
	app.routes.stations[station.id]="heal"
	event("station",{"id":station.id,"kind":"heal","amount":0})
	await frames(2)
	check("full_life_choice_is_silent_and_explicit",hud().presentation_state().message.contains("生命已满") and hud().presentation_state().sound_triggers==0 and world().station_presentation(station.id).selected=="heal")
	await shot("station-selected-full-960")
	# New real Main rounds for station approaches, with explicit position/health/speed fixtures.
	for choice in ["score","heal"]:
		key(false)
		held=false
		station_events.clear()
		app.start_endless(404)
		if not app.route_event.is_connected(on_event):
			app.route_event.connect(on_event)
		app.course.update_stream(station.origin+1800,-544)
		app.player.position=Vector2(station.origin-1100,432)
		app.player.health=2 if choice=="heal" else 3
		app.player.hurt_count=1 if choice=="heal" else 0
		app.player.velocity=Vector2(380,0)
		app._previous_position=app.player.position
		app.trial_speed=380
		app.chase.front_x=app.player.position.x-1200
		camera_at(app.player.position+Vector2(180,-162))
		app.player.set_physics_process(true)
		app.set_physics_process(true)
		var first_visible := -1.0
		var first_shot := false
		for _i in 500:
			step_input(choice)
			await frames(1)
			var presentation: Dictionary=world().station_presentation(station.id)
			if first_visible<0 and not presentation.is_empty() and Rect2(0,0,960,540).encloses(presentation.preview_rect):
				first_visible=app.elapsed
			if first_visible>=0 and not first_shot:
				await shot("station-380-advance-"+choice+"-960")
				first_shot=true
			if not station_events.is_empty() or app.phase=="failed":
				break
		var visible_seconds: float=app.elapsed-first_visible
		var actual: Dictionary=station_events[0] if not station_events.is_empty() else {}
		check("380_%s_actual_station_choice_and_advance_window" % choice,first_visible>=0 and visible_seconds>=1.2 and actual.get("kind","")==choice and app.phase=="running",{"window":visible_seconds,"event":actual,"health":app.player.health,"distance":app.run_distance})
		check("380_%s_actual_feedback_uses_amount" % choice,hud().presentation_state().message.contains(str(actual.get("amount",-1))) and hud().presentation_state().sound_triggers==1)
		approaches.append({"choice":choice,"window_seconds":visible_seconds,"event":actual,"health":app.player.health,"method":"Actual380 physics/SPACE approach from explicit position -1100 before seeded first station; health2 only for heal, chase gap1200, public trial_speed380; not natural opening/three-seed F."})
		await shot("station-380-selected-"+choice+"-960")
		app.set_physics_process(false)
		app.player.set_physics_process(false)
		key(false)
	app.return_to_menu()
	await frames(3)
	check("menu_hides_world_and_HUD_stops_cue",not hud().visible and not world().visible and not hud().get_node("RouteEventCue").playing)
	root.remove_child(app)
	app.free()
	await frames(8)
	await create_timer(.25).timeout
	var passed: bool=checks.all(func(row):return row.passed)
	var file:=FileAccess.open(OUT+"main-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"approaches":approaches,"renderer":RenderingServer.get_video_adapter_name(),"method":"E actual Main presentation. Challenge/interrupt/full-health event snapshots are explicit fixtures, not B/C gameplay-rule proof. Two actual station physics approaches with public380 trial speed and labelled start/health/gap fixtures; synthetic SPACE. No natural-opening/3seed F/human/audio-listening claim."},"\t"))
	file.close()
	quit(0 if passed else 1)
