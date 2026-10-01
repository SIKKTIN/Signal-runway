extends SceneTree
const Profile=preload("res://scripts/level/generation_profile.gd")
const Record=preload("res://scripts/level/endless_record.gd")
const Replay=preload("res://scripts/tools/generation_replay.gd")
const Main=preload("res://scenes/main/main.tscn")
var checks: Array[Dictionary]=[]
func _initialize() -> void:
	call_deferred("run")
func check(name: String,ok: bool) -> void:
	checks.append({"check":name,"passed":ok})
func run() -> void:
	var old:={}
	for p in [Record.DEFAULT_PATH,Record.V07_PATH,Record.V06_PATH,Record.V05_PATH,Record.LEGACY_PATH,Replay.DEFAULT_PATH,Replay.V07_PATH]:
		old[p]=FileAccess.get_sha256(p) if FileAccess.file_exists(p) else "missing"
	var path:="res://reports/v0.8/isolated-compat.json"
	var profile:=Profile.defaults()
	check("default_config6_valid",not Profile.load_profile().fallback and Profile.validate(Profile.load_profile().profile).is_empty() and Profile.load_profile().profile.generator_revision==6)
	var bad:=profile.duplicate(true)
	bad.dash_speed=760
	check("unverified_dash_numbers_rejected",not Profile.validate(bad).is_empty())
	var record:=Record.new()
	record.expected_rules_revision=8
	var metadata:={"rules_revision":8,"generator_revision":6,"profile_fingerprint":Profile.fingerprint(profile),"score_breakdown":{"distance":100,"nodes":100,"combo":200,"station":200}}
	check("v08_atomic_save",record.consider(path,600,1000,1,404,metadata) and record.status=="saved")
	var loaded:=Record.new()
	loaded.expected_rules_revision=8
	loaded.load_from(path)
	check("v08_reloads",loaded.status=="loaded" and loaded.best.score==600)
	check("low_score_preserves_best",not loaded.consider(path,500,2000,2,77,metadata))
	metadata.generator_revision=5
	record.consider(path,700,1000,1,404,metadata)
	loaded.load_from(path)
	check("rules8_old_generator_rejected",loaded.status=="invalid")
	var failure:=Replay.make(77,profile,256800,"fall",{"charges":0,"progress":1})
	check("failure_snapshot_schema2",failure.schema==2 and Replay.validate(failure).is_empty())
	check("failure_atomic_save",Replay.save(failure,path).ok)
	var restored:=Replay.load_from(path)
	check("failure_snapshot_roundtrip",restored.ok and restored.value.dash.charges==0 and restored.value.dash.progress==1 and restored.value.failed_x==256800)
	failure.dash.charges=3
	check("bad_snapshot_rejected",not Replay.validate(failure).is_empty())
	check("legacy_failure_schema1",Replay.validate(Replay.make(404,Profile.v07_defaults(),1234,"fall")).is_empty())
	for cfg in [Profile.legacy_defaults(),Profile.v05_defaults(),Profile.v06_defaults(),Profile.v07_defaults(),profile]:
		var flow:=Main.instantiate()
		flow.generation_profile=cfg
		flow.record_path=path
		root.add_child(flow)
		flow.start_endless(404)
		check("revision_"+str(cfg.generator_revision)+"_feature_gate",flow.player.dash_enabled==(cfg.generator_revision==6) and flow.rules_revision()==(8 if cfg.generator_revision==6 else 7) and flow.record_path==path)
		if cfg.generator_revision==6:
			var relay_id: String=flow.course.chunks[0].id+":fixture"
			flow.course.chunks[0].relays.append({"id":relay_id,"local_position":Vector2(200,410),"position":Vector2(200,410),"activated":false})
			flow.course._sync_geometry()
			flow._relay_pending.assign([relay_id])
			flow._activate_pending_relays()
			var state: Dictionary=flow.player.dash_snapshot()
			flow._relay_pending.assign([relay_id])
			flow._activate_pending_relays()
			check("flow_duplicate_node_no_refill_or_score",flow.player.dash_snapshot()==state and flow.relay_count==1)
			flow.player.try_dash()
			var during: Dictionary=flow.player.dash_snapshot()
			var point: Vector2=flow.player.position+Vector2(flow.course.total_offset,0)
			flow._shift_endless_world(25600)
			check("active_dash_rebase_global_position_and_resource",flow.player.dash_snapshot()==during and flow.player.position+Vector2(flow.course.total_offset,0)==point)
			flow._queue_failure("caught")
			flow._relay_pending.assign([relay_id])
			await process_frame
			check("terminal_cancels_resource_and_player",flow.phase=="failed" and not flow.player.try_dash() and not flow.player.charge_dash("fresh"))
		root.remove_child(flow)
		flow.queue_free()
		await process_frame
	for p in old:
		check("formal_record_state_preserved_"+p,old[p]==(FileAccess.get_sha256(p) if FileAccess.file_exists(p) else "missing"))
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(path+suffix):
			DirAccess.remove_absolute(path+suffix)
	await process_frame
	OS.delay_msec(150)
	var passed:=checks.all(func(c):return c.passed)
	var file:=FileAccess.open("res://reports/v0.8/compat-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"checks":checks,"formal_before":old,"method":"Isolated records and real Main revisions2..6; explicit invalid metadata/snapshot, duplicate relay and terminal fixtures. Missing means absent observation, not hash validation of existing records."},"\t"))
	file.close()
	print(JSON.stringify({"passed":passed,"checks":checks.size(),"failed":checks.filter(func(c):return not c.passed)}))
	quit(0 if passed else 1)
