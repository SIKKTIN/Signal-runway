extends SceneTree
const Main = preload("res://scenes/main/main.tscn")
var checks: Array[Dictionary] = []
func _initialize() -> void:
	call_deferred("run")
func frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame
func check(name_value: String,value: bool) -> void:
	checks.append({"name":name_value,"passed":value})
func run() -> void:
	var flow := Main.instantiate()
	flow.record_path = "user://v07_recovery_%d.json" % OS.get_process_id()
	root.add_child(flow)
	flow.start_endless(404)
	# Set up an actual generated sloped surface, then use real Player contact.
	var selected: Dictionary={}
	var local_point:=Vector2.ZERO
	var generator: RefCounted=load("res://scripts/level/endless_generator.gd").new()
	generator.reset(404)
	for i in 20:
		var row: Dictionary=generator.next()
		if not row.geometry.polygons.is_empty():
			selected=row
			var polygon: PackedVector2Array=row.geometry.polygons[0]
			local_point=(polygon[0]+polygon[1])/2
			break
	var target:=float(selected.index)*1280+local_point.x
	flow.course.update_stream(target,target-1200)
	flow.player.recover_at(Vector2(target,local_point.y-18))
	flow._previous_position=flow.player.position
	flow.run_distance=target-96
	flow.chase.reset(target)
	flow.chase.set_enabled(true)
	flow.chase.front_x=target-1200
	flow.chase.grace_remaining = 0
	await frames(24)
	check("生成坡面实际着地记录安全点",not flow.safe_points.is_empty())
	var score: int = flow.run_score
	var distance: float = flow.run_distance
	var front: float = flow.chase.front_x
	flow.player.position.y = 660
	await frames(3)
	check("掉坑扣1而非立即死亡",flow.player.health==2 and flow.phase=="running" and flow.fall_recovery_remaining>0)
	await frames(20)
	check("后方安全点恢复，时间前沿继续",flow.player.position.y<650 and flow.player.position.x<distance+96+150 and flow.chase.front_x>front and flow.player.health==2)
	check("恢复不减少最高距离分不扫奖励",flow.run_distance>=distance and flow.run_score>=score and flow.relay_count==0)
	var saved_global: Vector2 = flow.safe_points.back().global_point
	flow._shift_endless_world(25600)
	check("重定位安全点全局身份保持",flow.safe_points.back().global_point==saved_global and flow.course.safe_point_exists(flow.safe_points.back()))
	flow._restore_safe_point()
	check("重定位后恢复到正确局部位置",absf(flow.player.position.x-(saved_global.x-25600))<0.1)
	flow.start_endless(404)
	flow.chase.front_x=-100000
	await frames(24)
	flow.player.position.y=660
	await frames(2)
	flow.chase.front_x=flow.player.position.x+100
	await frames(2)
	check("无敌不抵消崩塌且只终局一次",flow.phase=="failed" and flow.failure_reason=="caught")
	flow.start_endless(404)
	flow.player.set_physics_process(false)
	flow.safe_points.clear()
	flow.player.position=Vector2(400,660)
	flow.chase.front_x=-100000
	await frames(20)
	check("无安全点明确结束不会循环",flow.phase=="failed" and flow.failure_reason=="unrecoverable")
	var record: String=flow.record_path
	flow.queue_free()
	await frames(2)
	OS.delay_msec(150)
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(record+suffix):
			DirAccess.remove_absolute(record+suffix)
	var failed:=checks.filter(func(c):return not c.passed).size()
	var file:=FileAccess.open("res://reports/v0.7/recovery-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failed==0,"checks":checks,"method":"首组在真实生成坡面显式定点后通过真实着地获取安全点；掉坑/前沿/重定位为显式注入，固定步长，隔离成绩"},"\t"))
	file.close()
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	quit(0 if failed==0 else 1)
