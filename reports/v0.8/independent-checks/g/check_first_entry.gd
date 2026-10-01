extends "res://reports/v0.8/independent-checks/check_tools.gd"
const OUT_G := "res://reports/v0.8/independent-checks/g/"
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT_G+label+".png")

func run() -> void:
	print("V08_F_RESCUE_PID=",OS.get_process_id())
	var before := hashes()
	var records_before := records()
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(960,540)
	root.size = Vector2i(960,540)
	editor = load("res://scenes/tools/generation_editor.tscn").instantiate()
	editor.replay_path = OUT_G+"unused-rescue-fixture.json"
	root.add_child(editor)
	await frames(3)
	await press("Prototypes")
	var hub: Control = editor.prototype_view
	var button: Button = hub.find_children("Rescue","Button",true,false)[0]
	button.grab_focus()
	await tap(KEY_ENTER)
	var flow: Node2D = hub.trial
	var record := OUT_G+"isolated-rescue.json"
	flow.record_path = record
	check("public_rescue_main",flow.course.skill_prototype=="rescue" and flow.player.dash_enabled and hub.resource_choice.get_selected_id()==1 and hub.speed_choice.get_selected_id()==280)
	var jump_pressed := false
	var jump_frames := 0
	var dash_pressed := false
	var before_dash: Dictionary = {}
	var landed := false
	for _i in 700:
		await frames(1)
		if jump_pressed:
			jump_frames += 1
			if jump_frames>=4:
				key(KEY_SPACE,false)
		key(KEY_SHIFT,false)
		for chunk in flow.course.chunks:
			if not chunk.geometry.has("skill"):
				continue
			var x: float = flow.player.position.x-chunk.origin
			if not jump_pressed and flow.player.is_on_floor() and x>=456 and x<480:
				key(KEY_SPACE,true)
				jump_pressed = true
			if jump_pressed and not dash_pressed and x>=528 and x<608 and not flow.player.is_on_floor():
				before_dash = {"x":x,"feet":flow.player.position.y+15,"velocity":str(flow.player.velocity),"dash":flow.player.dash_snapshot()}
				key(KEY_SHIFT,true)
				dash_pressed = true
			if dash_pressed and x>640 and flow.player.is_on_floor():
				landed = true
		if landed or flow.phase not in ["running","ready"]:
			break
	key(KEY_SPACE,false)
	key(KEY_SHIFT,false)
	check("short_jump_rescued_real_landing",jump_pressed and dash_pressed and landed and flow.player.health==3 and flow.player.hurt_count==0,before_dash)
	check("spent_one_retains_one",flow.player.dash_used==1 and flow.player.dash_refilled==1 and flow.player.dash_charges==1,flow.player.dash_snapshot())
	await shot("public-rescue-landing")
	await tap(KEY_F8)
	check("actual_F8_returns_prototype_hub",not is_instance_valid(hub.trial) and hub.chrome.visible)
	await tap(KEY_F8)
	check("actual_second_F8_returns_editor",not is_instance_valid(editor.prototype_view) and editor.chrome.visible)
	root.remove_child(editor)
	editor.free()
	await frames(8)
	OS.delay_msec(150)
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(record+suffix):
			DirAccess.remove_absolute(record+suffix)
	check("118_and_formal_unchanged",before==hashes() and frozen_matches(hashes()) and records_before==records())
	var passed: bool = checks.all(func(row: Dictionary) -> bool:return row.passed)
	var file := FileAccess.open(OUT_G+"rescue-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"before_dash":before_dash,"method":"Actual public editor Prototypes and Rescue buttons via synthetic Enter; explicit tool default initial1/fixed280, isolated score destination. Short SPACE4-frame release then Shift at real x528; real landing aftergap with health3 and one resource retained. Public tool fixture, not a seventh natural default run; no position/front/elapsed injection. GUI fixed60 accelerated. No human fun claim."},"\t"))
	file.close()
	quit(0 if passed else 1)
