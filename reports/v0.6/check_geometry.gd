extends SceneTree
const Geometry = preload("res://scripts/level/vertical_library.gd")
const Player = preload("res://scripts/player/player.gd")
const Course = preload("res://scripts/level/course.gd")
var results: Array[Dictionary] = []
func _initialize() -> void:
	preload("res://scripts/core/input_bindings.gd").configure()
	call_deferred("run")
func run() -> void:
	for id in ["relay_a","relay_b"]:
		if "--reward-only" in OS.get_cmdline_user_args() and id not in ["relay_a","relay_b"]:
			continue
		for variant in 9:
			for speed in [280,330,380]:
				for injury in [false,true]:
					await trial(id,variant,speed,injury)
	var failed := results.filter(func(r): return not r.passed)
	DirAccess.make_dir_recursive_absolute("res://reports/v0.6")
	var output := "reward-results.json" if "--reward-only" in OS.get_cmdline_user_args() else "geometry-results.json"
	var file := FileAccess.open("res://reports/v0.6/"+output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failed.is_empty(),"runs":results,"method":"真实Player/move_and_slide碰撞；每种结构3档参数、3跑速；injury为首次跳跃上升阶段显式伤害注入降到280；脚本自动按跳跃，非真人体验"},"\t"))
	file.close()
	print(JSON.stringify({"runs":results.size(),"failed":failed}))
	quit(0 if failed.is_empty() else 1)
func trial(id: String,variant: int,speed: int,injury: bool) -> void:
	var d := Geometry.build(id,32+(variant%3)*16,64+int(variant/3)*16,variant)
	d.relays = [{"local_id":"challenge_1","position":Vector2(400,448-(32+(variant%3)*16)-34)},{"local_id":"challenge_2","position":Vector2(588+(64+int(variant/3)*16),448-2*(32+(variant%3)*16)-34)},{"local_id":"challenge_3","position":Vector2(860,448-(32+(variant%3)*16)-34)},{"local_id":"low","position":Vector2(1010,410)}]
	var course := Course.new()
	course.lab_mode = true
	root.add_child(course)
	for child in course.get_children():
		course.remove_child(child)
		child.queue_free()
	for rect in d.floors+d.walls:
		course._add_solid(rect)
	for rect in d.platforms:
		course._add_solid(rect,null,true)
	for relay in d.relays:
		course.relays.append({"id":relay.local_id,"position":relay.position,"activated":false})
	var player := Player.new()
	root.add_child(player)
	player.auto_run = true
	player.health_enabled = true
	player.reset_at(Vector2(96,430))
	player.move_speed = speed
	var route: Array = d.floors.duplicate()
	if id in ["rhythm_a","relay_a","relay_b"]:
		route = [Rect2(0,448,288,160)] + d.platforms + [Rect2(976,448,304,160)]
	elif id == "gap":
		route = [d.floors[0]] + d.platforms + [d.floors[1]]
	var surfaces_hit := {}
	var jump_count := 0
	var injured := false
	var held := false
	var held_frames := 0
	var collected := {}
	var previous := player.position
	for frame in 900:
		await physics_frame
		for reward_id in course.relay_candidates(previous,player.position):
			collected[reward_id] = true
			course.activate_relay(reward_id)
		previous = player.position
		held_frames += 1
		if held and held_frames > 4 and player.velocity.y >= 0:
			Input.action_release("jump")
			held = false
		if injury and not injured and player.velocity.y < -200:
			player.take_damage("test")
			injured = true
		if player.is_on_floor():
			for i in route.size():
				var rect: Rect2 = route[i]
				if absf(player.position.y+15-rect.position.y) < 3 and player.position.x >= rect.position.x-10 and player.position.x <= rect.end.x+10:
					surfaces_hit[i] = true
					if i+1 < route.size():
						var next: Rect2 = route[i+1]
						var needs_jump := next.position.y < rect.position.y or (next.position.x > rect.end.x+1 and next.position.y <= rect.position.y) or next.position.x > rect.end.x+48
						var lead := 60 if next.position.x <= rect.end.x+1 and next.position.y < rect.position.y else 28
						if needs_jump and player.position.x >= rect.end.x-lead and not held:
							Input.action_press("jump")
							held = true
							held_frames = 0
							jump_count += 1
					break
		if player.position.x > 1120 or player.position.y > 650:
			break
	Input.action_release("jump")
	var upper_ok := true
	if id in ["rhythm_a","relay_a","relay_b"]:
		upper_ok = surfaces_hit.has(1) and surfaces_hit.has(2) and surfaces_hit.has(3)
	var reward_ok: bool = collected.size()==d.relays.size()
	results.append({"id":id,"variant":variant,"speed":speed,"injury":injury,"injured":injured,"passed":player.position.x>1120 and player.position.y<650 and upper_ok and (injured or not injury) and reward_ok,"position":[player.position.x,player.position.y],"surfaces":surfaces_hit.keys(),"jumps":jump_count,"rewards":collected.keys()})
	root.remove_child(player)
	root.remove_child(course)
	player.queue_free()
	course.queue_free()
	await process_frame
