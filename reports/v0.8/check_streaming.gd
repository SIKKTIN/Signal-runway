extends SceneTree
const Main=preload("res://scenes/main/main.tscn")
var held:=false
var held_frames:=0
var selected: Dictionary={}
var used: Dictionary={}
var samples: Array[Dictionary]=[]
func _initialize() -> void:
	call_deferred("run")
func step(flow: Node) -> void:
	Input.action_release("dash")
	held_frames+=1
	var player=flow.player
	var current: Dictionary={}
	for chunk in flow.course.chunks:
		if player.position.x>=chunk.origin and player.position.x<chunk.origin+1280:
			current=chunk
			break
	if current.is_empty():
		return
	var d: Dictionary=current.geometry
	if not selected.has(current.id):
		selected[current.id]=player.dash_charges>=1 if d.has("skill") else (d.has("challenge") or d.has("station") or d.connection.upper_from)
	var high: bool=selected[current.id]
	var short_jump: bool=high and d.get("skill",{}).get("kind","")=="rescue"
	if held and held_frames>=4 and (short_jump or player.velocity.y>=0):
		Input.action_release("jump")
		held=false
	var x: float=player.position.x-current.origin
	if player.is_on_floor() and not held:
		for w in d.jump_windows:
			if w.kind!="primary" and not high:
				continue
			var a: Vector2=w.from
			var lead:=4.0 if w.kind=="skill" else (24.0 if w.to.x>a.x+8 else 60.0)
			if x>=a.x-lead and x<a.x+12 and absf(player.position.y+15-a.y)<7:
				Input.action_press("jump")
				held=true
				held_frames=0
				break
	if high and d.has("skill"):
		for j in d.skill.dash_windows.size():
			var w: Dictionary=d.skill.dash_windows[j]
			var key: String=current.id+":"+str(j)
			if not used.has(key) and x>=w.dash_x and x<w.to.x and not player.is_on_floor() and player.dash_charges>0 and not player.dash_active:
				Input.action_press("dash")
				used[key]=true
	var live:={}
	for chunk in flow.course.chunks:
		live[chunk.id]=true
	for id in selected.keys():
		if not live.has(id):
			selected.erase(id)
	for id in used.keys():
		if not live.has(str(id).get_slice(":",0)+":"+str(id).get_slice(":",1)):
			used.erase(id)
func run() -> void:
	print("V08_STREAM_PID ",OS.get_process_id())
	var wall_start:=Time.get_ticks_msec()
	var flow:=Main.instantiate()
	flow.record_path="res://reports/v0.8/workflow/streaming-score.json"
	root.add_child(flow)
	flow.start_endless(404)
	var injured:=false
	var max_chunks:=0
	var max_identities:=0
	for frame in 18000:
		await physics_frame
		step(flow)
		if not injured and flow.elapsed>=120:
			flow.player.take_damage("explicit-stream-fixture")
			injured=true
			for chunk in flow.course.chunks:
				if flow.player.position.x>=chunk.origin and flow.player.position.x<chunk.origin+1280:
					selected[chunk.id]=false
		max_chunks=maxi(max_chunks,flow.course.chunks.size())
		max_identities=maxi(max_identities,flow.player._dash_nodes.size())
		if frame%600==0:
			samples.append({"elapsed":flow.elapsed,"distance":flow.run_distance,"health":flow.player.health,"offset":flow.course.total_offset,"chunks":flow.course.chunks.size(),"dash":flow.player.dash_snapshot(),"dash_identities":flow.player._dash_nodes.size(),"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"static_memory":OS.get_static_memory_usage()})
		if flow.phase=="failed":
			break
	Input.action_release("jump")
	Input.action_release("dash")
	var result:={"passed":flow.phase=="running" and flow.elapsed>=299 and flow.course.total_offset>=51200 and max_chunks<=8 and max_identities<=32 and flow.player.dash_used>0,"phase":flow.phase,"reason":flow.failure_reason,"elapsed":flow.elapsed,"wall_seconds":float(Time.get_ticks_msec()-wall_start)/1000,"distance":flow.run_distance,"health":flow.player.health,"max_chunks":max_chunks,"max_dash_identities":max_identities,"offset":flow.course.total_offset,"dash":flow.player.dash_snapshot(),"score":flow.score_breakdown(),"samples":samples,"method":"Frozen candidate638 actual Main natural start, fixed60 headless geometry-aware synthetic jump/dash, resource-based route choice. No traversal position/chase/clock/resource injection; injury explicitly at120 game seconds. 300 game seconds, not five wall-clock GPU minutes or human fun proof."}
	root.remove_child(flow)
	flow.queue_free()
	await process_frame
	await process_frame
	OS.delay_msec(150)
	var file:=FileAccess.open("res://reports/v0.8/streaming-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print(JSON.stringify({"passed":result.passed,"elapsed":result.elapsed,"reason":result.reason,"distance":result.distance,"offset":result.offset,"dash":result.dash,"wall_seconds":result.wall_seconds}))
	quit(0 if result.passed else 1)
