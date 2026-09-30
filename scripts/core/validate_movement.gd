extends SceneTree

var checks: Array[Dictionary] = []
var room: Node2D
var player: CharacterBody2D

func _initialize() -> void:
	call_deferred("_run")

func frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame

func check(label: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"check": label, "passed": passed, "detail": detail})
	print(label, ": ", passed, " ", detail)

func clear_input() -> void:
	for action in ["move_left", "move_right", "jump", "restart"]:
		Input.action_release(action)

func _run() -> void:
	room = load("res://scenes/test_room/test_room.tscn").instantiate()
	root.add_child(room)
	await frames(12)
	player = room.player
	Input.action_press("move_right")
	await frames(20)
	check("horizontal_speed", absf(player.velocity.x - 280.0) < 1.0, player.velocity.x)
	Input.action_release("move_right")
	await frames(12)
	check("ground_stop", absf(player.velocity.x) < 1.0, player.velocity.x)
	player.reset_at(Vector2(80, 430))
	await frames(5)
	var base := player.position.y
	Input.action_press("jump")
	var full_apex := base
	for _i in 50:
		await frames(1)
		full_apex = minf(full_apex, player.position.y)
	Input.action_release("jump")
	await frames(5)
	check("full_jump_height", base - full_apex > 85.0 and base - full_apex < 105.0, base - full_apex)
	check("no_held_autojump", player.is_on_floor(), player.position)
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	var short_apex := base
	for _i in 50:
		await frames(1)
		short_apex = minf(short_apex, player.position.y)
	check("variable_jump", base - short_apex < (base - full_apex) * 0.65, base - short_apex)
	# Leave an actual platform edge and jump within the coyote window.
	player.reset_at(Vector2(510, 430))
	await frames(5)
	Input.action_press("move_right")
	var left_floor := false
	for _i in 20:
		await frames(1)
		if not player.is_on_floor():
			left_floor = true
			break
	Input.action_press("jump")
	await frames(1)
	check("coyote_jump", left_floor and player.velocity.y < -400.0, player.velocity)
	clear_input()
	# Queue a jump just before the real floor contact.
	player.reset_at(Vector2(80, 370))
	player.velocity.y = 350.0
	await frames(6)
	Input.action_press("jump")
	var buffered := false
	for _i in 12:
		await frames(1)
		buffered = buffered or player.velocity.y < -400.0
	check("landing_buffer", buffered, player.velocity)
	clear_input()
	# Contact the wall and consume one side's jump opportunity.
	player.reset_at(Vector2(718, 340))
	Input.action_press("move_right")
	await frames(8)
	check("wall_slide", player.is_on_wall() and player.velocity.y <= 90.1, player.velocity)
	Input.action_press("jump")
	await frames(1)
	check("wall_jump", player.velocity.x < 0.0 and player.velocity.y < -400.0, player.velocity)
	Input.action_release("jump")
	await frames(1)
	# Put the body back against the same side without grounding: it must not jump again.
	player.position = Vector2(718, 340)
	player.velocity = Vector2(30, 20)
	await frames(5)
	Input.action_press("jump")
	await frames(1)
	check("same_wall_lock", player.velocity.y >= 0.0, player.velocity)
	clear_input()
	for i in 20:
		player.reset_at(Vector2(432, 428))
		await frames(3)
		await frames(20)
		if player.dead:
			check("recovery_" + str(i), false)
	check("20_hazard_recoveries", room.death_count >= 20 and not player.dead, room.death_count)
	check("recovery_velocity", player.velocity.length() < 1.0, player.velocity)
	var success := checks.all(func(c): return c.passed)
	var report := {"suite": "movement", "godot": Engine.get_version_info().string, "checks": checks, "passed": success}
	DirAccess.make_dir_recursive_absolute("res://reports/v0.1")
	var file := FileAccess.open("res://reports/v0.1/movement-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	quit(0 if success else 1)
