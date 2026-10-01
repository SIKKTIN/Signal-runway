extends "res://reports/v0.8/independent-checks/check_routes.gd"
func run() -> void:
	print("V08_F_OVERLAP_PID=",OS.get_process_id())
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(960,540)
	root.size = Vector2i(960,540)
	route_choice = "skill"
	app = load("res://scenes/main/main.tscn").instantiate()
	app.record_path = OUT8+"isolated-overlap.json"
	root.add_child(app)
	app.start_endless(77)
	var observations: Array[Dictionary] = []
	for _i in 6500:
		step_input()
		await frames(1)
		var route: Node2D = app.world.get_node("RouteVisual")
		var state: Dictionary = route.presentation_state()
		var at: Vector2 = app.player.get_global_transform_with_canvas()*Vector2.ZERO
		var body := Rect2(at-Vector2(10,15),Vector2(20,30))
		if not state.skill_offer.is_empty() and state.skill_rect.intersects(body):
			app.toggle_pause()
			app.ui.show_playing()
			await frames(3)
			observations.append({"elapsed":app.elapsed,"global_x":app.player.position.x+app.course.total_offset,"body":str(body),"body_x":body.position.x,"body_y":body.position.y,"body_width":body.size.x,"body_height":body.size.y,"card":str(state.skill_rect),"offer":state.skill_offer,"health":app.player.health,"hurt_count":app.player.hurt_count,"player_position":str(app.player.position),"dash":app.player.dash_snapshot(),"camera":str(app.camera.position)})
			await shot("defect-77-card-overlap")
			# Disclosed frozen visual control: remove only the card, keep other marks.
			route.set_process(false)
			route._skill_offer.clear()
			route.queue_redraw()
			await shot("defect-77-without-card")
			break
		if app.phase!="running":
			break
	var file := FileAccess.open(OUT8+"overlap-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"reproduced":not observations.is_empty(),"observations":observations,"method":"Same independent skill key planner, default Main seed77, no motion/resource/speed injection. Stop at first real intersection with public pause and hide pause overlay; card removal only is a frozen visual control. Screenshot uses paused same character transform. Not a new complete station sample."},"\t"))
	file.close()
	paused = false
	released()
	key(KEY_SHIFT,false)
	root.remove_child(app)
	app.free()
	await frames(8)
	OS.delay_msec(150)
	quit(0 if not observations.is_empty() else 1)
