extends SceneTree
const Main := preload("res://scenes/main/main.tscn")
const Profile := preload("res://scripts/level/generation_profile.gd")
const OUT := "res://reports/v0.8/art/"
var checks: Array[Dictionary] = []
var runs: Array[Dictionary] = []
var events: Array[Dictionary] = []
var size_tag := ""
var routes_only := false

func _initialize() -> void:
	preload("res://scripts/core/input_bindings.gd").configure()
	call_deferred("run")

func check(label: String, passed: bool, actual: Variant = null) -> void:
	checks.append({"check": label, "passed": passed, "actual": actual})
	print(label + ": " + str(passed))

func frames(count: int) -> void:
	for _i in count:
		await process_frame
		await physics_frame

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + size_tag + "-" + label + ".png")

func make_flow(kind: String) -> Node2D:
	var flow: Node2D = Main.instantiate()
	flow.generation_profile = Profile.defaults()
	flow.dash_prototype_kind = kind
	flow.trial_speed = 380.0
	flow.record_path = OUT + "isolated-e-" + size_tag + ".json"
	root.add_child(flow)
	flow.start_endless(404)
	return flow

func dispose(flow: Node) -> void:
	paused = false
	Input.action_release("jump")
	Input.action_release("dash")
	root.remove_child(flow)
	flow.free()
	await frames(8)
	OS.delay_msec(150)
	for suffix in ["", ".tmp", ".bak"]:
		var path: String = OUT + "isolated-e-" + size_tag + ".json" + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func run() -> void:
	size_tag = str(int(root.size.x))
	routes_only = "--routes" in OS.get_cmdline_user_args()
	if routes_only:
		size_tag += "-route"
	print("ART_CHECK_PID=" + str(OS.get_process_id()))
	for kind in ["shortcut", "relay", "rescue"]:
		await natural(kind)
	if routes_only:
		await offer_fixture()
	else:
		await state_fixtures()
	var passed: bool = checks.all(func(c: Dictionary) -> bool: return bool(c.passed))
	var result := {"passed": passed, "checks": checks, "runs": runs, "events": events,
		"pixel_size": root.size, "godot": Engine.get_version_info().string,
		"renderer": RenderingServer.get_video_adapter_name(),
		"main_sha256": FileAccess.get_sha256("res://scripts/level/run_flow.gd"),
		"method": "Actual Main, seed404, explicit Profile.defaults gen6 / prototype kind / fixed380 and isolated record. Three full prototype routes use synthetic jump/dash from actual geometry windows, no position/chase/time/resource injection during traversal. State fixtures separately call real public Player resource/damage APIs on a new Main. GUI fixed60 accelerated clock; no human fun claim."}
	var file := FileAccess.open(OUT + size_tag + "-skill-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	quit(0 if passed else 1)

func natural(kind: String) -> void:
	var wall_start := Time.get_ticks_msec()
	var flow := make_flow(kind)
	await frames(3)
	var visual: Node2D = flow.world.get_node("DashVisual")
	var hud: Control = flow._dash_status
	var route: Node2D = flow.world.get_node("RouteVisual")
	check(kind + "_main_installed", is_instance_valid(visual) and is_instance_valid(hud) and not is_instance_valid(flow._dash_fallback))
	flow.dash_state_changed.connect(func(snapshot: Dictionary): events.append({"kind": kind, "snapshot": snapshot.duplicate(true), "position": str(flow.player.position)}))
	var held := false
	var held_frames := 0
	var used: Dictionary = {}
	var overlaps := 0
	var landed_overlaps := 0
	var mismatches := 0
	var captured := false
	var pause_done := false
	var offer_frames := 0
	var offer_overlaps := 0
	var offer_truth_errors := 0
	for _frame in 1400:
		await physics_frame
		Input.action_release("dash")
		var player: CharacterBody2D = flow.player
		held_frames += 1
		if held and held_frames >= 4 and (kind == "rescue" or player.velocity.y >= 0):
			Input.action_release("jump")
			held = false
		var at: Vector2 = player.get_global_transform_with_canvas() * Vector2.ZERO
		var hud_rect := Rect2(hud.global_position, hud.size)
		var offer: Dictionary = route.presentation_state().skill_offer
		var offer_rect: Rect2 = route.presentation_state().skill_rect
		if not offer.is_empty():
			offer_frames += 1
			if offer_rect.intersects(Rect2(at-Vector2(10,15),Vector2(20,30))):
				offer_overlaps += 1
			if bool(offer.available) != (int(offer.charges)>=int(offer.required)):
				offer_truth_errors += 1
		if hud.visible and hud_rect.intersects(Rect2(at - Vector2(10, 15), Vector2(20, 30))):
			overlaps += 1
		if int(hud.presentation_state().snapshot.get("charges", -1)) != player.dash_charges:
			mismatches += 1
		for chunk in flow.course.chunks:
			var d: Dictionary = chunk.geometry
			var x: float = player.position.x - chunk.origin
			if player.is_on_floor() and not held:
				for w in d.jump_windows:
					var a: Vector2 = w.from
					var lead := 4.0 if w.kind == "skill" else (24.0 if w.to.x > a.x + 8 else 60.0)
					if x >= a.x - lead and x < a.x + 12 and absf(player.position.y + 15 - a.y) < 7:
						Input.action_press("jump")
						held = true
						held_frames = 0
						var landing: Vector2 = flow.course.get_global_transform_with_canvas() * (w.to + Vector2(chunk.origin, 0))
						if hud_rect.intersects(Rect2(landing, Vector2(float(w.get("landing_width", 20)), 3))):
							landed_overlaps += 1
						if not offer.is_empty() and offer_rect.intersects(Rect2(landing,Vector2(20,3))):
							offer_overlaps += 1
						break
			if d.has("skill"):
				for j in d.skill.dash_windows.size():
					var w: Dictionary = d.skill.dash_windows[j]
					var key := str(chunk.index) + ":" + str(j)
					if not used.has(key) and x >= w.dash_x and x < w.to.x and not player.is_on_floor() and player.dash_charges > 0 and not player.dash_active:
						Input.action_press("dash")
						used[key] = true
		if player.dash_active and visual.presentation_state().trace_count >= 2 and not captured:
			await shot(kind + "-dash")
			captured = true
		if kind == "shortcut" and player.dash_active and not pause_done and captured:
			flow.toggle_pause()
			await frames(3)
			var before_v: String = JSON.stringify(visual.presentation_state())
			var before_h: String = JSON.stringify(hud.presentation_state())
			var before_remaining: float = player.dash_remaining
			await shot("pause-before")
			await frames(12)
			await shot("pause-after")
			check("pause_dash_frozen", before_v == JSON.stringify(visual.presentation_state()) and before_h == JSON.stringify(hud.presentation_state()) and before_remaining == player.dash_remaining)
			flow.toggle_pause()
			pause_done = true
		if flow.phase not in ["running", "ready"]:
			break
	await frames(2)
	var row := {"kind": kind, "health": flow.player.health, "phase": flow.phase, "dash": flow.player.dash_snapshot(),
		"overlap_frames": overlaps, "landing_overlaps": landed_overlaps, "resource_mismatch_frames": mismatches,
		"captured": captured, "game_seconds": flow.elapsed, "wall_seconds": float(Time.get_ticks_msec() - wall_start) / 1000.0}
	runs.append(row)
	check(kind + "_actual_route", flow.phase == "prototype_done" and flow.player.health == 3 and flow.player.dash_used > 0, row)
	check(kind + "_visible_readable", overlaps == 0 and landed_overlaps == 0 and captured)
	if routes_only:
		check(kind+"_offer_readable_truth", offer_frames>0 and offer_overlaps==0 and offer_truth_errors==0,{"offer_frames":offer_frames,"overlaps":offer_overlaps,"truth_errors":offer_truth_errors})
	# The UI _process runs after physics: permit one frame per real resource event.
	check(kind + "_resource_matches", mismatches <= flow.player.dash_used + flow.player.dash_refilled)
	check(kind + "_terminal_cleans", not hud.visible and visual.presentation_state().trace_count == 0)
	flow.restart_challenge()
	await frames(3)
	check(kind + "_retry_single_hud", flow.ui.get_children().filter(func(c: Node) -> bool: return c.get_script() == preload("res://scenes/ui/v08_dash_status.gd")).size() == 1 and int(flow._dash_status.presentation_state().snapshot.charges) == 1)
	await dispose(flow)

func offer_fixture() -> void:
	var flow := make_flow("relay")
	var route: Node2D = flow.world.get_node("RouteVisual")
	for _i in 200:
		await physics_frame
		if flow.player.position.x>=1080:
			break
	await frames(2)
	var s: Dictionary = flow.current_skill_offer()
	check("relay_budget_same_source", s.required==1 and s.dash_cost==2 and s.expected_refill==1)
	check("offer_card_avoids_existing_hud", not Rect2(270,128,390,58).intersects(Rect2(24,128,230,40)) and not Rect2(270,128,390,58).intersects(Rect2(690,142,246,94)))
	flow.player.try_dash()
	await frames(16)
	var lines: Array = route.presentation_state().skill_lines
	check("insufficient_main_hint", lines[0].contains("冲刺不足") and lines[0].contains("走主路"))
	check("refill_capacity_qualified", lines[1].contains("容量允许"))
	check("offer_text_fits", route._font.get_string_size(lines[0],HORIZONTAL_ALIGNMENT_LEFT,-1,14).x<=370 and route._font.get_string_size(lines[1],HORIZONTAL_ALIGNMENT_LEFT,-1,12).x<=370)
	await shot("insufficient")
	flow.player.charge_dash("art:offer:first")
	flow.player.charge_dash("art:offer:second")
	await frames(2)
	check("resource_updates_offer", flow.current_skill_offer().available and route.presentation_state().skill_lines[0].contains("入口需 1 次"))
	await shot("available")
	flow.toggle_pause()
	await frames(3)
	var frozen: String = JSON.stringify(route.presentation_state())
	await frames(10)
	check("route_pause_frozen", frozen==JSON.stringify(route.presentation_state()))
	flow.toggle_pause()
	await dispose(flow)

func state_fixtures() -> void:
	var flow := make_flow("shortcut")
	await frames(3)
	var hud: Control = flow._dash_status
	var player: CharacterBody2D = flow.player
	var visual: Node2D = flow.world.get_node("DashVisual")
	player.charge_dash("art:fixture:one")
	await frames(2)
	check("one_unique_node_progress", hud.presentation_state().detail == "充能 1/2 节点")
	await shot("charging")
	player.charge_dash("art:fixture:two")
	await frames(2)
	check("refill_once", hud.presentation_state().refill_cues == 1 and hud.presentation_state().snapshot.charges == 2)
	await shot("refilled")
	player.charge_dash("art:fixture:two")
	player.charge_dash("art:fixture:three")
	await frames(55)
	check("full_no_repeated_cue", hud.presentation_state().refill_cues == 1 and hud.presentation_state().detail == "储备已满")
	await shot("full")
	player.try_dash()
	await frames(16)
	player.try_dash()
	await frames(16)
	player.try_dash()
	await frames(2)
	check("empty_visible", hud.presentation_state().snapshot.charges == 0 and hud.presentation_state().detail.begins_with("冲刺耗尽"))
	check("detail_fits", hud._font.get_string_size(hud.presentation_state().detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x <= hud.size.x - 20)
	await shot("empty")
	player.charge_dash("art:fixture:four")
	player.charge_dash("art:fixture:five")
	player.try_dash()
	await frames(3)
	player.take_damage("art_fixture")
	await frames(2)
	check("hurt_clears_trace", visual.presentation_state().trace_count == 0 and not player.dash_active and player.dash_charges == 0)
	flow.return_to_menu()
	await frames(3)
	check("menu_cleans", not hud.visible and visual.presentation_state().trace_count == 0)
	flow.start_challenge(false, "time_trial", "level01")
	await frames(3)
	check("old_mode_silent", not flow.player.dash_enabled and not is_instance_valid(flow._dash_status) and not flow.world.has_node("DashVisual"))
	await dispose(flow)
