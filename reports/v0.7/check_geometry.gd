extends "res://reports/v0.7/check_terrain.gd"
const Vertical=preload("res://scripts/level/vertical_library.gd")
func run() -> void:
	for id in ["slope","terrace","bridge","basin","upper"]:
		for variant in 3:
			if "--bridge-fix" in OS.get_cmdline_user_args() and (id!="bridge" or variant!=2):
				continue
			for speed in [280,330,380]:
				for injury in [false,true]:
					await geometry_trial(id,variant,speed,injury)
	var passed:=runs.all(func(r):return r.passed)
	var file:=FileAccess.open("res://reports/v0.7/bridge-fix-results.json" if "--bridge-fix" in OS.get_cmdline_user_args() else "res://reports/v0.7/geometry-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"runs":runs,"method":"headless fixed60, real Player/collision, synthetic jump controller using actual jump windows. Four structures and two-chunk upper corridor; 3 envelope variants x3 speeds x normal/explicit injury at ascending jump or mid-ground. No position/speed/clock injections during traversal except disclosed injury."},"\t"))
	file.close()
	print(JSON.stringify({"passed":passed,"runs":runs.size(),"failed":runs.filter(func(r):return not r.passed)}))
	quit(0 if passed else 1)
func geometry_trial(id: String,variant: int,speed: int,injury: bool) -> void:
	var entry:=384.0+variant*64
	var h:=32.0+variant*16
	var gap:=64.0+variant*16
	var d: Dictionary
	var next: Dictionary
	if id=="upper":
		var original:=Vertical.build("relay_a",h,gap)
		original.relays=[{"local_id":"challenge_1","position":Vector2(400,448-h-34)},{"local_id":"challenge_2","position":Vector2(588+gap,448-2*h-34)},{"local_id":"challenge_3","position":Vector2(860,448-h-34)}]
		original.challenge={"entry":Rect2(280,0,96,448-h-10),"lower":Rect2(370,410,606,110),"exit_x":976.0,"order":["challenge_1","challenge_2","challenge_3"],"bonus":200}
		d=Spatial.reward_segment(original,entry)
		Spatial.extend_upper(d,entry-h,false,true,"fixture")
		next=Spatial.empty("slope",entry,entry,h,gap)
		Spatial.surface(next,Vector2(0,entry),Vector2(1280,entry))
		Spatial.extend_upper(next,entry-h,true,false,"fixture")
	else:
		d=Spatial.build(id,entry,entry+32 if entry<512 else entry-32,h,gap,variant)
		next=Spatial.build("slope",d.connection.exit_y,448,32,80)
	for value in [d,next]:
		value.category="safe"
		value.difficulty=0
	var course:=Course.new()
	course.prototype=false
	root.add_child(course)
	for child in course.get_children():
		course.remove_child(child)
		child.free()
	course.chunks.clear()
	course._holders.clear()
	course._generated_end=0
	for i in 2:
		course._append_chunk({"geometry":d if i==0 else next,"index":i,"template_id":"safe_a","stage":0})
	course._sync_geometry()
	var player:=Player.new()
	root.add_child(player)
	player.auto_run=true
	player.health_enabled=true
	player.floor_snap_length=16
	player.floor_constant_speed=true
	player.reset_at(Vector2(96,entry-18))
	player.move_speed=speed
	var injured:=false
	var held:=false
	var held_frames:=0
	var seen:={}
	var previous:=player.position
	var jumps:=0
	var seam_height:=-1.0
	for frame in 900:
		await physics_frame
		for key in course.relay_candidates(previous,player.position):
			seen[key]=true
			course.activate_relay(key)
		if previous.x<1280 and player.position.x>=1280:
			seam_height=player.position.y
		previous=player.position
		held_frames+=1
		if held and held_frames>4 and player.velocity.y>=0:
			Input.action_release("jump")
			held=false
		if injury and not injured and (player.velocity.y<-200 or (jumps==0 and player.position.x>512)):
			player.take_damage("fixture")
			injured=true
		if player.is_on_floor() and not held:
			var local_x:=fmod(player.position.x,1280)
			var current: Dictionary=d if player.position.x<1280 else next
			for w in current.jump_windows:
				if w.kind!="primary" and id!="upper":
					continue
				var a: Vector2=w.from
				var b: Vector2=w.to
				var lead:=24.0 if b.x>a.x+8 else 60.0
				if local_x>=a.x-lead and local_x<a.x+8 and absf(player.position.y+15-a.y)<7:
					Input.action_press("jump")
					held=true
					held_frames=0
					jumps+=1
					break
		if player.position.x>2416 or player.position.y>650:
			break
	Input.action_release("jump")
	var upper_ok:=id!="upper" or (seen.size()==3 and absf(seam_height+15-(entry-h))<6)
	runs.append({"id":id,"variant":variant,"speed":speed,"injury":injury,"injured":injured,"position":str(player.position),"jumps":jumps,"rewards":seen.keys(),"seam_height":seam_height,"passed":player.position.x>2416 and player.position.y<650 and upper_ok and (not injury or injured)})
	root.remove_child(player)
	root.remove_child(course)
	player.free()
	course.free()
	await process_frame
