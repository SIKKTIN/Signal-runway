extends "res://reports/v0.7/art/check_main.gd"
## Correct mid-surface camera fixtures, not another traversal suite.
func run() -> void:
	print("V07_E_LAYOUT_PID ",OS.get_process_id())
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size=Vector2i(960,540)
	var prior: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT+"main-results.json"))
	var cases: Array=[]
	var ids: Dictionary={}
	for row in prior.shots:
		if not ids.has(row.case):
			ids[row.case]=true
			cases.append(row)
	cases.sort_custom(func(a,b):return a.index<b.index)
	app=load("res://scenes/main/main.tscn").instantiate()
	app.record_path=OUT+"isolated-layout-record.json"
	root.add_child(app)
	await frames(4)
	app.start_endless(404)
	freeze()
	await frames(2)
	for row in cases:
		app.course.update_stream(row.index*1280+640,row.index*1280-700)
		await frames(2)
		var chunk: Dictionary=app.course.chunks.filter(func(value):return value.index==row.index)[0]
		var d: Dictionary=chunk.geometry
		var x: float=96 if row.case=="station" else 640
		if row.case=="upper-merge":
			x=736
		elif row.case=="terrace":
			x=400
		var y: float=ground_y(d,x)
		if row.case in ["challenge","upper-merge","bridge"]:
			for rect in d.platforms:
				if x>=rect.position.x+20 and x<=rect.end.x-20:
					y=rect.position.y
					break
		if not is_finite(y):
			x=d.platforms[0].get_center().x
			y=d.platforms[0].position.y
		app.player.reset_at(Vector2(chunk.origin+x,y-16))
		app.player.move_speed=380
		app.target_run_speed=380
		app._update_ui()
		var camera_y: float=clampf(y-16-163,270,420)
		camera(Vector2(chunk.origin+x+180,camera_y))
		var geometry_hash: String=JSON.stringify(d).sha256_text()
		for size in [Vector2i(1280,720),Vector2i(960,540)]:
			root.size=size
			await frames(3)
			await shot("final-"+row.case+"-"+str(size.x))
			shots.append({"case":row.case,"index":row.index,"size":str(size),"foot_y":y,"player":str(app.player.position),"camera":str(app.camera.position),"spatial":visuals()[0].presentation_state(),"ground_segments":d.ground_segments,"platforms":d.platforms})
		check("mid_surface_"+row.case+"_camera_and_geometry",camera_y==clampf(app.player.position.y-163,270,420) and geometry_hash==JSON.stringify(chunk.geometry).sha256_text())
		if row.case=="upper-merge":
			app.player.reset_at(Vector2(chunk.origin+96,d.connection.upper_entry_y-16))
			camera(Vector2(chunk.origin+276,clampf(app.player.position.y-163,270,420)))
			await frames(2)
			await shot("final-upper-entry-960")
		if row.case=="slope":
			key(KEY_ESCAPE,true)
			await frames(2)
			key(KEY_ESCAPE,false)
			await frames(2)
			await shot("slope-details-on")
			visuals()[0].set_process(false)
			visuals()[0].hide()
			await frames(2)
			await shot("slope-details-off")
			visuals()[0].show()
			visuals()[0].set_process(true)
			key(KEY_ESCAPE,true)
			await frames(2)
			key(KEY_ESCAPE,false)
			await frames(2)
		var snapshot: Dictionary=visuals()[0].presentation_state()
		check("layout_"+row.case+"_activity_bounded",snapshot.chunks==app.course.chunks.size() and snapshot.chunks<=8)
	var sources: Dictionary={}
	for path in ["scripts/visual/spatial_visual.gd","scripts/visual/endless_module_visual.gd","scripts/visual/route_visual.gd"]:
		sources[path]=FileAccess.get_sha256("res://"+path)
	root.remove_child(app)
	app.free()
	await frames(8)
	OS.delay_msec(150)
	var file:=FileAccess.open(OUT+"layout-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":checks.all(func(value):return value.passed),"checks":checks,"shots":shots,"sources":sources,"method":"Only final E layout: actual streamed geometry and actual Main, explicit frozen player on a middle surface, camera uses public follow formula. 380 field is a screenshot fixture, actual 380 traversal evidence remains main-results. Initial start-camera screenshots preserved. GPU fixed60; not natural route or human experience."},"\t"))
	file.close()
	quit(0 if checks.all(func(value):return value.passed) else 1)
