extends RefCounted
const Library = preload("res://scripts/level/endless_library.gd")
const Profile = preload("res://scripts/level/generation_profile.gd")
const Vertical = preload("res://scripts/level/vertical_library.gd")
var geometry_seed := 0
var recent_vertical: Array[bool] = []
var profile: Dictionary = Profile.defaults()
var rng := RandomNumberGenerator.new()
var index := 0
var next_relay := 5
var last_id := ""
var last_difficulty := 0
var walls_since_relay := 0
var pool: Array[String] = []
var rhythm: RefCounted
func reset(seed_value: int, settings: Dictionary = {}) -> void:
	profile = Profile.defaults() if settings.is_empty() or not Profile.validate(settings).is_empty() else Profile.normalized(settings)
	rhythm = null
	if profile.generator_revision >= 4:
		rhythm = load("res://scripts/level/skill_generator.gd" if profile.generator_revision==6 else ("res://scripts/level/spatial_generator.gd" if profile.generator_revision==5 else "res://scripts/level/rhythm_generator.gd")).new()
		rhythm.reset(seed_value,profile)
	rng.seed = seed_value
	geometry_seed = seed_value
	recent_vertical.clear()
	index = 0
	next_relay = int(profile.relay_min)
	last_id = ""
	last_difficulty = 0
	walls_since_relay = 0
	pool = Library.ids()
func next() -> Dictionary:
	if rhythm != null:
		var row: Dictionary = rhythm.next()
		index = int(row.index)+1
		return row
	# Map stage uses nominal route time, independent of frame/prefetch/player input.
	var stage := mini(3, int(index * Library.LENGTH / profile.stage_distance))
	var selected := ""
	var candidates: Array[String] = []
	var excluded := {}
	var reason := "按合格候选权重随机选择"
	if index == 0:
		selected = "safe_a"
		reason = "开局安全A锁定"
	elif index == 1:
		selected = "safe_b"
		reason = "开局安全B锁定"
	else:
		var due := index == next_relay
		for id in pool:
			var d := Library.definition(id)
			if not profile.templates[id].enabled:
				excluded[id] = "配置禁用"
				continue
			if profile.generator_revision == 3 and not due and id not in Vertical.STRUCTURES:
				var count_vertical := recent_vertical.count(true)
				var two_flat := recent_vertical.size() >= 2 and not recent_vertical[-1] and not recent_vertical[-2]
				if two_flat or (recent_vertical.size() >= 9 and count_vertical < 3):
					excluded[id] = "保留立体变化：十段至少三段/最多两连续平段"
					continue
			if id == last_id or (d.category == "relay") != due:
				excluded[id] = "禁止重复" if id == last_id else "中继间隔资格"
				continue
			if d.difficulty > maxi(1, stage):
				excluded[id] = "尚未达到难度阶段"
				continue
			if last_difficulty >= 2 and d.category != "safe":
				excluded[id] = "高难后安全调整"
				continue
			if d.difficulty >= 2 and index + 1 == next_relay:
				excluded[id] = "中继前保留安全调整"
				continue
			if d.category == "wall" and (walls_since_relay >= 1 or index + 1 == next_relay):
				excluded[id] = "墙跳收益预算/中继前调整"
				continue
			# One costly wall action per reward interval, including optional relay B.
			if id == "relay_b" and walls_since_relay > 0:
				excluded[id] = "本奖励间隔已有成本墙跳"
				continue
			candidates.append(id)
		if candidates.is_empty():
			selected = "safe_b" if last_id == "safe_a" else "safe_a"
			reason = "安全兜底：无合格候选"
			if profile.generator_revision == 3:
				selected = "step" if last_id == "safe_b" else "safe_b"
				reason = "安全兜底：已验证缓和起伏，覆盖权重以保障可通行与空间变化"
		else:
			var uniform := true
			var total := 0.0
			for id in candidates:
				total += float(profile.templates[id].weight)
				uniform = uniform and is_equal_approx(profile.templates[id].weight, profile.templates[candidates[0]].weight)
			if uniform:
				selected = candidates[rng.randi_range(0, candidates.size() - 1)]
			else:
				var choice := rng.randf() * total
				selected = candidates.back()
				for id in candidates:
					choice -= float(profile.templates[id].weight)
					if choice <= 0:
						selected = id
						break
		if due:
			next_relay = index + rng.randi_range(profile.relay_min, profile.relay_max)
			walls_since_relay = 0
	var definition := Library.definition(selected)
	if definition.category == "wall":
		walls_since_relay += 1
	last_id = selected
	last_difficulty = definition.difficulty
	var result := {"index": index, "template_id": selected, "stage": stage, "length": definition.length, "difficulty": definition.difficulty, "category": definition.category, "reason": reason, "candidates": candidates, "excluded": excluded, "next_relay": next_relay}
	if profile.generator_revision == 3 and index >= 2:
		var shape_rng := RandomNumberGenerator.new()
		shape_rng.seed = absi((str(geometry_seed)+":"+str(index)+":geometry3").hash())
		var h := shape_rng.randi_range(profile.height_min/16,profile.height_max/16)*16
		var gap := shape_rng.randi_range(profile.gap_min/16,profile.gap_max/16)*16
		result.geometry = Vertical.build(selected,h,gap,int(h-32)/16)
	else:
		result.geometry = Library.definition(selected)
	recent_vertical.append(result.geometry.get("vertical",false))
	if recent_vertical.size() > 9:
		recent_vertical.pop_front()
	index += 1
	return result
