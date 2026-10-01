extends SceneTree
var app: Node2D
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	app = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(app)
	await create_timer(0.15).timeout
	app.start_endless(404)
	await process_frame
	var ticks := Time.get_ticks_usec()
	var before: float = app.elapsed
	await create_timer(2.5).timeout
	var wall := (Time.get_ticks_usec() - ticks) / 1000000.0
	var game: float = app.elapsed - before
	app.toggle_pause()
	var frozen: Array = [app.elapsed, app.player.position, app.chase.front_x, app.run_score]
	await create_timer(0.3).timeout
	var pause_ok := frozen == [app.elapsed, app.player.position, app.chase.front_x, app.run_score]
	app.toggle_pause()
	await create_timer(0.25).timeout
	var passed: bool = absf(wall - game) < 0.25 and pause_ok and app.phase == "running" and app.elapsed > frozen[0]
	var result := {"passed": passed, "wall_seconds": wall, "game_seconds": game, "difference": absf(wall - game), "paused_frozen": pause_ok, "fixed_fps": false, "renderer": RenderingServer.get_video_adapter_name(), "scope": "Normal graphical CLI without fixed-fps; safe initial terrain, real active delta and pause comparison."}
	var file := FileAccess.open("res://reports/v0.6/realtime-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print(JSON.stringify(result))
	app.free()
	OS.delay_msec(200)
	await process_frame
	quit(0 if passed else 1)
