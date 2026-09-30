extends RefCounted
## Neutral seams: 240+ clear units, floor top448, grounded/rightward entry/exit.
const LENGTH := 1280.0
static func ids() -> Array[String]:
	return ["safe_a", "safe_b", "gap", "spike", "relay_a", "wall_a", "step", "rhythm_a", "rhythm_b", "rhythm_c", "relay_b", "wall_b"]
static func definition(id: String) -> Dictionary:
	var d := {"id": id, "length": LENGTH, "category": "safe", "difficulty": 0, "gaps": [], "spikes": [], "walls": [], "platforms": [], "relays": []}
	match id:
		"safe_b":
			d.platforms = [Rect2(440, 400, 224, 16)]
		"gap":
			d.category = "single"
			d.difficulty = 1
			d.gaps = [Rect2(576, 448, 112, 92)]
		"spike":
			d.category = "single"
			d.difficulty = 1
			d.spikes = [Rect2(576, 424, 32, 24)]
		"relay_a":
			d.category = "relay"
			d.difficulty = 1
			d.platforms = [Rect2(320, 400, 180, 16), Rect2(568, 352, 160, 16)]
			d.gaps = [Rect2(848, 448, 112, 92)]
			d.relays = [{"local_id": "node", "position": Vector2(646, 314)}]
		"wall_a":
			d.category = "wall"
			d.difficulty = 2
			d.walls = [Rect2(608, 320, 32, 128)]
		"step":
			d.category = "single"
			d.difficulty = 1
			d.walls = [Rect2(576, 400, 160, 48)]
		"rhythm_a":
			d.category = "rhythm"
			d.difficulty = 2
			d.gaps = [Rect2(352, 448, 80, 92), Rect2(784, 448, 96, 92)]
		"rhythm_b":
			d.category = "rhythm"
			d.difficulty = 2
			d.spikes = [Rect2(352, 424, 32, 24), Rect2(784, 424, 64, 24)]
		"rhythm_c":
			d.category = "rhythm"
			d.difficulty = 2
			d.gaps = [Rect2(352, 448, 96, 92)]
			d.spikes = [Rect2(784, 424, 32, 24)]
		"relay_b":
			d.category = "relay"
			d.difficulty = 2
			d.platforms = [Rect2(240, 384, 120, 16), Rect2(464, 296, 160, 16)]
			d.walls = [Rect2(400, 248, 32, 136)]
			d.gaps = [Rect2(848, 448, 112, 92)]
			d.relays = [{"local_id": "node", "position": Vector2(520, 258)}]
		"wall_b":
			d.category = "wall"
			d.difficulty = 3
			d.walls = [Rect2(608, 304, 32, 144)]
	var ground: Array[Rect2] = []
	var cursor := 0.0
	for gap in d.gaps:
		ground.append(Rect2(cursor, 448, gap.position.x - cursor, 160))
		cursor = gap.end.x
	ground.append(Rect2(cursor, 448, LENGTH - cursor, 160))
	d.floors = ground
	return d
