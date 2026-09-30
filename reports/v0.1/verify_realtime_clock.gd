extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var app: Node2D = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	for _i in 5:
		await process_frame
	app.start_challenge(false)
	Input.action_press("move_right")
	await physics_frame
	await physics_frame
	Input.action_release("move_right")
	var start_wall := Time.get_ticks_usec()
	var start_game: float = app.elapsed
	while Time.get_ticks_usec() - start_wall < 3000000:
		await process_frame
	var wall_seconds := (Time.get_ticks_usec() - start_wall) / 1000000.0
	var game_seconds: float = app.elapsed - start_game
	var result := {"wall_seconds":wall_seconds,"game_seconds":game_seconds,"difference_seconds":absf(wall_seconds - game_seconds),"time_scale":Engine.time_scale,"physics_hz":Engine.physics_ticks_per_second,"passed":absf(wall_seconds-game_seconds)<0.10,"launch":"graphical CLI without fixed-fps"}
	var file := FileAccess.open("res://reports/v0.1/realtime-clock.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	print("REALTIME_CLOCK ", JSON.stringify(result))
	app.queue_free()
	await process_frame
	OS.delay_msec(150)
	quit(0 if result.passed else 1)
