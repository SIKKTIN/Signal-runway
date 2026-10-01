extends SceneTree
const Profile = preload("res://scripts/level/generation_profile.gd")
const Generator = preload("res://scripts/level/endless_generator.gd")
const OldGenerator = preload("res://reports/v0.6/history/endless_generator.gd")
var failures: Array[String] = []
var stations := 0
var combos := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
func run() -> void:
	for seed_value in 100:
		var g := Generator.new()
		var duplicate := Generator.new()
		g.reset(seed_value,Profile.defaults())
		duplicate.reset(seed_value,Profile.defaults())
		var last_station := 0
		var last_relay := -1
		var roles: Array[String] = []
		var vertical_flags: Array[bool] = []
		for i in 200:
			var row := g.next()
			check(var_to_bytes(row)==var_to_bytes(duplicate.next()),"determinism %d:%d"%[seed_value,i])
			check(row.challenge_streak<=2,"challenge limit")
			roles.append(row.segment_role)
			vertical_flags.append(row.geometry.get("vertical",false))
			if row.segment_role=="恢复":
				stations += 1
				check(i-last_station>=16 and i-last_station<=24,"station interval")
				check(roles[i-1]=="缓和","station approach")
				last_station=i
			if i>0 and roles[i-1]=="恢复":
				check(row.segment_role=="缓和","station exit")
			if row.category=="relay":
				check(last_relay<0 or (i-last_relay>=5 and i-last_relay<=6),"relay interval")
				last_relay=i
			if row.geometry.has("challenge"):
				combos+=1
				check(row.geometry.challenge.order.size()==3 and row.geometry.relays.size()==4,"challenge metadata")
			if i>=11:
				var count_vertical:=0
				for j in range(i-9,i+1):
					count_vertical+=int(vertical_flags[j])
				check(count_vertical>=3,"vertical window guarantee")
		for settings in [Profile.legacy_defaults(),Profile.v05_defaults()]:
			var new := Generator.new()
			var old := OldGenerator.new()
			new.reset(seed_value,settings)
			old.reset(seed_value,settings)
			for i in 200:
				check(var_to_bytes(new.next())==var_to_bytes(old.next()),"legacy sequence %d:%d"%[seed_value,i])
	for revision in [2,3,4]:
		var value: Dictionary = Profile.legacy_defaults() if revision==2 else (Profile.v05_defaults() if revision==3 else Profile.defaults())
		check(Profile.validate(JSON.parse_string(JSON.stringify(value))).is_empty(),"json version read")
	var bad := Profile.defaults()
	bad.station_min=25
	check(not Profile.validate(bad).is_empty(),"reject interval")
	bad=Profile.defaults()
	bad.generator_revision=9
	check(not Profile.validate(bad).is_empty(),"reject version")
	bad=Profile.defaults()
	bad.templates.gap.enabled=false
	bad.templates.step.enabled=false
	bad.templates.rhythm_a.enabled=false
	var fallback := Generator.new()
	fallback.reset(404,bad)
	for i in 200:
		check(fallback.next().geometry.get("vertical",false) or i<2,"fallback valid")
	var f:=FileAccess.open("res://reports/v0.6/generation-results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures.slice(0,30),"failure_count":failures.size(),"seeds":100,"segments_per_seed":200,"stations":stations,"challenges":combos,"legacy_versions":[2,3],"method":"deterministic snapshot/metadata checks; not physical traversal"},"\t"))
	f.close()
	print("v06 generation failures ",failures.size())
	quit(0 if failures.is_empty() else 1)
