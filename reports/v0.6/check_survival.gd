extends SceneTree
const Main = preload("res://scenes/main/main.tscn")
var checks: Array[Dictionary] = []
var flow: Node
func _initialize() -> void:
	call_deferred("run")
func check(name_value: String, passed: bool) -> void:
	checks.append({"name": name_value, "passed": passed})
func frames(count: int) -> void:
	for _i in count:
		await physics_frame
func run() -> void:
	flow = Main.instantiate()
	flow.endless_prototype = true
	flow.record_path = "user://v06_survival_%d.json" % OS.get_process_id()
	root.add_child(flow)
	flow.start_endless(404)
	await frames(3)
	check("开局3生命基础跑速", flow.player.health == 3 and flow.player.move_speed < 281)
	flow.chase.front_x = -100000
	flow.player.set_physics_process(false)
	flow.player.position.x = 50096
	await frames(2)
	check("新增最高距离封顶380", is_equal_approx(flow.target_run_speed, 380))
	flow.player.velocity = Vector2(380, -200)
	flow.player.take_damage("spike")
	check("扣1重置速度保留垂直运动", flow.player.health == 2 and flow.player.velocity == Vector2(280, -200) and flow.target_run_speed == 280)
	flow.player.take_damage("spike")
	check("同帧与无敌去重", flow.player.health == 2 and flow.player.hurt_count == 1)
	flow.player.position.x -= 1000
	await frames(3)
	check("回跑旧路不恢复加速", is_equal_approx(flow.target_run_speed, 280))
	flow.toggle_pause()
	var remaining: float = flow.player.invulnerable_remaining
	var elapsed: float = flow.elapsed
	await frames(4)
	check("暂停冻结时钟和无敌", flow.elapsed == elapsed and flow.player.invulnerable_remaining == remaining)
	flow.toggle_pause()
	flow.restart_challenge()
	await frames(2)
	check("同seed重试重置生命和距离", flow.player.health == 3 and flow.run_distance < 100)
	flow.chase.front_x = -100000
	flow.player.auto_run = false
	flow.player.position = Vector2(600, 430)
	flow.course._add_spikes(Rect2(576, 424, 64, 24))
	await frames(6)
	check("真实尖刺接触首次扣1", flow.player.health == 2)
	await frames(80)
	check("持续重叠无敌结束再次扣1", flow.player.health == 1)
	await frames(80)
	check("第三次有效接触只结算一次", flow.player.health == 0 and flow.phase == "failed" and flow.failure_reason == "health" and flow.player.hurt_count == 3)
	flow.start_challenge(false, "time_trial", "level01")
	check("固定关保留无生命规则", not flow.player.health_enabled and flow.player.move_speed == 280)
	var record: String = flow.record_path
	flow.queue_free()
	await frames(2)
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(record + suffix):
			DirAccess.remove_absolute(record + suffix)
	var failed := checks.filter(func(c): return not c.passed).size()
	DirAccess.make_dir_recursive_absolute("res://reports/v0.6")
	var file := FileAccess.open("res://reports/v0.6/survival-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failed == 0, "checks": checks, "method": "真实尖刺Area持续碰撞；距离封顶通过显式位置注入，隔离记录；固定步长游戏时间"}, "\t"))
	file.close()
	print(JSON.stringify({"checks": checks.size(), "failed": failed}))
	quit(0 if failed == 0 else 1)
