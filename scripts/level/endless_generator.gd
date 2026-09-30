extends RefCounted
const Library = preload("res://scripts/level/endless_library.gd")
var rng := RandomNumberGenerator.new()
var index := 0
var next_relay := 5
var last_id := ""
var last_difficulty := 0
var walls_since_relay := 0
var pool: Array[String] = []
func reset(seed_value: int) -> void:
	rng.seed = seed_value
	index = 0
	next_relay = 5
	last_id = ""
	last_difficulty = 0
	walls_since_relay = 0
	pool = Library.ids()
func next() -> Dictionary:
	# Map stage uses nominal route time, independent of frame/prefetch/player input.
	var stage := mini(3, int(index * Library.LENGTH / 8400.0))
	var selected := ""
	if index == 0:
		selected = "safe_a"
	elif index == 1:
		selected = "safe_b"
	else:
		var candidates: Array[String] = []
		var due := index == next_relay
		for id in pool:
			var d := Library.definition(id)
			if id == last_id or (d.category == "relay") != due:
				continue
			if d.difficulty > maxi(1, stage):
				continue
			if last_difficulty >= 2 and d.category != "safe":
				continue
			if d.difficulty >= 2 and index + 1 == next_relay:
				continue
			if d.category == "wall" and (walls_since_relay >= 1 or index + 1 == next_relay):
				continue
			# One costly wall action per reward interval, including optional relay B.
			if id == "relay_b" and walls_since_relay > 0:
				continue
			candidates.append(id)
		if candidates.is_empty():
			selected = "safe_b" if last_id == "safe_a" else "safe_a"
		else:
			selected = candidates[rng.randi_range(0, candidates.size() - 1)]
		if due:
			next_relay = index + rng.randi_range(5, 6)
			walls_since_relay = 0
	var definition := Library.definition(selected)
	if definition.category == "wall":
		walls_since_relay += 1
	last_id = selected
	last_difficulty = definition.difficulty
	var result := {"index": index, "template_id": selected, "stage": stage, "length": definition.length, "difficulty": definition.difficulty, "category": definition.category}
	index += 1
	return result
