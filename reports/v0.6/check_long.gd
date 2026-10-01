extends SceneTree
const Main=preload("res://scenes/main/main.tscn")
const Profile=preload("res://scripts/level/generation_profile.gd")
const Record=preload("res://scripts/level/endless_record.gd")
var checks: Array[Dictionary]=[]
var samples: Array[Dictionary]=[]
var held:=false
var held_frames:=0
func _initialize() -> void:
	call_deferred("run")
func check(name_value:String,value:bool) -> void:
	checks.append({"name":name_value,"passed":value})
func frames(count:int) -> void:
	for _i in count:
		await physics_frame
		await process_frame
func run() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var flow:=Main.instantiate()
	flow.record_path="user://v06_long_%d.json" % OS.get_process_id()
	flow.generation_profile=Profile.defaults()
	root.add_child(flow)
	flow.start_endless(404)
	var max_chunks:=0
	var hurt_before:=false
	var recovered_after_hurt:=false
	var time_begin:=Time.get_ticks_msec()
	for frame in 108020:
		await physics_frame
		await process_frame
		if flow.phase!="running":
			break
		max_chunks=maxi(max_chunks,flow.course.chunks.size())
		bot(flow)
		if not hurt_before and flow.elapsed>180:
			flow.player.take_damage("test")
			hurt_before=true
		if hurt_before and flow.elapsed>360 and flow.player.move_speed>350 and flow.player.health==3:
			recovered_after_hurt=true
		if frame%1800==0:
			if DisplayServer.get_name() != "headless":
				RenderingServer.force_draw(false,0.0)
			print("LONG_PROGRESS ",int(flow.elapsed),"s health=",flow.player.health," chunks=",flow.course.chunks.size())
			samples.append({"time":flow.elapsed,"distance":flow.run_distance,"score":flow.run_score,"nodes":flow.relay_count,"health":flow.player.health,"speed":flow.target_run_speed,"front_speed":flow.chase.speed,"gap":flow.player.position.x-10-flow.chase.front_x,"chunks":flow.course.chunks.size(),"offset":flow.course.total_offset,"memory":Performance.get_monitor(Performance.MEMORY_STATIC),"objects":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"route_identities":flow.routes.closed.size()+flow.routes.stations.size(),"combo_count":flow.routes.completed,"station_heals":flow.routes.heal_choices})
	Input.action_release("jump")
	check("30分钟真实流式游戏时间",flow.elapsed>=1800 and flow.phase=="running")
	check("运行速度达到上限且伤后再积累",hurt_before and recovered_after_hurt and flow.target_run_speed==380)
	check("自动高路与恢复站存活且活动片段有界",flow.player.health==3 and max_chunks<=8 and flow.course.total_offset>0)
	check("实际中继和高路连段接入",flow.relay_count>20 and flow.routes.completed>10 and flow.routes.heal_choices>5 and flow.routes.closed.size()+flow.routes.stations.size()<=flow.course.chunks.size()*2+1)
	var metadata:={"rules_revision":6,"generator_revision":4,"profile_fingerprint":Profile.fingerprint(flow.generation_profile)}
	flow.endless_record.consider(flow.record_path,flow.run_score,flow.run_distance,flow.relay_count,flow.run_seed,metadata)
	var loaded:=Record.new()
	loaded.load_from(flow.record_path)
	check("规则版记录原子写入和重新加载",loaded.status=="loaded" and loaded.best.score==flow.run_score)
	var record:String=flow.record_path
	var final:={"phase":flow.phase,"time":flow.elapsed,"distance":flow.run_distance,"nodes":flow.relay_count,"health":flow.player.health,"gap":flow.player.position.x-10-flow.chase.front_x,"wall_ms":Time.get_ticks_msec()-time_begin,"max_chunks":max_chunks}
	root.remove_child(flow)
	flow.queue_free()
	await frames(3)
	OS.delay_msec(150)
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(record+suffix):
			DirAccess.remove_absolute(record+suffix)
	var failed:=checks.filter(func(c):return not c.passed).size()
	var file:=FileAccess.open("res://reports/v0.6/long-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failed==0,"checks":checks,"final":final,"samples":samples,"renderer":DisplayServer.get_name(),"method":"关闭逐帧渲染，headless逻辑/生命周期；真实物理60步长加速游戏时间、自动高路跳跃，180秒显式受伤；隔离成绩，非真人30分钟体验。GPU表现/独立操作另见E/F；本报告不证明正常墙钟30分钟或连续GPU渲染。"},"\t"))
	file.close()
	print(JSON.stringify({"checks":checks.size(),"failed":failed,"final":final}))
	call_deferred("quit",0 if failed==0 else 1)
func bot(flow:Node) -> void:
	held_frames+=1
	var player:Node=flow.player
	if held and held_frames>4 and player.velocity.y>=0:
		Input.action_release("jump")
		held=false
	if held or not player.is_on_floor() or flow.fall_recovery_remaining>0:
		return
	var jump:=false
	for chunk in flow.course.chunks:
		if player.position.x<chunk.origin or player.position.x>chunk.origin+chunk.length:
			continue
		var d:Dictionary=chunk.geometry
		var x:float=player.position.x-chunk.origin
		var route:Array=d.floors.duplicate()
		if not d.gaps.is_empty() and not d.platforms.is_empty():
			route=[d.floors[0]]+d.platforms+[d.floors[1]]
		elif not d.platforms.is_empty():
			route=[Rect2(0,448,288,160)]+d.platforms+[Rect2(976,448,304,160)]
		for i in route.size():
			var rect:Rect2=route[i]
			if absf(player.position.y+15-rect.position.y)<3 and x>=rect.position.x-10 and x<=rect.end.x+10:
				if i+1<route.size():
					var next:Rect2=route[i+1]
					var needs_jump:=next.position.y<rect.position.y or (next.position.x>rect.end.x+1 and next.position.y<=rect.position.y) or next.position.x>rect.end.x+48
					var lead:=60 if next.position.x<=rect.end.x+1 and next.position.y<rect.position.y else 28
					jump=needs_jump and x>=rect.end.x-lead
				break
		for spike in d.spikes:
			jump=jump or (x>=spike.position.x-70 and x<spike.end.x+10)
	if jump:
		Input.action_press("jump")
		held=true
		held_frames=0
