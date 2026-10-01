extends SceneTree
const Profile=preload("res://scripts/level/generation_profile.gd")
const Generator=preload("res://scripts/level/endless_generator.gd")
const Old=preload("res://reports/v0.8/workflow/old_endless_generator.gd")
const Spatial=preload("res://scripts/level/spatial_library.gd")
var errors: Array[String]=[]
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var counts:={"shortcut":0,"relay":0,"rescue":0}
	var seams:=0
	for seed_value in 100:
		var g:=Generator.new()
		var same:=Generator.new()
		g.reset(seed_value,Profile.defaults())
		same.reset(seed_value,Profile.defaults())
		var previous: Dictionary={}
		var last_relay:=-1
		var last_station:=0
		var last_skill:=-100
		for i in 200:
			var row:=g.next()
			var twin:=same.next()
			if var_to_bytes(row)!=var_to_bytes(twin):
				errors.append("determinism "+str(seed_value)+":"+str(i))
			var d: Dictionary=row.geometry
			errors.append_array(Spatial.errors(d))
			if not previous.is_empty():
				var a: Dictionary=previous.connection
				var b: Dictionary=d.connection
				if a.exit_y!=b.entry_y or a.upper_to!=b.upper_from or (b.upper_from and a.upper_exit_y!=b.upper_entry_y):
					errors.append("seam "+str(seed_value)+":"+str(i))
				seams+=int(b.upper_from)
			if d.has("skill"):
				counts[d.skill.kind]+=1
				if d.skill.required not in [0,1] or not d.skill.stable or d.skill.reward_nodes!=3 or i-last_skill<Profile.defaults().relay_min:
					errors.append("budget "+str(i))
				last_skill=i
			if row.category=="relay":
				if last_relay>=0 and (i-last_relay<5 or i-last_relay>6):
					errors.append("relay interval")
				last_relay=i
			if d.has("station"):
				if i-last_station<16 or i-last_station>24:
					errors.append("station interval")
				last_station=i
			previous=d
	for cfg in [Profile.legacy_defaults(),Profile.v05_defaults(),Profile.v06_defaults(),Profile.v07_defaults()]:
		for seed_value in 100:
			var g:=Generator.new()
			var old:=Old.new()
			g.reset(seed_value,cfg)
			old.reset(seed_value,cfg)
			for _i in 200:
				if var_to_bytes(g.next())!=var_to_bytes(old.next()):
					errors.append("legacy "+str(cfg.generator_revision)+":"+str(seed_value))
	var passed:=errors.is_empty()
	var file:=FileAccess.open("res://reports/v0.8/generation-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"seeds":100,"segments":200,"counts":counts,"upper_seams":seams,"legacy_revisions":[2,3,4,5],"errors":errors,"method":"Deterministic fixed seed/profile geometry and budget checks; 100x200 per legacy revision exact against saved pre-v08 generator/profile. Structural proof, not action simulation."},"\t"))
	file.close()
	print(JSON.stringify({"passed":passed,"counts":counts,"errors":errors.slice(0,10)}))
	quit(0 if passed else 1)
