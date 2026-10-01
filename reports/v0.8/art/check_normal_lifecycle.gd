extends SceneTree
var checks: Array[Dictionary] = []
func _initialize() -> void:
	call_deferred("run")
func check(label: String, passed: bool) -> void:
	checks.append({"check":label,"passed":passed})
	print(label+": "+str(passed))
func run() -> void:
	print("ART_NORMAL_PID="+str(OS.get_process_id()))
	var flow: Node2D = load("res://scenes/main/main.tscn").instantiate()
	flow.record_path = "res://reports/v0.8/art/isolated-normal.json"
	root.add_child(flow)
	flow.start_endless(404)
	await create_timer(0.1).timeout
	check("actual_default_gen6", flow.generation_profile.generator_revision==6 and flow.player.dash_enabled)
	Input.action_press("dash")
	await create_timer(0.055).timeout
	Input.action_release("dash")
	var visual: Node2D = flow.world.get_node("DashVisual")
	check("normal_clock_start_cue", flow.player.dash_active and visual._cue.playing and visual._cue.get_playback_position()>0.0)
	await create_timer(0.23).timeout
	check("normal_clock_dash_ends", not flow.player.dash_active)
	# Explicit public-node API fixture for the refill sound; not natural collection.
	flow.player.charge_dash("art:normal:first")
	flow.player.charge_dash("art:normal:second")
	await create_timer(0.055).timeout
	check("normal_clock_refill_cue", flow._dash_status._cue.playing and flow._dash_status._cue.get_playback_position()>0.0)
	await create_timer(0.23).timeout
	flow.return_to_menu()
	await create_timer(0.1).timeout
	root.remove_child(flow)
	flow.free()
	await create_timer(0.25).timeout
	var result := {"passed":checks.all(func(c: Dictionary) -> bool:return bool(c.passed)),"checks":checks,"method":"Actual default Main gen6, seed404, normal GPU clock (no fixed-fps). Synthetic dash press; explicit unique-node public API refill fixture. Audio playback state/position, not human listening or general leak proof."}
	var file := FileAccess.open("res://reports/v0.8/art/normal-lifecycle-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	file.close()
	for suffix in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists("res://reports/v0.8/art/isolated-normal.json"+suffix):
			DirAccess.remove_absolute("res://reports/v0.8/art/isolated-normal.json"+suffix)
	quit(0 if result.passed else 1)
