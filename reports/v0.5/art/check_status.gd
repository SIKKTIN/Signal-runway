extends SceneTree
const OUT := "res://reports/v0.5/art/"
var status: Control
var checks: Array[Dictionary] = []

class Stage extends Node2D:
	var cap: Texture2D
	var side: Texture2D
	var sign: Texture2D
	var font: Font
	func _ready() -> void:
		var system := SystemFont.new()
		system.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
		font = system
		for pair in [["cap","platform_cap"],["side","ground_side"],["sign","route_upper"]]:
			var data := Image.load_from_file("res://assets/visual/v05/" + pair[1] + ".svg")
			set(pair[0],ImageTexture.create_from_image(data))
	func _draw() -> void:
		draw_rect(Rect2(0,0,960,540),Color("18212b"))
		for x in range(0,960,64):
			draw_texture_rect(side,Rect2(x,464,64,64),false)
		for x in range(0,960,128):
			draw_texture_rect(cap,Rect2(x,448,128,16),false)
		for rect in [Rect2(260,368,160,16),Rect2(452,320,160,16),Rect2(658,368,160,16)]:
			draw_texture_rect(cap,rect,false)
			draw_texture_rect(side,Rect2(rect.position+Vector2(0,16),Vector2(rect.size.x,32)),false,Color(1,1,1,.7))
		draw_texture_rect(sign,Rect2(264,300,80,28),false)
		draw_string(font,Vector2(352,320),"上路 · 中继",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("ffd166"))
		draw_string(font,Vector2(530,424),"稳路 →",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("9bb5ba"))
		draw_string(font,Vector2(24,35),"v0.5 状态与平台资源样例",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("e6efed"))
		draw_string(font,Vector2(24,63),"仅显示模拟快照；不是实际地形/生命/加速规则验证",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("9bb5ba"))

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for _i in n:
		await physics_frame
		await process_frame

func check(name: String, passed: bool) -> void:
	checks.append({"check":name,"passed":passed})
	print(name, ": ", passed)

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")

func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(960,540)
	root.size = Vector2i(1280,720)
	var stage := Stage.new()
	root.add_child(stage)
	status = load("res://scenes/ui/v05_status.tscn").instantiate()
	root.add_child(status)
	status.update_state(3,280,280,false,0)
	await frames(4)
	check("initial_snapshot_silent_and_readonly",status.presentation_state().hurt_pulses==0 and status.presentation_state().health==3 and not status.enable_hurt_audio)
	await shot("status-full-1280")
	status.update_state(3,350,330,false,0)
	await frames(3)
	check("actual_and_target_distinguished",status.presentation_state().actual_speed==330 and status.presentation_state().target_speed==350 and status.presentation_state().status.contains("加速"))
	await shot("status-accelerating-1280")
	status.update_state(2,280,290,true,1)
	await frames(3)
	for _i in 5:
		status.update_state(2,280,290,true,1)
	check("repeated_snapshot_does_not_repeat_hurt",status.presentation_state().hurt_pulses==1)
	await shot("status-hurt-1280")
	paused = true
	await frames(3)
	var before: Dictionary = status.presentation_state()
	await shot("status-paused-a")
	await frames(20)
	await shot("status-paused-b")
	check("pause_freezes_pulse_and_clock",before.animation_time==status.presentation_state().animation_time and before.hurt_remaining==status.presentation_state().hurt_remaining)
	paused = false
	await frames(45)
	check("hurt_pulse_expires",status.presentation_state().hurt_remaining==0)
	status.update_state(1,380,379,false,2)
	await frames(45)
	await shot("status-low-1280")
	check("low_life_and_max_target_readable",status.presentation_state().health==1 and status.presentation_state().status.contains("最高"))
	status.set_feedback_active(false)
	var clock: float = status.presentation_state().animation_time
	await frames(4)
	check("owner_result_gate_freezes_feedback",status.presentation_state().animation_time==clock)
	status.set_feedback_active(true)
	status.update_state(3,280,280,false,0)
	check("new_round_clears_hurt_history",status.presentation_state().hurt_pulses==0 and status.presentation_state().animation_time==0)
	root.size = Vector2i(960,540)
	status.update_state(2,280,285,true,1)
	await frames(4)
	await shot("status-hurt-960")
	check("logical_bounds_avoid_f8_and_floor",status.get_global_rect()==Rect2(24,450,380,60))
	status.update_state(0,280,0,false,3)
	await frames(3)
	await shot("status-empty-960")
	check("zero_life_stops_nonfatal_feedback",status.presentation_state().hurt_remaining==0)
	root.remove_child(status)
	status.free()
	root.remove_child(stage)
	stage.free()
	await frames(6)
	var file := FileAccess.open(OUT+"status-preparation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":checks.all(func(row):return row.passed),"checks":checks,"scope":"Standalone simulated snapshots and SVG sample; no actual run, physics or gameplay-rule proof.","renderer":RenderingServer.get_video_adapter_name()},"\t"))
	file.close()
	quit(0 if checks.all(func(row):return row.passed) else 1)
