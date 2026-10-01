extends "res://reports/v0.7/independent-checks/check_routes.gd"
## Independent actual default runs. No motion/resource/clock injection.
const OUT8 := "res://reports/v0.8/independent-checks/g/"
var dash_events: Array[Dictionary] = []
var used_windows: Dictionary = {}
var charge_seen: Dictionary = {}
var input_log: Array[Dictionary] = []
var skill_dash_captured := false
var resource_sync := true

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT8+label+".png")

func source_hashes() -> Dictionary:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://reports/v0.8/version-manifest.json"))
	var hashes: Dictionary = {}
	var mismatch: Array[String] = []
	for row in manifest.files:
		var current: String = FileAccess.get_sha256("res://"+row.path)
		hashes[row.path] = current
		if current != row.sha256:
			mismatch.append(row.path)
	return {"version":manifest.version,"manifest_sha256":manifest.sha256,"files":hashes,"mismatches":mismatch}

func formal_records() -> Dictionary:
	return {"v08":file_hash(Record.DEFAULT_PATH),"v07":file_hash(Record.V07_PATH),"v06":file_hash(Record.V06_PATH),"v05":file_hash(Record.V05_PATH),"earlier":file_hash(Record.LEGACY_PATH),"failure":file_hash("user://map_editor_failure_v08.json"),"failure_v07":file_hash("user://map_editor_failure_v07.json")}

func on_dash(snapshot: Dictionary) -> void:
	dash_events.append({"snapshot":snapshot.duplicate(true),"elapsed":app.elapsed,"global_x":app.player.position.x+app.course.total_offset,"health":app.player.health})

func step_input() -> void:
	key(KEY_SHIFT,false)
	held_frames += 1
	var short_rescue := false
	for chunk in app.course.chunks:
		if chunk.geometry.get("skill",{}).get("kind","")=="rescue" and route_choice=="skill" and app.player.position.x>=chunk.origin+450 and app.player.position.x<chunk.origin+608:
			short_rescue = true
	if held and held_frames>4 and (app.player.velocity.y>=0 or short_rescue):
		released()
	for chunk in app.course.chunks:
		var x: float = app.player.position.x-chunk.origin
		if x<0 or x>chunk.length:
			continue
		var d: Dictionary = chunk.geometry
		var skill: Dictionary = d.get("skill",{})
		var enter_skill: bool = route_choice=="skill" and (skill.is_empty() or app.routes.active==chunk.id or app.player.dash_charges>=int(skill.get("required",0)))
		if not held and app.player.is_on_floor() and app.fall_recovery_remaining<=0:
			for window in d.jump_windows:
				if window.kind!="primary" and not enter_skill:
					continue
				var a: Vector2 = window.from
				var b: Vector2 = window.to
				var lead: float = 4 if window.kind=="skill" else (24 if b.x>a.x+8 else 60)
				if x>=a.x-lead and x<a.x+8 and absf(app.player.position.y+15-a.y)<7:
					key(KEY_SPACE,true)
					held = true
					held_frames = 0
					presses += 1
					input_log.append({"key":"SPACE","chunk":chunk.id,"kind":window.kind,"x":x,"feet":app.player.position.y+15,"elapsed":app.elapsed})
					break
		if enter_skill and not skill.is_empty() and not app.player.is_on_floor() and app.player.dash_charges>0 and not app.player.dash_active:
			for j in skill.dash_windows.size():
				var window: Dictionary = skill.dash_windows[j]
				var id: String = chunk.id+":"+str(j)
				if not used_windows.has(id) and x>=float(window.dash_x) and x<float(window.to.x):
					key(KEY_SHIFT,true)
					used_windows[id] = true
					input_log.append({"key":"Shift","chunk":chunk.id,"kind":skill.kind,"x":x,"feet":app.player.position.y+15,"elapsed":app.elapsed,"charges_before":app.player.dash_charges})
					break

func run() -> void:
	print("V08_F_NATURAL_PID=",OS.get_process_id())
	var before := source_hashes()
	var records_before := formal_records()
	check("118_frozen_before",before.mismatches.is_empty())
	if not before.mismatches.is_empty():
		quit(2)
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(960,540)
	for seed_value in [77]:
		for choice in ["skill"]:
			root.size = Vector2i(1280,720) if choice=="stable" else Vector2i(960,540)
			released()
			key(KEY_SHIFT,false)
			presses = 0
			events.clear()
			route_events.clear()
			dash_events.clear()
			samples.clear()
			used_windows.clear()
			input_log.clear()
			skill_dash_captured = false
			resource_sync = true
			route_choice = choice
			app = load("res://scenes/main/main.tscn").instantiate()
			var record: String = OUT8+"isolated-natural-%d-%s.json"%[seed_value,choice]
			app.record_path = record
			root.add_child(app)
			await frames(3)
			app.relay_activated.connect(on_relay)
			app.route_event.connect(on_route)
			app.dash_state_changed.connect(on_dash)
			app.start_endless(seed_value)
			var wall_begin := Time.get_ticks_msec()
			var station_index := -1
			var station_id := ""
			var preview_time := -1.0
			var choice_time := -1.0
			var station_captured := false
			var dash_ui_overlaps := 0
			var route_ui_overlaps := 0
			var ui_mismatches: Array[Dictionary] = []
			for frame in 12000:
				if app.phase not in ["running","recovering"]:
					break
				step_input()
				await frames(1)
				var dash_ui: Dictionary = app._dash_status.presentation_state()
				var snapshot: Dictionary = app.player.dash_snapshot()
				var dash_matches := true
				for field in snapshot:
					if field=="remaining":
						dash_matches = dash_matches and absf(float(dash_ui.snapshot.get(field,-1))-float(snapshot[field]))<=1.1/60.0
					else:
						dash_matches = dash_matches and dash_ui.snapshot.get(field)==snapshot[field]
				var health_matches: bool = app._survival_status.presentation_state().health==app.player.health
				if not (dash_matches and health_matches) and ui_mismatches.size()<12:
					ui_mismatches.append({"elapsed":app.elapsed,"ui":dash_ui.snapshot.duplicate(true),"actual":snapshot,"ui_health":app._survival_status.presentation_state().health,"actual_health":app.player.health})
				resource_sync = resource_sync and dash_matches and health_matches
				var at: Vector2 = app.player.get_global_transform_with_canvas()*Vector2.ZERO
				var body := Rect2(at-Vector2(10,15),Vector2(20,30))
				if Rect2(app._dash_status.global_position,app._dash_status.size).intersects(body):
					dash_ui_overlaps += 1
				var route_ui: Dictionary = app.world.get_node("RouteVisual").presentation_state()
				if not route_ui.skill_offer.is_empty() and route_ui.skill_rect.intersects(body):
					route_ui_overlaps += 1
				for chunk in app.course.chunks:
					if station_index<0 and chunk.geometry.has("station"):
						station_index = int(chunk.index)
						station_id = chunk.id
				if not station_id.is_empty() and preview_time<0:
					var info: Dictionary = app.world.get_node("RouteVisual").station_presentation(station_id)
					if not info.is_empty() and Rect2(0,0,960,540).encloses(info.preview_rect):
						preview_time = app.elapsed
				for event in route_events:
					if event.kind=="station" and choice_time<0:
						choice_time = float(event.elapsed)
				if not skill_dash_captured and choice=="skill" and app.player.dash_active:
					await shot("natural-%d-skill-dash"%seed_value)
					skill_dash_captured = true
				if not station_captured and app.routes.stations.has(station_id):
					await shot("natural-%d-%s-station"%[seed_value,choice])
					station_captured = true
				if not did_pause and seed_value==77 and choice=="skill" and app.player.dash_active:
					await tap(KEY_ESCAPE)
					var freeze: Array = [app.elapsed,app.player.position,app.chase.front_x,app.player.dash_snapshot(),app._dash_status.presentation_state(),app.world.get_node("DashVisual").presentation_state(),app.world.get_node("RouteVisual").presentation_state()]
					await shot("natural-pause-before")
					await frames(20)
					await shot("natural-pause-after")
					check("actual_Esc_dash_and_hud_freeze",app.phase=="paused" and freeze==[app.elapsed,app.player.position,app.chase.front_x,app.player.dash_snapshot(),app._dash_status.presentation_state(),app.world.get_node("DashVisual").presentation_state(),app.world.get_node("RouteVisual").presentation_state()])
					await tap(KEY_ESCAPE)
					did_pause = true
				if frame%300==0:
					samples.append({"elapsed":app.elapsed,"distance":app.run_distance,"health":app.player.health,"target_speed":app.target_run_speed,"gap":app.player.position.x-10-app.chase.front_x,"dash":snapshot,"score":app.run_score,"chunks":app.course.chunks.size()})
				if station_index>=0 and app.player.position.x+app.course.total_offset>(station_index+1)*1280+100:
					break
			released()
			key(KEY_SHIFT,false)
			var state: Dictionary = app.routes.snapshot()
			var station: Array = route_events.filter(func(row: Dictionary) -> bool:return row.kind=="station")
			var breakdown: Dictionary = app.score_breakdown()
			var result := {"seed":seed_value,"strategy":choice,"phase":app.phase,"failure":app.failure_reason,"elapsed":app.elapsed,"wall_seconds":float(Time.get_ticks_msec()-wall_begin)/1000,"distance":app.run_distance,"health":app.player.health,"hurt_count":app.player.hurt_count,"dash":app.player.dash_snapshot(),"score":app.run_score,"breakdown":breakdown,"routes":state,"first_station_index":station_index,"station_events":station,"preview_seconds":choice_time-preview_time,"jump_presses":presses,"input_log":input_log.duplicate(true),"dash_events":dash_events.duplicate(true),"route_events":route_events.duplicate(true),"relay_events":events.duplicate(true),"samples":samples.duplicate(true),"dash_ui_overlap_frames":dash_ui_overlaps,"route_ui_overlap_frames":route_ui_overlaps,"resource_ui_sync":resource_sync,"ui_mismatches":ui_mismatches,"timing":"fixed60 GPU accelerated clock"}
			results.append(result)
			var label := "natural_%d_%s"%[seed_value,choice]
			check(label+"_after_first_station",app.phase=="running" and station_index>=0 and app.player.position.x+app.course.total_offset>(station_index+1)*1280+100 and station.size()==1,result)
			check(label+"_actual_strategy",(choice=="stable" and app.player.dash_used==0 and state.completed==0 and app.player.dash_charges>0) or (choice=="skill" and app.player.dash_used>0 and app.player.dash_refilled>0 and state.completed>0),app.player.dash_snapshot())
			check(label+"_health_station_mutex",app.player.health==3 and app.player.hurt_count==0 and state.heal_choices+state.score_choices==1)
			check(label+"_score_ui",resource_sync and app.run_score==int(breakdown.distance)+int(breakdown.nodes)+int(breakdown.combo)+int(breakdown.station))
			check(label+"_readable",dash_ui_overlaps==0 and route_ui_overlaps==0 and preview_time>=0 and choice_time-preview_time>=1.2,{"dash_overlap":dash_ui_overlaps,"route_overlap":route_ui_overlaps,"station_preview_seconds":choice_time-preview_time})
			print("F_NATURAL_FINISHED ",seed_value," ",choice," phase=",app.phase," game=",app.elapsed)
			var partial := FileAccess.open(OUT8+"natural-progress.json",FileAccess.WRITE)
			partial.store_string(JSON.stringify(results,"\t"))
			partial.close()
			if seed_value==77 and choice=="skill":
				await tap(KEY_R)
				check("actual_R_initial_resource_single_hud",app.player.dash_charges==1 and app.player.dash_progress==0 and app.player.dash_used==0 and app.ui.get_children().filter(func(c: Node) -> bool:return c.get_script()==preload("res://scenes/ui/v08_dash_status.gd")).size()==1)
			root.remove_child(app)
			app.free()
			app = null
			await frames(8)
			OS.delay_msec(150)
			for suffix in ["",".bak",".tmp"]:
				if FileAccess.file_exists(record+suffix):
					DirAccess.remove_absolute(record+suffix)
	var after := source_hashes()
	check("118_sources_and_formal_records_unchanged",before.files==after.files and after.mismatches.is_empty() and records_before==formal_records())
	var passed: bool = checks.all(func(row: Dictionary) -> bool:return row.passed)
	var file := FileAccess.open(OUT8+"natural-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"runs":results,"before":before,"after":after,"records_before":records_before,"records_after":formal_records(),"renderer":RenderingServer.get_video_adapter_name(),"method":"G focused frozen default Main, only seed77 skill actual Player run to first station after. Prior five passing natural routes inherit old638 F evidence. Synthetic SPACE/Shift/Esc/R from real geometry. Initial public start_endless only; isolated record destination. No position/resource/speed/health/front/time injection. Skill strategy uses optional routes if available and deliberate short rescue jump. GPU fixed60 accelerated, per-run wall/game seconds. Not human fun proof; no producer long-run duplication."},"\t"))
	file.close()
	quit(0 if passed else 1)
