extends SceneTree
## Small independent public-tool workflow; debug injuries are labelled fixtures.
const OUT := "res://reports/v0.5/independent-checks/"
const Profile = preload("res://scripts/level/generation_profile.gd")
const Record = preload("res://scripts/level/endless_record.gd")
var editor: Control
var checks: Array[Dictionary] = []
var snapshots: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")
func frames(n: int) -> void:
	for _i in n:
		await physics_frame
		await process_frame
func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
func tap(code: Key) -> void:
	key(code,true)
	await frames(2)
	key(code,false)
	await frames(2)
func check(label: String, passed: bool, actual: Variant = "") -> void:
	checks.append({"check":label,"passed":passed,"actual":actual})
	print(label,": ",passed)
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
func hash_or_missing(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "missing"
func hashes() -> Dictionary:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://reports/v0.5/version-manifest.json"))
	var result := {}
	for row in manifest.files:
		result[row.path] = hash_or_missing("res://"+row.path)
	return result
func run() -> void:
	print("G_TOOL_PID ",OS.get_process_id())
	var source_before := hashes()
	var record_before := [hash_or_missing(Record.DEFAULT_PATH),hash_or_missing(Record.LEGACY_PATH)]
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(960,540)
	root.size = Vector2i(1280,720)
	editor = load("res://scenes/tools/generation_editor.tscn").instantiate()
	root.add_child(editor)
	await frames(4)
	check("tool_default_v3_and_preview",editor.draft.generator_revision == 3 and editor.preview.visible)
	await shot("tool-preview-1280")
	editor.speed_choice.select(2)
	var play: Button = editor.find_children("Play","Button",true,false)[0]
	play.grab_focus()
	await tap(KEY_ENTER)
	var trial: Node2D = editor.trial
	var path: String = OUT+"isolated-tool-record-%d.json" % OS.get_process_id()
	editor._trial_record = path
	trial.record_path = path
	await frames(30)
	check("actual_Enter_on_Play_installs_330_trial",trial.phase == "running" and trial.trial_speed == 330 and trial.player.health == 3 and trial.player.velocity.x > 320)
	var distance: float = trial.run_distance
	var score: int = trial.run_score
	await tap(KEY_F9)
	snapshots.hurt = {"health":trial.player.health,"target":trial.target_run_speed,"actual":trial.player.velocity.x,"distance":trial.run_distance,"score":trial.run_score,"status":trial._survival_status.presentation_state()}
	check("public_F9_one_life_speed_reset_preserves_score",trial.player.health == 2 and trial.player.hurt_count == 1 and trial.trial_speed == 0 and trial.target_run_speed < 281 and trial.player.velocity.x <= 281 and trial.run_distance >= distance and trial.run_score >= score,snapshots.hurt)
	await shot("tool-hurt-1280")
	await tap(KEY_F9)
	check("invulnerable_F9_does_not_stack_damage",trial.player.health == 2 and trial.player.hurt_count == 1)
	await tap(KEY_ESCAPE)
	var paused_state := [trial.elapsed,trial.run_distance,trial.player.position,trial.chase.front_x,trial._survival_status.presentation_state()]
	await shot("tool-pause-a")
	await frames(20)
	await shot("tool-pause-b")
	check("actual_Escape_freezes_logic_and_hurt",trial.phase == "paused" and paused_state == [trial.elapsed,trial.run_distance,trial.player.position,trial.chase.front_x,trial._survival_status.presentation_state()])
	await tap(KEY_ESCAPE)
	await frames(82)
	check("actual_running_rebuilds_speed_after_debug_injury",trial.phase == "running" and trial.player.health == 2 and trial.target_run_speed > 280.5 and trial.player.velocity.x > 280.5 and trial.player.invulnerable_remaining == 0,{"target":trial.target_run_speed,"actual":trial.player.velocity.x,"distance":trial.run_distance})
	check("actual_landing_created_safe_points",trial.safe_points.size() > 0)
	var front: float = trial.chase.front_x
	var elapsed: float = trial.elapsed
	var before_fall_distance: float = trial.run_distance
	await tap(KEY_F10)
	var recovery_was_active: bool = trial.fall_recovery_remaining > 0
	await frames(18)
	snapshots.recovery = {"health":trial.player.health,"count":trial.player.hurt_count,"phase":trial.phase,"position":trial.player.position,"distance":trial.run_distance,"elapsed":trial.elapsed,"front":trial.chase.front_x,"remaining":trial.fall_recovery_remaining}
	check("public_F10_recovers_to_confirmed_surface",recovery_was_active and trial.phase == "running" and trial.player.health == 1 and trial.player.hurt_count == 2 and trial.fall_recovery_remaining == 0 and trial.player.position.y < 600 and trial.player.control_enabled,snapshots.recovery)
	check("recovery_keeps_clock_front_and_highest_distance",trial.elapsed > elapsed and trial.chase.front_x > front and trial.run_distance >= before_fall_distance and trial.run_distance-before_fall_distance < 50)
	root.size = Vector2i(960,540)
	await frames(2)
	await shot("tool-recovered-960")
	var hint: Control = trial.ui.get_node("EditorReturnHint")
	check("960_status_and_F8_do_not_overlap",not trial._survival_status.get_global_rect().intersects(hint.get_global_rect()) and trial._survival_status.get_global_rect() == Rect2(24,450,380,60))
	# One explicit terminal fixture exercises isolated record writing, not a natural loss.
	trial.player.die("caught")
	await frames(4)
	var isolated_record_hash := hash_or_missing(path)
	check("trial_terminal_saves_only_isolated_record",trial.phase == "failed" and isolated_record_hash != "missing" and trial.endless_record.status == "saved")
	await shot("tool-result-960")
	var draft_before := Profile.fingerprint(editor.draft)
	await tap(KEY_F8)
	check("actual_F8_returns_same_draft_and_removes_trial_record",not is_instance_valid(editor.trial) and editor.chrome.visible and Profile.fingerprint(editor.draft) == draft_before and not FileAccess.file_exists(path))
	await shot("tool-return-960")
	root.remove_child(editor)
	editor.free()
	await frames(8)
	await create_timer(.15).timeout
	var source_after := hashes()
	var record_after := [hash_or_missing(Record.DEFAULT_PATH),hash_or_missing(Record.LEGACY_PATH)]
	check("98_production_sources_and_formal_records_unchanged",source_before == source_after and record_before == record_after)
	var passed: bool = checks.all(func(row):return row.passed)
	var file := FileAccess.open(OUT+"tools-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"snapshots":snapshots,"before":source_before,"after":source_after,"formal_records_before":record_before,"formal_records_after":record_after,"method":"Public editor GUI Play via focused synthetic Enter; actual F9/F10/Esc/F8 via Input.parse_input_event. Public debug injury/fall are labelled fixtures; no natural hazard claim here. Terminal is explicit event fixture. Dedicated writable isolation path, no default/config writes. Two physical window sizes with960logical canvas. No human keyboard/listening claim."},"\t"))
	file.close()
	quit(0 if passed else 1)
