extends RefCounted
const Profile = preload("res://scripts/level/generation_profile.gd")
const Vertical = preload("res://scripts/level/vertical_library.gd")
const Library = preload("res://scripts/level/endless_library.gd")
var base: RefCounted
var profile: Dictionary
var rng := RandomNumberGenerator.new()
var next_station := 20
var previous_station := -100
var challenge_streak := 0
var last_id := ""
func reset(seed_value: int, settings: Dictionary) -> void:
	profile = settings.duplicate(true)
	base = load("res://scripts/level/endless_generator.gd").new()
	var old := Profile.v05_defaults()
	for key in old:
		if key != "generator_revision":
			old[key] = profile[key]
	base.reset(seed_value,old)
	rng.seed = absi((str(seed_value)+":rhythm4").hash())
	next_station = rng.randi_range(profile.station_min,profile.station_max)
	previous_station = -100
	challenge_streak = 0
	last_id = ""
func next() -> Dictionary:
	var row: Dictionary = base.next()
	var i: int = row.index
	var phase := 0 if i*1280 < profile.phase_one else (1 if i*1280 < profile.phase_two else 2)
	var role := "缓和"
	var d: Dictionary = row.geometry
	var near_station := i == next_station-1 or i == previous_station+1
	if i >= 2:
		var shape := RandomNumberGenerator.new()
		shape.seed = absi((str(base.geometry_seed)+":"+str(i)+":geometry4").hash())
		var h := shape.randi_range(profile.height_min/16,profile.height_max/16)*16
		var gap := shape.randi_range(profile.gap_min/16,profile.gap_max/16)*16
		if i == next_station:
			row.candidates=["relay_a"]
			role = "恢复"
			d = Vertical.build("relay_a",32,80)
			d.relays = [{"local_id":"low","position":Vector2(1010,410)}] if row.category == "relay" else []
			d.station = {"heal":Vector2(460,382),"score":Vector2(460,430),"bonus":profile.station_bonus}
			row.template_id = "relay_a"
			d.structure = "恢复站双路线"
			previous_station = i
			next_station = i+rng.randi_range(profile.station_min,profile.station_max)
		elif row.category == "relay" and not near_station and challenge_streak < profile.challenge_limit:
			role = "分路"
			d = Vertical.build(row.template_id,h,gap)
			d.relays = [{"local_id":"challenge_1","position":Vector2(400,448-h-34)},{"local_id":"challenge_2","position":Vector2(588+gap,448-2*h-34)},{"local_id":"challenge_3","position":Vector2(860,448-h-34)},{"local_id":"low","position":Vector2(1010,410)}]
			d.challenge = {"entry":Rect2(280,0,96,448-h-10),"exit_x":976.0,"lower":Rect2(370,410,606,110),"order":["challenge_1","challenge_2","challenge_3"],"bonus":profile.combo_bonus}
		else:
			var wants_challenge: bool = not near_station and challenge_streak < profile.challenge_limit and rng.randf() < float(profile.challenge_weight+phase)/float(profile.challenge_weight+phase+3)
			# Reserve a calm segment before a compulsory relay if this would exceed the streak.
			if i+1 == base.next_relay and challenge_streak+1 >= profile.challenge_limit:
				wants_challenge = false
			var options: Array[String] = []
			if wants_challenge and row.category != "relay":
				for id in ["step","gap","rhythm_a"]:
					if profile.templates[id].enabled and id != last_id:
						options.append(id)
			if not options.is_empty():
				row.candidates=options.duplicate()
				role = "挑战"
				var total := 0.0
				for id in options:
					total += profile.templates[id].weight
				var choice := rng.randf()*total
				row.template_id = options.back()
				for id in options:
					choice -= profile.templates[id].weight
					if choice <= 0:
						row.template_id = id
						break
				d = Vertical.build(row.template_id,h,gap)
			else:
				row.candidates=["safe_b","step"]
				d = Vertical.build("step" if last_id == "safe_b" else "safe_b",32,80)
				if row.category == "relay":
					d.relays = [{"local_id":"low","position":Vector2(1010,410)}]
				else:
					row.template_id = "step" if last_id == "safe_b" else "safe_b"
				if wants_challenge and options.is_empty():
					row.reason = "安全兜底：挑战候选禁用，采用已验证缓和起伏"
		row.reason += " · 段落编排："+role
		for id in Library.ids():
			if id not in row.candidates:
				row.excluded[id]="v4段落角色与安全连接筛选"
			else:
				row.excluded.erase(id)
		d.category = row.category if row.category == "relay" else ("safe" if role in ["缓和","恢复"] else "rhythm")
		d.difficulty = 1 if role in ["挑战","分路"] else 0
		d.validation = "v0.6候选几何；以版本验收报告为准，当前预览未实时动作模拟"
	challenge_streak = challenge_streak+1 if role in ["挑战","分路"] else 0
	last_id = row.template_id
	row.geometry = d
	row.category = d.category
	row.difficulty = d.difficulty
	row.stage = phase
	row.segment_role = role
	row.next_station = next_station
	row.challenge_streak = challenge_streak
	d.segment_role = role
	d.phase = phase
	return row
