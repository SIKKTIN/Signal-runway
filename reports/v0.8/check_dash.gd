extends SceneTree
const Player=preload("res://scripts/player/player.gd")
var results: Array[Dictionary]=[]
func _initialize() -> void:
	preload("res://scripts/core/input_bindings.gd").configure()
	call_deferred("run")
func run() -> void:
	for speed in [280,330,380]:
		for air in [false,true]:
			await motion(speed,air)
	await motion(330,false,true)
	var file:=FileAccess.open("res://reports/v0.8/dash-motion-results.json",FileAccess.WRITE)
	var passed:=results.all(func(r):return r.passed)
	file.store_string(JSON.stringify({"passed":passed,"results":results,"method":"Actual CharacterBody2D/solid fixtures, synthetic held Shift/Space, fixed60 headless; explicit initial speed/floor/wall, pause and injury fixtures. Dash duration/real distance/gravity, held input, no penetration and no refund are measured."},"\t"))
	file.close()
	print(JSON.stringify({"passed":passed,"results":results}))
	quit(0 if passed else 1)
func solid(owner: Node,rect: Rect2) -> void:
	var body:=StaticBody2D.new()
	body.position=rect.get_center()
	var shape:=CollisionShape2D.new()
	var geometry:=RectangleShape2D.new()
	geometry.size=rect.size
	shape.shape=geometry
	body.add_child(shape)
	owner.add_child(body)
func motion(speed: int,air: bool,wall: bool=false) -> void:
	var level:=Node2D.new()
	root.add_child(level)
	solid(level,Rect2(-200,448,5000,200))
	var p:=Player.new()
	level.add_child(p)
	p.auto_run=true
	p.health_enabled=true
	p.dash_enabled=true
	p.move_speed=speed
	p.reset_at(Vector2(96,430))
	for _i in 30:
		await physics_frame
	if air:
		Input.action_press("jump")
		for _i in 6:
			await physics_frame
	if wall:
		solid(level,Rect2(p.position.x+64,0,32,448))
		await physics_frame
	var start:=p.position
	var vy:=p.velocity.y
	Input.action_press("dash")
	var frames:=0
	for _i in 12:
		await physics_frame
		frames+=1
	await physics_frame
	var delta:=p.position.x-start.x
	var active_end:=p.dash_active
	var before_pause:=p.dash_snapshot()
	paused=true
	for _i in 4:
		await physics_frame
	var pause_ok:=p.dash_snapshot()==before_pause and not p.try_dash()
	paused=false
	for _i in 18:
		await physics_frame
	var held_ok:=p.dash_used==1 and p.dash_charges==0
	Input.action_release("dash")
	Input.action_release("jump")
	p.dash_charges=1
	p.try_dash()
	await physics_frame
	p.take_damage("fixture")
	var hurt_ok:=not p.dash_active and p.dash_charges==0 and p.move_speed==280 and p.health==2
	var distance_ok: bool=delta>=150 and delta<=175 if not wall else delta<=55
	results.append({"speed":speed,"air":air,"wall":wall,"distance":delta,"initial_vy":vy,"end_active":active_end,"pause":pause_ok,"held_once":held_ok,"hurt_cancel":hurt_ok,"passed":distance_ok and not active_end and held_ok and pause_ok and hurt_ok})
	root.remove_child(level)
	level.free()
	await process_frame
