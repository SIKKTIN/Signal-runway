extends SceneTree
const Main=preload("res://scenes/main/main.tscn")
var held:=false
var hold_frames:=0
var samples: Array[Dictionary]=[]
func _initialize() -> void:
	call_deferred("run")
func step(flow: Node) -> void:
	hold_frames+=1
	if held and hold_frames>4 and flow.player.velocity.y>=0:
		Input.action_release("jump")
		held=false
	if held or not flow.player.is_on_floor():
		return
	for chunk in flow.course.chunks:
		var x: float=flow.player.position.x-chunk.origin
		if x<0 or x>=1280:
			continue
		var d: Dictionary=chunk.geometry
		var upper: bool=d.has("challenge") or d.has("station") or d.connection.upper_from
		for w in d.jump_windows:
			if w.kind!="primary" and not upper:
				continue
			var a: Vector2=w.from
			var b: Vector2=w.to
			var lead:=24.0 if b.x>a.x+8 else 60.0
			if x>=a.x-lead and x<a.x+8 and absf(flow.player.position.y+15-a.y)<7:
				Input.action_press("jump")
				held=true
				hold_frames=0
				return
func run() -> void:
	print("V07_STREAM_PID ",OS.get_process_id())
	var wall_start:=Time.get_ticks_msec()
	var flow:=Main.instantiate()
	flow.record_path="res://reports/v0.7/workflow/streaming-score.json"
	DirAccess.make_dir_recursive_absolute("res://reports/v0.7/workflow")
	root.add_child(flow)
	flow.start_endless(404)
	var injured:=false
	var max_chunks:=0
	for frame in 36000:
		await physics_frame
		step(flow)
		if not injured and flow.elapsed>=180:
			flow.player.take_damage("explicit-long-fixture")
			injured=true
		max_chunks=maxi(max_chunks,flow.course.chunks.size())
		if frame%600==0:
			samples.append({"elapsed":flow.elapsed,"distance":flow.run_distance,"health":flow.player.health,"offset":flow.course.total_offset,"chunks":flow.course.chunks.size(),"nodes":int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),"static_memory":OS.get_static_memory_usage(),"routes":flow.routes.snapshot()})
		if flow.phase=="failed":
			break
	Input.action_release("jump")
	var result:={"passed":flow.phase=="running" and flow.elapsed>=599 and flow.course.total_offset>128000 and max_chunks<=8,"phase":flow.phase,"reason":flow.failure_reason,"elapsed":flow.elapsed,"wall_seconds":float(Time.get_ticks_msec()-wall_start)/1000,"distance":flow.run_distance,"health":flow.player.health,"max_chunks":max_chunks,"offset":flow.course.total_offset,"score":flow.score_breakdown(),"samples":samples,"method":"headless fixed60 actual Main/Player, synthetic geometry-aware jumping from natural start, no teleport/clock/front injection; explicit injury once at180 game seconds. 600 game seconds, not ten wall-clock minutes or human play. Loaded before final art freeze."}
	root.remove_child(flow)
	flow.queue_free()
	await process_frame
	await process_frame
	OS.delay_msec(150)
	var file:=FileAccess.open("res://reports/v0.7/streaming-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print(JSON.stringify({"passed":result.passed,"elapsed":result.elapsed,"reason":result.reason,"distance":result.distance,"offset":result.offset,"wall_seconds":result.wall_seconds}))
	quit(0 if result.passed else 1)
