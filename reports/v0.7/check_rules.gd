extends SceneTree
const Main=preload("res://scenes/main/main.tscn")
const Profile=preload("res://scripts/level/generation_profile.gd")
const Route=preload("res://scripts/level/route_challenge.gd")
const Vertical=preload("res://scripts/level/vertical_library.gd")
var checks: Array[Dictionary]=[]
func _initialize() -> void:
	call_deferred("run")
func frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame
func check(name_value: String,value: bool) -> void:
	checks.append({"name":name_value,"passed":value})
func challenge() -> Dictionary:
	var d:=Vertical.build("relay_a",48,80)
	d.challenge={"entry":Rect2(280,0,96,390),"exit_x":976.0,"lower":Rect2(370,410,606,110),"order":["one","two","three"],"bonus":200}
	d.relays=[{"local_id":"one","position":Vector2(400,366)},{"local_id":"two","position":Vector2(668,318)},{"local_id":"three","position":Vector2(860,366)}]
	return {"id":"404:2","origin":2560.0,"geometry":d}
func run() -> void:
	var chunk:=challenge()
	var tracker:=Route.new()
	tracker.begin_step(Vector2(2800,370),Vector2(2850,370),[chunk],0,false)
	check("高路入口开始",tracker.active==chunk.id)
	for id in ["one","two","three"]:
		tracker.node(chunk.id+":"+id)
	check("三个顺序节点尚未出口不给额外分",tracker.progress==3 and tracker.combo_score==0)
	tracker.begin_step(Vector2(3500,380),Vector2(3550,390),[chunk],0,false)
	tracker.end_step([chunk],0,3)
	check("到出口完成且额外200",tracker.completed==1 and tracker.combo_score==200)
	tracker.begin_step(Vector2(2800,370),Vector2(2850,370),[chunk],0,false)
	check("回跑不能重启完成挑战",tracker.active.is_empty())
	tracker.reset()
	tracker.begin_step(Vector2(2800,370),Vector2(2850,370),[chunk],0,false)
	tracker.node(chunk.id+":two")
	check("乱序中断无奖励",tracker.interrupted==1 and tracker.combo_score==0)
	tracker.reset()
	tracker.begin_step(Vector2(2800,370),Vector2(2850,370),[chunk],0,false)
	tracker.begin_step(Vector2(2850,370),Vector2(3000,370),[chunk],0,false)
	tracker.end_step([chunk],0,3)
	check("越过节点立即中断",tracker.interrupted==1)
	tracker.reset()
	tracker.begin_step(Vector2(2800,370),Vector2(2850,370),[chunk],0,false)
	tracker.begin_step(Vector2(2900,395),Vector2(3000,430),[chunk],0,false)
	tracker.end_step([chunk],0,3)
	check("落回下路中断",tracker.interrupted==1)
	tracker.reset()
	tracker.begin_step(Vector2(2800,370),Vector2(2850,370),[chunk],0,true)
	check("受伤帧进入不能启动",tracker.active.is_empty() and tracker.closed.has(chunk.id))
	tracker.reset()
	tracker.begin_step(Vector2(2800,370),Vector2(2850,370),[chunk],0,false)
	tracker.interrupt("damage")
	tracker.begin_step(Vector2(2800,370),Vector2(2850,370),[chunk],0,false)
	check("伤害中断且恢复不能重启",tracker.interrupted==1 and tracker.active.is_empty())
	var station:={"id":"404:20","origin":25600.0,"geometry":{"station":{"heal":Vector2(460,382),"score":Vector2(460,430),"bonus":200}}}
	for hp in [1,2,3]:
		tracker.reset()
		tracker.begin_step(Vector2(26020,400),Vector2(26080,400),[station],0,false)
		var action:=tracker.end_step([station],0,hp)
		check("补血上限%d"%hp,action.size()==1 and action[0].kind=="heal" and action[0].amount==(1 if hp<3 else 0))
		tracker.begin_step(Vector2(26020,430),Vector2(26080,430),[station],0,false)
		check("两路互斥%d"%hp,tracker.end_step([station],0,hp).is_empty() and tracker.station_score==0)
	tracker.reset()
	tracker.begin_step(Vector2(26020,430),Vector2(26080,430),[station],0,false)
	tracker.end_step([station],0,2)
	check("积分选择只一次200",tracker.station_score==200 and tracker.score_choices==1)
	tracker.begin_step(Vector2(26020,430),Vector2(26080,430),[station],0,false)
	tracker.end_step([station],0,2)
	check("重复接触不刷分",tracker.station_score==200)
	tracker.begin_step(Vector2.ZERO,Vector2.ZERO,[],0,false)
	check("身份随回收有界清理",tracker.stations.is_empty() and tracker.closed.is_empty())
	var flow:=Main.instantiate()
	flow.generation_profile=Profile.defaults()
	flow.record_path="user://v07_rules_%d.json"%OS.get_process_id()
	root.add_child(flow)
	flow.start_endless(404)
	await frames(4)
	flow.chase.front_x=-100000
	flow.player.set_physics_process(false)
	flow.course.chunks[0].geometry.station={"heal":Vector2(140,382),"score":Vector2(140,430),"bonus":200}
	flow.player.health=2
	flow._previous_position=Vector2(96,400)
	flow.player.position=Vector2(140,400)
	await frames(2)
	check("实际Flow扫掠补血2至3",flow.player.health==3 and flow.routes.heal_choices==1)
	flow.player.position=Vector2(140,430)
	await frames(2)
	check("Flow同站另一条不能领",flow.routes.station_score==0)
	flow.toggle_pause()
	var snapshot:=var_to_bytes(flow.routes.snapshot())
	await frames(4)
	check("暂停冻结连段站点",snapshot==var_to_bytes(flow.routes.snapshot()))
	flow.toggle_pause()
	flow.restart_challenge()
	await frames(2)
	check("重试清理全部连段站点",flow.routes.completed==0 and flow.routes.heal_choices==0 and flow.routes.closed.is_empty())
	flow.chase.front_x=-100000
	flow.player.set_physics_process(false)
	flow.player.health=1
	flow.course.chunks[0].geometry.station={"heal":Vector2(140,382),"score":Vector2(140,430),"bonus":200}
	flow._previous_position=Vector2(96,400)
	flow.player.position=Vector2(140,400)
	flow.player.take_damage("test")
	await frames(2)
	check("致命伤同帧补血不能复活",flow.phase=="failed" and flow.player.health==0 and flow.routes.heal_choices==0)
	flow.restart_challenge()
	await frames(2)
	flow.chase.front_x=-100000
	flow.player.set_physics_process(false)
	flow.course.chunks[0].geometry.station={"heal":Vector2(140,382),"score":Vector2(140,430),"bonus":200}
	flow._previous_position=Vector2(96,400)
	flow.player.position=Vector2(140,400)
	flow.player.take_damage("test")
	await frames(2)
	check("非致命伤先扣再补且降速保留",flow.player.health==3 and flow.player.hurt_count==1 and flow.target_run_speed<281 and flow.routes.heal_choices==1)
	flow.routes.combo_score=200
	flow.routes.station_score=200
	check("四类分数明细之和",flow.total_score()==int(flow.run_distance/10)+flow.relay_count*100+400)
	var record:String=flow.record_path
	root.remove_child(flow)
	flow.queue_free()
	await frames(3)
	OS.delay_msec(150)
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(record+suffix):
			DirAccess.remove_absolute(record+suffix)
	var failed:=checks.filter(func(c):return not c.passed)
	var f:=FileAccess.open("res://reports/v0.7/rules-results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":failed.is_empty(),"checks":checks,"method":"state-machine event cases and actual Main with explicit stationary position/health/geometry injections for same-frame rules; not natural traversal"},"\t"))
	f.close()
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	call_deferred("quit",0 if failed.is_empty() else 1)
