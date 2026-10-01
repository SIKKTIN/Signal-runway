extends SceneTree
const Main=preload("res://scenes/main/main.tscn")
const Profile=preload("res://scripts/level/generation_profile.gd")
const Player=preload("res://scripts/player/player.gd")
const OldProfile=preload("res://reports/v0.8/workflow/old_generation_profile.gd")
var checks: Array[Dictionary]=[]
var runs: Array[Dictionary]=[]
func _initialize() -> void:
	preload("res://scripts/core/input_bindings.gd").configure()
	call_deferred("run")
func check(name: String,passed: bool,actual: Variant=null) -> void:
	checks.append({"check":name,"passed":passed,"actual":actual})
	print(name+": "+str(passed))
func run() -> void:
	var p:=Player.new()
	root.add_child(p)
	p.dash_enabled=true
	p.health_enabled=true
	check("initial_resource",p.dash_charges==1 and p.dash_progress==0)
	p.charge_dash("1:0:a")
	p.charge_dash("1:0:a")
	check("unique_node_only",p.dash_progress==1 and p.dash_charges==1)
	p.charge_dash("1:0:b")
	check("two_nodes_refill",p.dash_charges==2 and p.dash_progress==0)
	p.charge_dash("1:0:c")
	p.charge_dash("1:0:d")
	check("full_no_hidden_credit",p.dash_charges==2 and p.dash_progress==0)
	p.try_dash()
	check("start_consumes_once",p.dash_active and p.dash_charges==1 and not p.try_dash())
	p.take_damage("fixture")
	check("damage_cancels_no_refund",not p.dash_active and p.health==2 and p.dash_charges==1 and p.move_speed==280)
	p.recover_at(Vector2.ZERO)
	check("recovery_keeps_resource",p.dash_charges==1 and p.dash_progress==0)
	p.die("caught")
	check("dead_cannot_dash_or_charge",not p.try_dash() and not p.charge_dash("1:0:e"))
	p.reset_at(Vector2.ZERO)
	check("retry_initial_resource",p.dash_charges==1 and p.dash_progress==0 and p._dash_nodes.is_empty())
	root.remove_child(p)
	p.free()
	check("v5_normalization_preserved",JSON.stringify(Profile.normalized(Profile.v07_defaults()),"",true)==JSON.stringify(OldProfile.normalized(OldProfile.defaults()),"",true))
	check("v6_profile_valid",Profile.validate(Profile.defaults()).is_empty())
	for kind in ["shortcut","relay","rescue"]:
		for speed in [280,330,380]:
			for strategy in ["stable","skill"]:
				if "--shortcut-fix" in OS.get_cmdline_user_args() and (kind!="shortcut" or strategy!="skill"):
					continue
				await trial(kind,speed,strategy)
	var passed:=checks.all(func(c):return c.passed)
	var file:=FileAccess.open("res://reports/v0.8/a-fix-results.json" if "--shortcut-fix" in OS.get_cmdline_user_args() else "res://reports/v0.8/a-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"runs":runs,"method":"Real Main/Player/course, fixed60 headless, synthetic jump/dash inputs from declared windows. Initial kind/profile/trial speed and zero resources on stable route explicitly injected. Rescue skill uses deliberate short jump; no position/chase/time injections during traversal. Unit damage/recovery/terminal are explicit fixtures. Fun is not measured."},"\t"))
	file.close()
	await process_frame
	await process_frame
	quit(0 if passed else 1)
func make_flow(kind: String,speed: int,strategy: String) -> Node2D:
	var flow:=Main.instantiate()
	flow.generation_profile=Profile.defaults()
	flow.dash_prototype_kind=kind
	flow.trial_speed=float(speed)
	flow.record_path="res://reports/v0.8/isolated-a.json"
	root.add_child(flow)
	flow.start_endless(404)
	flow.player.dash_charges=0 if strategy=="stable" else 1
	return flow
func on_frame(_flow: Node2D) -> void:
	pass
func good_run(flow: Node2D,kind: String,strategy: String) -> bool:
	return flow.phase=="prototype_done" and flow.player.health==3 and (strategy!="skill" or flow.player.dash_used>0) and (kind=="rescue" or strategy!="skill" or flow.routes.completed==1)
func trial(kind: String,speed: int,strategy: String) -> void:
	var flow:=make_flow(kind,speed,strategy)
	var held:=false
	var held_frames:=0
	var used:={}
	for frame in 1400:
		await physics_frame
		Input.action_release("dash")
		var player=flow.player
		on_frame(flow)
		held_frames+=1
		if held and held_frames>=4 and ((kind=="rescue" and strategy=="skill") or player.velocity.y>=0):
			Input.action_release("jump")
			held=false
		for chunk in flow.course.chunks:
			var d: Dictionary=chunk.geometry
			var x: float=player.position.x-chunk.origin
			if player.is_on_floor() and not held:
				for w in d.jump_windows:
					if strategy=="stable" and w.kind!="primary":
						continue
					var a: Vector2=w.from
					var lead:=4.0 if w.kind=="skill" else (24.0 if w.to.x>a.x+8 else 60.0)
					if x>=a.x-lead and x<a.x+12 and absf(player.position.y+15-a.y)<7:
						Input.action_press("jump")
						held=true
						held_frames=0
						break
			if strategy=="skill" and d.has("skill"):
				for j in d.skill.dash_windows.size():
					var w: Dictionary=d.skill.dash_windows[j]
					var key:=str(chunk.index)+":"+str(j)
					if not used.has(key) and x>=w.dash_x and x<w.to.x and not player.is_on_floor() and player.dash_charges>0 and not player.dash_active:
						Input.action_press("dash")
						used[key]=true
		if flow.phase not in ["running","ready"]:
			break
	Input.action_release("jump")
	Input.action_release("dash")
	var good: bool=good_run(flow,kind,strategy)
	var row:={"kind":kind,"speed":speed,"strategy":strategy,"phase":flow.phase,"position":str(flow.player.position),"health":flow.player.health,"dash":flow.player.dash_snapshot(),"score":flow.score_breakdown(),"passed":good}
	runs.append(row)
	check(kind+"_"+str(speed)+"_"+strategy,good,row)
	root.remove_child(flow)
	flow.free()
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists("res://reports/v0.8/isolated-a.json"+suffix):
			DirAccess.remove_absolute("res://reports/v0.8/isolated-a.json"+suffix)
	await process_frame
