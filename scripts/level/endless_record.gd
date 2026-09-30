extends RefCounted
## Separate local endless record. Static-course session scores are not migrated.
const DEFAULT_PATH := "user://signal_runway_endless.json"
var best := {"score": 0, "distance": 0.0, "nodes": 0, "seed": 0}
var status := "missing"
func load_from(file_path: String) -> void:
	best = {"score": 0, "distance": 0.0, "nodes": 0, "seed": 0}
	status = "missing"
	if not FileAccess.file_exists(file_path):
		return
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		status = "read_failed"
		return
	var parser := JSON.new()
	var result := parser.parse(file.get_as_text())
	file.close()
	if result != OK or not parser.data is Dictionary:
		status = "invalid"
		return
	var data: Dictionary = parser.data
	if data.get("schema") != 1 or not data.get("best") is Dictionary:
		status = "invalid"
		return
	var row: Dictionary = data.best
	for key in ["score", "distance", "nodes", "seed"]:
		var v: Variant = row.get(key)
		if not (v is int or v is float) or not is_finite(float(v)) or float(v) < 0:
			status = "invalid"
			return
		if key != "distance" and (floor(float(v)) != float(v) or float(v) > 9007199254740991.0):
			status = "invalid"
			return
	best = {"score": int(row.score), "distance": float(row.distance), "nodes": int(row.nodes), "seed": int(row.seed)}
	status = "loaded"
func consider(file_path: String, score: int, distance: float, nodes: int, seed_value: int) -> bool:
	if score <= int(best.score):
		return false
	best = {"score": score, "distance": distance, "nodes": nodes, "seed": seed_value}
	var temporary := file_path + ".tmp"
	var backup := file_path + ".bak"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		status = "save_failed"
		return true
	file.store_string(JSON.stringify({"schema": 1, "generator_revision": 1, "best": best}))
	file.flush()
	file.close()
	var had_old := FileAccess.file_exists(file_path)
	if had_old and DirAccess.rename_absolute(file_path, backup) != OK:
		status = "save_failed"
		return true
	if DirAccess.rename_absolute(temporary, file_path) != OK:
		if had_old:
			DirAccess.rename_absolute(backup, file_path)
		status = "save_failed"
		return true
	if had_old:
		DirAccess.remove_absolute(backup)
	status = "saved"
	return true
