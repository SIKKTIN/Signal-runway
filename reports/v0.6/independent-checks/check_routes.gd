extends "res://reports/v0.5/independent-checks/check_routes.gd"
## Reuse independent synthetic-key controller. Natural v4 routes, no injected state/time.
const OUT_F := "res://reports/v0.6/independent-checks/"
var route_events: Array[Dictionary]=[]
var samples: Array[Dictionary]=[]
var did_pause := false
var same_frame_sync := true

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT_F+label+".png")
func source_hashes() -> Dictionary:
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/v0.6/version-manifest.json"))
	var hashes:= {}
	var mismatch: Array[String]=[]
	for row in manifest.files:
		var current:=FileAccess.get_sha256("res://"+row.path)
		hashes[row.path]=current
		if current!=row.sha256:
			mismatch.append(row.path)
	return {"version":manifest.version,"manifest_sha256":manifest.sha256,"files":hashes,"mismatches":mismatch}
func file_hash(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
func formal_records() -> Dictionary:
	return {"v06":file_hash(Record.DEFAULT_PATH),"v05":file_hash(Record.V05_PATH),"earlier":file_hash(Record.LEGACY_PATH)}
func on_route(kind: String,data: Dictionary) -> void:
	route_events.append({"kind":kind,"data":data.duplicate(true),"elapsed":app.elapsed,"distance":app.run_distance,"health":app.player.health})

func step_input() -> void:
	# v4 may retain a relay identity while its final geometry is a calm connector.
	held_frames+=1
	if held and held_frames>4 and app.player.velocity.y>=0:
		released()
	if held or not app.player.is_on_floor() or app.fall_recovery_remaining>0:
		return
	var jump:=false
	for chunk in app.course.chunks:
		var x: float=app.player.position.x-chunk.origin
		if x<0 or x>chunk.length:
			continue
		var d: Dictionary=chunk.geometry
		var path: Array=d.floors.duplicate()
		if not d.gaps.is_empty() and not d.platforms.is_empty():
			path=[d.floors[0]]+d.platforms+[d.floors[1]]
		elif route_choice=="upper" and not d.platforms.is_empty():
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
		for spike in d.spikes:
			jump=jump or (x>=spike.position.x-70 and x<spike.end.x+10)
	if jump:
		key(KEY_SPACE,true)
		held=true
		held_frames=0
		presses+=1

func run() -> void:
	print("F_ROUTE_PID ",OS.get_process_id())
	var before:=source_hashes()
	var records_before:=formal_records()
	check("105_frozen_sources_match_before",before.mismatches.is_empty(),before.version)
	if not before.mismatches.is_empty():
		quit(2)
		return
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size=Vector2i(960,540)
	var accelerated: bool="--resume" in OS.get_cmdline_user_args()
	if accelerated:
		var prior: Array=JSON.parse_string(FileAccess.get_file_as_string(OUT_F+"normal-partial.json"))
		results.assign(prior)
		for row in results:
			row.timing="normal wall clock, prior complete run"
		var prior_log:=FileAccess.get_file_as_string(OUT_F+"normal-partial.log")
		did_pause=prior_log.contains("actual_Escape_preserves_active_challenge: true")
		check("preserved_normal_partial_and_pause",results.size()>0 and results[0].phase=="running" and did_pause)
	for seed_value in [404,77,9001]:
		for choice in ["primary","upper"]:
			if results.any(func(row):return row.seed==seed_value and row.strategy==choice):
				continue
			root.size=Vector2i(1280,720) if choice=="primary" else Vector2i(960,540)
			released()
			presses=0
			events.clear()
			route_events.clear()
			samples.clear()
			route_choice=choice
			same_frame_sync=true
			app=load("res://scenes/main/main.tscn").instantiate()
			var record: String=OUT_F+"isolated-natural-%d-%s.json" % [seed_value,choice]
			app.record_path=record
			root.add_child(app)
			await frames(3)
			app.relay_activated.connect(on_relay)
			app.route_event.connect(on_route)
			app.start_endless(seed_value)
			var wall_begin:=Time.get_ticks_msec()
			var first_station_index := -1
			var station_id := ""
			var preview_time := -1.0
			var choice_time := -1.0
			var captured_combo := false
			var captured_station := false
			var last_route_events := 0
			for frame in 12000:
				if app.phase not in ["running","recovering"]:
					break
				step_input()
				await frames(1)
				for chunk in app.course.chunks:
					if first_station_index<0 and chunk.geometry.has("station"):
						first_station_index=int(chunk.index)
						station_id=chunk.id
				if not station_id.is_empty() and preview_time<0:
					var info: Dictionary=app.world.get_node("RouteVisual").station_presentation(station_id)
					if not info.is_empty() and Rect2(0,0,960,540).encloses(info.preview_rect):
						preview_time=app.elapsed
						if seed_value==404:
							await shot("natural-404-"+choice+"-station-advance")
				if route_events.size()>last_route_events:
					same_frame_sync=same_frame_sync and app._survival_status.presentation_state().health==app.player.health and app.run_score==app.total_score()
					for i in range(last_route_events,route_events.size()):
						if route_events[i].kind=="station":
							choice_time=app.elapsed
					last_route_events=route_events.size()
				if seed_value==404 and choice=="upper" and not captured_combo and app.routes.completed>0:
					await shot("natural-404-completed-960")
					captured_combo=true
				if seed_value==404 and not captured_station and app.routes.stations.has(station_id):
					await shot("natural-404-"+choice+"-station-selected")
					captured_station=true
				if not did_pause and seed_value==404 and choice=="upper" and app.routes.progress==1:
					await tap(KEY_ESCAPE)
					var paused_state: Array=[app.elapsed,app.player.position,app.chase.front_x,app._route_status.presentation_state()]
					await shot("natural-pause-a")
					await frames(20)
					await shot("natural-pause-b")
					check("actual_Escape_preserves_active_challenge",app.phase=="paused" and paused_state==[app.elapsed,app.player.position,app.chase.front_x,app._route_status.presentation_state()])
					await tap(KEY_ESCAPE)
					did_pause=true
				if frame%300==0:
					samples.append({"elapsed":app.elapsed,"distance":app.run_distance,"score":app.run_score,"health":app.player.health,"target_speed":app.target_run_speed,"gap":app.player.position.x-10-app.chase.front_x,"chunks":app.course.chunks.size(),"routes":app.routes.snapshot()})
				if first_station_index>=0 and app.player.position.x+app.course.total_offset>(first_station_index+1)*1280+100:
					break
			released()
			var state: Dictionary=app.routes.snapshot()
			var breakdown: Dictionary=app.score_breakdown()
			var station: Array=route_events.filter(func(row):return row.kind=="station")
			var result: Dictionary={"seed":seed_value,"strategy":choice,"phase":app.phase,"failure":app.failure_reason,"elapsed":app.elapsed,"wall_seconds":float(Time.get_ticks_msec()-wall_begin)/1000,"distance":app.run_distance,"health":app.player.health,"hurt_count":app.player.hurt_count,"score":app.run_score,"breakdown":breakdown,"routes":state,"first_station_index":first_station_index,"station_event":station,"preview_window_seconds":choice_time-preview_time,"key_presses":presses,"events":route_events.duplicate(true),"relay_events":events.duplicate(true),"samples":samples.duplicate(true),"generator_revision":app.generation_profile.generator_revision,"profile_fingerprint":preload("res://scripts/level/generation_profile.gd").fingerprint(app.generation_profile)}
			results.append(result)
			result.timing="fixed60 GPU accelerated game time" if accelerated else "normal wall clock"
			check("natural_%d_%s_reaches_after_first_station" % [seed_value,choice],app.phase=="running" and first_station_index>=0 and app.player.position.x+app.course.total_offset>(first_station_index+1)*1280+100 and station.size()==1,result)
			check("natural_%d_%s_strategy_and_full_health_choice" % [seed_value,choice],app.player.health==3 and app.player.hurt_count==0 and ((choice=="upper" and state.completed>0 and state.heal_choices==1 and station[0].data.amount==0) or (choice=="primary" and state.completed==0 and state.score_choices==1 and station[0].data.amount>0)))
			check("natural_%d_%s_score_and_same_frame_UI" % [seed_value,choice],same_frame_sync and app.run_score==int(breakdown.distance)+int(breakdown.nodes)+int(breakdown.combo)+int(breakdown.station))
			check("natural_%d_%s_station_readable_window" % [seed_value,choice],preview_time>=0 and choice_time-preview_time>=1.2,choice_time-preview_time)
			print("F_NATURAL_FINISHED ",seed_value," ",choice," seconds=",app.elapsed)
			var partial:=FileAccess.open(OUT_F+"natural-progress.json",FileAccess.WRITE)
			partial.store_string(JSON.stringify(results,"\t"))
			partial.close()
			root.remove_child(app)
			app.free()
			app=null
			await frames(8)
			OS.delay_msec(150)
			for suffix in ["",".bak",".tmp"]:
				if FileAccess.file_exists(record+suffix):
					DirAccess.remove_absolute(record+suffix)
	for seed_value in [404,77,9001]:
		var pair: Array=results.filter(func(row):return row.seed==seed_value)
		check("same_seed_%d_upper_reward_gain" % seed_value,pair[1].breakdown.nodes+pair[1].breakdown.combo>pair[0].breakdown.nodes+pair[0].breakdown.combo,{"primary":pair[0].breakdown,"upper":pair[1].breakdown})
	var after:=source_hashes()
	check("105_sources_and_formal_v06_v05_records_unchanged",before.files==after.files and after.mismatches.is_empty() and records_before==formal_records())
	var passed: bool=checks.all(func(row):return row.passed)
	var file:=FileAccess.open(OUT_F+"natural-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"runs":results,"before":before,"after":after,"records_before":records_before,"records_after":formal_records(),"renderer":RenderingServer.get_video_adapter_name(),"method":"Actual default v4 Main; same-seed API only. BOTH seed404 primary and upper completed with normal wall clock before the own process was stopped for the producer-authorized acceleration. Four remaining cases, seed77/9001 x primary/upper, used fixed60 GPU accelerated game time. Normal original partial JSON and log are preserved, including 8 route checks and actual Esc pause. Final 22-check resumed JSON is not an additional rerun of those 8 checks. Real Player physics with synthetic SPACE/Esc; no position/speed/health/front or elapsed-state injection. Controller uses final geometry; v4 calm connectors may retain relay template IDs. Each strategy reaches beyond first station. Tool/debug fixtures separate. Not human experience."},"\t"))
	file.close()
	quit(0 if passed else 1)
