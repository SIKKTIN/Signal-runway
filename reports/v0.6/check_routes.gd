extends SceneTree
const Main=preload("res://scenes/main/main.tscn")
const Profile=preload("res://scripts/level/generation_profile.gd")
var results: Array[Dictionary]=[]
var held:=false
var held_frames:=0
var prefer_upper:=true
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var diagnostic: bool="--diagnostic" in OS.get_cmdline_user_args()
	for seed_value in ([404] if diagnostic else [404,77,9001]):
		for upper in ([false] if diagnostic else [false,true]):
			await trial(seed_value,upper)
	var failed:=results.filter(func(r):return not r.passed)
	var f:=FileAccess.open("res://reports/v0.6/"+("routes-diagnostic-results.json" if diagnostic else "routes-results.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":failed.is_empty(),"runs":results,"method":"actual Main from start, real Player physics and automatic jump actions; upper runs inject one damage at distance2000 to verify restoration, no position/speed/front/time injection; headless fixed60 accelerated game time"},"\t"))
	f.close()
	print(JSON.stringify({"runs":results.size(),"failed":failed}))
	call_deferred("quit",0 if failed.is_empty() else 1)
func trial(seed_value:int,upper:bool) -> void:
	prefer_upper=upper
	held=false
	held_frames=0
	var flow:=Main.instantiate()
	flow.generation_profile=Profile.defaults()
	flow.record_path="user://v06_route_%d_%d.json"%[OS.get_process_id(),seed_value]
	root.add_child(flow)
	flow.start_endless(seed_value)
	var damaged:=false
	var first_station:=0
	for frame in 11000:
		await physics_frame
		await process_frame
		if flow.phase!="running":
			break
		bot(flow)
		if upper and not damaged and flow.run_distance>2000:
			flow.player.take_damage("check")
			damaged=true
		for chunk in flow.course.chunks:
			if chunk.geometry.has("station") and first_station==0:
				first_station=chunk.index
		if first_station>0 and flow.run_distance>(first_station+1)*1280:
			break
	Input.action_release("jump")
	var state:Dictionary=flow.routes.snapshot()
	var passed:bool=flow.phase=="running" and first_station>0 and flow.run_distance>(first_station+1)*1280 and ((upper and state.completed>0 and state.heal_choices==1 and flow.player.health==3) or (not upper and state.completed==0 and state.score_choices==1 and flow.player.health==3))
	results.append({"seed":seed_value,"upper":upper,"passed":passed,"phase":flow.phase,"reason":flow.failure_reason,"distance":flow.run_distance,"health":flow.player.health,"hurt_count":flow.player.hurt_count,"first_station":first_station,"routes":state,"score":flow.run_score,"time":flow.elapsed})
	print("ROUTE ",seed_value," upper=",upper," passed=",passed)
	var record:String=flow.record_path
	root.remove_child(flow)
	flow.queue_free()
	await process_frame
	await process_frame
	OS.delay_msec(150)
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(record+suffix):
			DirAccess.remove_absolute(record+suffix)
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
		elif not d.platforms.is_empty() and prefer_upper:
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
