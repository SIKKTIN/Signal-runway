extends "res://reports/v0.8/check_a.gd"
const Skill=preload("res://scripts/level/skill_library.gd")
const Spatial=preload("res://scripts/level/spatial_library.gd")
var variant:=0
var injury:=false
var injured:=false
func run() -> void:
	for v in 3:
		variant=v
		for kind in ["shortcut","relay","rescue"]:
			for speed in [280,330,380]:
				for strategy in ["stable","skill","hurt"]:
					if kind=="rescue" and strategy=="hurt":
						continue
					injury=strategy=="hurt"
					injured=false
					await trial(kind,speed,"skill" if injury else strategy)
					runs.back().variant=variant
					runs.back().injury=injury
	var passed:=checks.all(func(c):return c.passed)
	var file:=FileAccess.open("res://reports/v0.8/skill-geometry-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"runs":runs,"method":"72 actual Main trials: 3 envelope variants(384/32,448/48,512/64)x3 speedsxstable/skill, plus shortcut/relay injury cancelling first dash after 0.05 sec. Explicit initial geometry/spawn/speed/resources; no traversal position/chase/time injection. Injured high route may fail but stable ground preserves run, health2 expected."},"\t"))
	file.close()
	print(JSON.stringify({"passed":passed,"runs":runs.size(),"failed":runs.filter(func(r):return not r.passed)}))
	await process_frame
	quit(0 if passed else 1)
func make_flow(kind: String,speed: int,strategy: String) -> Node2D:
	var flow:=super.make_flow(kind,speed,strategy)
	var course=flow.course
	for holder in course._holders.values():
		course.remove_child(holder)
		holder.queue_free()
	course._holders.clear()
	course.chunks.clear()
	course._generated_end=0
	var entry:=384.0+variant*64
	var height:=32.0+variant*16
	for i in 3:
		var d: Dictionary
		if i==1:
			d=Skill.build(kind,entry,height)
		else:
			d=Spatial.empty("slope",entry,entry,32,80)
			Spatial.surface(d,Vector2(0,entry),Vector2(1280,entry))
			d.category="safe"
			d.difficulty=0
		course._append_chunk({"geometry":d,"index":i,"template_id":"safe_a","stage":0})
	course._sync_geometry()
	course.chunks_changed.emit()
	flow.player.reset_at(Vector2(96,entry-18))
	flow.player.dash_charges=0 if strategy=="stable" else 1
	flow._previous_position=flow.player.position
	return flow
func on_frame(flow: Node2D) -> void:
	if injury and not injured and flow.player.dash_active and flow.player.dash_remaining<0.15:
		flow.player.take_damage("fixture")
		injured=true
func good_run(flow: Node2D,kind: String,strategy: String) -> bool:
	if injury:
		return flow.phase=="prototype_done" and flow.player.health==2 and injured and not flow.player.dash_active
	return super.good_run(flow,kind,strategy)
