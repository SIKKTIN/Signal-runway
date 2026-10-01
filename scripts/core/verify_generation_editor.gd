extends SceneTree
const Profile = preload("res://scripts/level/generation_profile.gd")
const Generator = preload("res://scripts/level/endless_generator.gd")
const Legacy = preload("res://reports/v0.4.1/legacy_generator.gd")
const Editor = preload("res://scripts/tools/generation_editor.gd")
var checks: Array[Dictionary] = []
func _initialize() -> void:
	call_deferred("run")
func check(title: String, passed: bool) -> void:
	checks.append({"check": title, "passed": passed})
	print(title, ": ", passed)
func run() -> void:
	var base := Profile.defaults()
	check("built_in_and_project_default_valid", Profile.validate(base).is_empty() and Profile.load_profile().profile == base)
	var order := {}
	var keys := base.keys()
	keys.reverse()
	for key in keys:
		order[key] = base[key]
	check("field_order_stable_fingerprint", Profile.fingerprint(base) == Profile.fingerprint(order))
	var invalids: Array = [null, [], {}, {"schema": 1}]
	for key in ["stage_distance", "relay_min", "relay_max"]:
		var bad := base.duplicate(true)
		bad[key] = "bad"
		invalids.append(bad)
	for pair in [["stage_distance", INF], ["stage_distance", 0], ["relay_min", 3], ["relay_max", 9], ["relay_min", 5.5]]:
		var bad := base.duplicate(true)
		bad[pair[0]] = pair[1]
		invalids.append(bad)
	var unknown := base.duplicate(true)
	unknown.templates.extra = {"enabled": true, "weight": 1}
	invalids.append(unknown)
	for id in Profile.LOCKED:
		var bad := base.duplicate(true)
		bad.templates[id].enabled = false
		invalids.append(bad)
	var all_rejected := true
	for bad in invalids:
		all_rejected = all_rejected and not Profile.validate(bad).is_empty()
	check("invalid_types_ranges_nonfinite_ids_and_locked_rejected", all_rejected)
	var custom := base.duplicate(true)
	custom.stage_distance = 4200
	custom.relay_min = 4
	custom.relay_max = 8
	custom.templates.spike.weight = 10
	custom.templates.wall_b.enabled = false
	var equivalent := true
	var valid_sequences := true
	var spike_base := 0
	var spike_weighted := 0
	for seed_value in 100:
		var old := Legacy.new()
		var normal := Generator.new()
		var weighted := Generator.new()
		old.reset(seed_value)
		normal.reset(seed_value, base)
		weighted.reset(seed_value, custom)
		var sequence: Array[Dictionary] = []
		for _i in 200:
			var row := normal.next()
			var selected := weighted.next()
			sequence.append(selected)
			equivalent = equivalent and old.next().template_id == row.template_id
			spike_base += int(row.template_id == "spike")
			spike_weighted += int(selected.template_id == "spike")
			valid_sequences = valid_sequences and selected.template_id != "wall_b" and (selected.template_id in selected.candidates or selected.index < 2)
		valid_sequences = valid_sequences and Editor.sequence_errors(sequence, custom).is_empty() and sequence[4].category == "relay"
	check("100_seed_200_default_legacy_sequences_identical", equivalent)
	check("100_seed_200_custom_constraints_and_disabled_filter", valid_sequences)
	check("higher_weight_changes_actual_eligible_distribution", spike_weighted > spike_base * 1.3)
	var a := Generator.new()
	var b := Generator.new()
	a.reset(77, custom)
	b.reset(77, custom)
	var deterministic := true
	for _i in 60:
		randf()
		deterministic = deterministic and a.next() == b.next()
	check("custom_seed_unrelated_rng_and_diagnostics_read_only", deterministic)
	var path := "user://editor_verify_%d.json" % OS.get_process_id()
	check("save_load_atomic_profile", Profile.save_profile(base, path).ok and Profile.save_profile(custom, path).ok and Profile.load_profile(path).profile == Profile.normalized(custom))
	check("backup_retains_previous_valid_profile", Profile.load_profile(path + ".bak").profile == base)
	check("invalid_save_preserves_previous_file", not Profile.save_profile({}, path).ok and Profile.load_profile(path).profile == Profile.normalized(custom))
	check("write_failure_reported", not Profile.save_profile(base, "user://missing_editor_folder_%d/file.json" % OS.get_process_id()).ok)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{bad")
	file.close()
	check("corrupt_missing_safe_visible_fallback", Profile.load_profile(path).fallback and Profile.load_profile(path + ".missing").fallback)
	var app: Node2D = load("res://scenes/main/main.tscn").instantiate()
	app.generation_profile = custom.duplicate(true)
	app.record_path = "user://editor_verify_trial_%d.json" % OS.get_process_id()
	root.add_child(app)
	await process_frame
	app.start_endless(404)
	app.set_physics_process(false)
	app.player.set_physics_process(false)
	app.course.update_stream(22000, -544)
	var generator := Generator.new()
	generator.reset(404, custom)
	var prefix_match := true
	for chunk in app.course.chunks:
		prefix_match = prefix_match and chunk.template_id == generator.next().template_id
	check("real_course_preview_custom_prefix_identical", prefix_match and app.course.chunks.size() >= 20)
	custom.templates.spike.weight = 2
	check("running_course_profile_is_snapshot", app.course.generation_profile.templates.spike.weight == 10)
	app.restart_challenge()
	check("same_seed_retry_keeps_round_profile", app.run_seed == 404 and app.course.generation_profile.templates.spike.weight == 10)
	app.start_challenge(false, "pursuit", "level01")
	check("fixed_level_manual_and_goal_compatible", not app.player.auto_run and app.course.get_node_or_null("Goal") != null)
	app.free()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	var passed := checks.all(func(c): return c.passed)
	var result := {"passed": passed, "checks": checks, "invalid_samples": invalids.size(), "default_spikes": spike_base, "weighted_spikes": spike_weighted, "scope": "100x200 frozen v0.4 IDs compared; configuration structural constraints and file lifecycle; explicit main prefix fixture, not long-route pressure evidence"}
	file = FileAccess.open("res://reports/v0.4.1/profile-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	OS.delay_msec(100)
	await process_frame
	quit(0 if passed else 1)
