extends SceneTree
const Main=preload("res://scenes/main/main.tscn")
const Profile=preload("res://scripts/level/generation_profile.gd")
const Record=preload("res://scripts/level/endless_record.gd")
var checks: Array[Dictionary]=[]
var curves: Array[Dictionary]=[]
func _initialize() -> void:
	call_deferred("run")
func frames(count:int) -> void:
	for _i in count:
		await physics_frame
		await process_frame
func check(name_value:String,passed:bool) -> void:
	checks.append({"name":name_value,"passed":passed})
func run() -> void:
	var flow:=Main.instantiate()
	flow.endless_prototype=true
	flow.record_path="user://v05_pressure_%d.json" % OS.get_process_id()
	root.add_child(flow)
	for speed in [280,330,380]:
		for nodes in [false,true]:
			flow.start_endless(77)
			for child in flow.course.get_children():
				if child is StaticBody2D:
					flow.course.remove_child(child)
					child.queue_free()
			flow.course.walls.clear()
			flow.course.floors.assign([Rect2(-960,448,1000000,160)])
			flow.course._add_solid(flow.course.floors[0])
			flow.course.hide()
			flow.trial_speed=speed
			flow.target_run_speed=speed
			flow.set_physics_process(false)
			flow.player.set_physics_process(false)
			for connection in flow.chase.get_signal_connection_list("threat_updated"):
				flow.chase.disconnect("threat_updated",connection.callable)
			var sample:={"speed":speed,"nodes_injected":nodes,"samples":[]}
			for frame in 60000:
				if nodes and frame>=36000:
					break
				flow.elapsed+=1.0/60.0
				flow.player.position.x+=speed/60.0
				flow.update_endless_pressure(1.0/60.0)
				if flow.chase.advance(1.0/60.0,flow.player.position.x-10):
					flow._queue_failure("caught")
					await frames(2)
				if flow.phase!="running":
					break
				# Isolated flat course: each 20s inject the same 0.9s delay as a node.
				if nodes and frame>0 and frame%1200==0:
					flow.chase.add_relay_delay(0.9)
				if frame%1800==0:
					sample.samples.append({"time":flow.elapsed,"gap":flow.player.position.x-10-flow.chase.front_x,"front_speed":flow.chase.speed})
			sample.end={"time":flow.elapsed,"phase":flow.phase,"gap":flow.player.position.x-10-flow.chase.front_x}
			curves.append(sample)
			check("三档跳过节点仍可被追上%d_%s"%[speed,nodes],flow.phase=="running" if nodes else flow.failure_reason=="caught")
			await frames(3)
	flow.set_physics_process(true)
	flow.start_endless(404)
	flow.trial_speed=380
	await frames(150)
	var before_gap:float=flow.player.position.x-10-flow.chase.front_x
	var before_front:float=flow.chase.front_x
	flow.player.take_damage("test")
	await frames(35)
	check("高速受伤后前沿连续且有挽回窗口",flow.phase=="running" and flow.player.health==2 and flow.chase.front_x>before_front and flow.chase.speed<285 and before_gap>600)
	var elapsed:float=flow.elapsed
	var invulnerability:float=flow.player.invulnerable_remaining
	flow.toggle_pause()
	await frames(4)
	check("压力/生命反馈暂停冻结",flow.elapsed==elapsed and flow.player.invulnerable_remaining==invulnerability and flow._survival_status._feedback_active)
	flow.toggle_pause()
	flow._queue_relay("irrelevant")
	flow.player.invulnerable_remaining=0
	flow.player.health=1
	flow.player.take_damage("test")
	flow._queue_failure("caught")
	await frames(3)
	check("同帧崩塌优先第三伤且不奖励",flow.failure_reason=="caught" and flow.relay_count==0)
	var metadata:={"rules_revision":5,"generator_revision":3,"profile_fingerprint":Profile.fingerprint(flow.generation_profile)}
	var record:=Record.new()
	record.expected_rules_revision=5
	record.consider(flow.record_path,1000,8000,2,77,metadata)
	record.load_from(flow.record_path)
	check("新版记录重载与规则元数据",record.status=="loaded" and record.best.score==1000)
	var old_file:=FileAccess.open(flow.record_path,FileAccess.WRITE)
	old_file.store_string(JSON.stringify({"schema":1,"best":{"score":999999,"distance":1,"nodes":0,"seed":1}}))
	old_file.close()
	record.load_from(flow.record_path)
	check("拒绝把旧规则成绩混入v05",record.status=="invalid" and record.best.score==0)
	var file_path:String=flow.record_path
	flow.queue_free()
	await frames(3)
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(file_path+suffix):
			DirAccess.remove_absolute(file_path+suffix)
	var failed:=checks.filter(func(c):return not c.passed).size()
	var file:=FileAccess.open("res://reports/v0.5/pressure-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failed==0,"checks":checks,"curves":curves,"method":"三速度平地距离显式线性注入，调用正式update_endless_pressure/Chase.advance，以20秒一次0.9s节点延迟模拟；不是实际路线/玩家输入。伤害/暂停另用实际物理帧。"},"\t"))
	file.close()
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	call_deferred("quit",0 if failed==0 else 1)
