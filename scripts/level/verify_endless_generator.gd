extends SceneTree
const Generator = preload("res://scripts/level/endless_generator.gd")
var checks: Array[Dictionary] = []
func _initialize() -> void:
	call_deferred("run")
func check(name: String, value: bool) -> void:
	checks.append({"check": name, "passed": value})
func run() -> void:
	var repeatable := true
	var structure := true
	var intervals := true
	var adjustment := true
	var wall_budget := true
	var diversity: Dictionary = {}
	var prefixes: Dictionary = {}
	for seed_value in range(1, 101):
		var a := Generator.new()
		var b := Generator.new()
		a.reset(seed_value)
		b.reset(seed_value)
		var last := ""
		var difficulty := 0
		var previous_relay := -1
		var costly_walls := 0
		var prefix: Array = []
		for index in 200:
			var e: Dictionary = a.next()
			# Consume unrelated global random values and variable batch cadence.
			for _j in index % 4:
				randf()
			repeatable = repeatable and e == b.next()
			structure = structure and e.template_id != last and e.length == 1280 and e.difficulty <= maxi(1, e.stage)
			adjustment = adjustment and (difficulty < 2 or e.category == "safe")
			if e.category == "wall":
				costly_walls += 1
			if e.category == "relay":
				costly_walls += int(e.template_id == "relay_b")
				wall_budget = wall_budget and costly_walls <= 1
				costly_walls = 0
				intervals = intervals and (previous_relay < 0 or index - previous_relay in [5, 6])
				previous_relay = index
			last = e.template_id
			difficulty = e.difficulty
			diversity[last] = true
			if index < 20:
				prefix.append(last)
		prefixes[JSON.stringify(prefix)] = true
	check("100_seeds_200_chunks_valid", structure)
	check("same_seed_unrelated_rng_and_batch_independent", repeatable)
	check("12_templates_reached", diversity.size() == 12)
	check("relay_interval_five_or_six_chunks", intervals)
	check("high_difficulty_followed_by_adjustment", adjustment)
	check("different_seeds_have_varied_prefixes", prefixes.size() > 90)
	check("at_most_one_costly_wall_per_reward_interval", wall_budget)
	var fallback := Generator.new()
	fallback.reset(404)
	fallback.pool.clear()
	var safe := true
	for _i in 10:
		safe = safe and fallback.next().category == "safe"
	check("empty_candidate_pool_safe_fallback", safe)
	var passed := checks.all(func(c): return c.passed)
	var f := FileAccess.open("res://reports/v0.4/generator-results.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks": checks, "passed": passed, "templates": diversity.keys(), "unique_prefixes": prefixes.size(), "scope": "20,000 pure generator entries. Structure and reproducibility only; action reachability separately tested in full-chunk-results."}, "\t"))
	f.close()
	print(JSON.stringify({"checks": checks, "passed": passed}))
	quit(0 if passed else 1)
