extends SceneTree
const Spatial=preload("res://scripts/level/spatial_library.gd")
const Course=preload("res://scripts/level/endless_course.gd")
const Player=preload("res://scripts/player/player.gd")
var runs: Array[Dictionary]=[]
func _initialize() -> void:
	preload("res://scripts/core/input_bindings.gd").configure()
	call_deferred("run")
func run() -> void:
	for id in ["slope","basin"]:
		for entry in [384.0,512.0]:
			for speed in [280,330,380]:
				for injury in [false,true]:
					await trial(id,entry,speed,injury)
	var file:=FileAccess.open("res://reports/v0.7/terrain-results.json",FileAccess.WRITE)
	var passed:=runs.all(func(r):return r.passed)
	file.store_string(JSON.stringify({"passed":passed,"runs":runs,"method":"headless fixed60, real Player/move_and_slide and polygon bodies across two fixtures; synthetic auto-run, explicit mid-slope injury reduces to280. No position/clock changes during traversal; setup and post-run recovery point inspection are fixtures."},"\t"))
	file.close()
	print(JSON.stringify({"passed":passed,"runs":runs.size(),"failed":runs.filter(func(r):return not r.passed)}))
	quit(0 if passed else 1)
func trial(id: String,entry: float,speed: int,injury: bool) -> void:
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
		var d:=Spatial.build(id,entry if i==0 else 448,448 if i==0 else entry,64,96,i)
		d.category="safe"
		d.difficulty=0
		course._append_chunk({"geometry":d,"index":i,"template_id":"safe_a","stage":0})
	course._sync_geometry()
	var player:=Player.new()
	root.add_child(player)
	player.auto_run=true
	player.health_enabled=true
	player.floor_snap_length=16
	player.floor_constant_speed=true
	player.reset_at(Vector2(96,entry-18))
	player.move_speed=speed
	var safe: Dictionary={}
	var slope_samples:=0
	var max_deviation:=0.0
	var injured:=false
	for frame in 720:
		await physics_frame
		if player.is_on_floor():
			var saved:=course.safe_surface(player.position)
			if not saved.is_empty() and player.position.x>250 and player.position.x<1000:
				safe=saved
				slope_samples+=1
				max_deviation=maxf(max_deviation,absf(player.position.y+15-saved.global_point.y-16))
		if injury and not injured and player.position.x>512:
			player.take_damage("fixture")
			injured=true
		if player.position.x>2416 or player.position.y>650:
			break
	var crossed:=player.position.x>2416 and player.position.y<650
	var safe_ok:=not safe.is_empty() and course.safe_point_exists(safe)
	runs.append({"id":id,"entry":entry,"speed":speed,"injury":injury,"injured":injured,"position":str(player.position),"health":player.health,"safe_samples":slope_samples,"safe_point":str(safe),"feet_deviation":max_deviation,"passed":crossed and safe_ok and slope_samples>20 and (not injury or injured)})
	root.remove_child(player)
	root.remove_child(course)
	player.free()
	course.free()
	await process_frame
