extends SceneTree
const Profile=preload("res://scripts/level/generation_profile.gd")
const Generator=preload("res://scripts/level/endless_generator.gd")
const Previous=preload("res://reports/v0.7/history/endless_generator.gd")
const Spatial=preload("res://scripts/level/spatial_library.gd")
var failures: Array[String]=[]
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var counts:={}
	var chains:=0
	var stations:=0
	for seed_value in 100:
		var g:=Generator.new()
		var duplicate:=Generator.new()
		g.reset(seed_value)
		duplicate.reset(seed_value)
		var prior: Dictionary={}
		var station_index:=0
		var relay_index:=-1
		for i in 200:
			var row:=g.next()
			var d: Dictionary=row.geometry
			if var_to_bytes(row)!=var_to_bytes(duplicate.next()):
				failures.append("determinism %d:%d"%[seed_value,i])
			failures.append_array(Spatial.errors(d))
			counts[d.spatial_id]=counts.get(d.spatial_id,0)+1
			if not prior.is_empty():
				if d.connection.entry_y!=prior.connection.exit_y or d.connection.upper_from!=prior.connection.upper_to or (d.connection.upper_from and d.connection.upper_entry_y!=prior.connection.upper_exit_y):
					failures.append("seam %d:%d"%[seed_value,i])
			if row.challenge_streak>2:
				failures.append("streak")
			if d.connection.upper_from:
				chains+=1
			if d.has("station"):
				stations+=1
				if i-station_index<16 or i-station_index>24 or prior.segment_role!="缓和":
					failures.append("station")
				station_index=i
			if not prior.is_empty() and prior.has("station") and row.segment_role!="缓和":
				failures.append("post station")
			if row.category=="relay":
				if relay_index>=0 and (i-relay_index<5 or i-relay_index>6):
					failures.append("relay")
				relay_index=i
			prior=d
	var legacy_runs:=0
	for p in [Profile.legacy_defaults(),Profile.v05_defaults(),Profile.v06_defaults()]:
		for seed_value in 100:
			var old:=Previous.new()
			var current:=Generator.new()
			old.reset(seed_value,p)
			current.reset(seed_value,p)
			for i in 200:
				if var_to_bytes(old.next())!=var_to_bytes(current.next()):
					failures.append("legacy%d %d:%d"%[p.generator_revision,seed_value,i])
			legacy_runs+=1
	var file:=FileAccess.open("res://reports/v0.7/generation-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures.slice(0,30),"seeds":100,"chunks_per_seed":200,"counts":counts,"upper_seams":chains,"stations":stations,"legacy_profiles":3,"legacy_seeds":legacy_runs,"method":"deterministic 100x200 v5 geometry/seam/rhythm invariants; v2/v3/v4 each100x200 exact byte snapshots against saved pre-v07 generator. Structural checks, no physics or player experience."},"\t"))
	file.close()
	print(JSON.stringify({"passed":failures.is_empty(),"counts":counts,"upper_seams":chains,"failures":failures.slice(0,20)}))
	quit(0 if failures.is_empty() else 1)
