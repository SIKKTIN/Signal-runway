extends RefCounted
## Separate local endless record. Static-course session scores are not migrated.
const DEFAULT_PATH := "user://signal_runway_endless_v08.json"
const V07_PATH := "user://signal_runway_endless_v07.json"
const V06_PATH := "user://signal_runway_endless_v06.json"
const V05_PATH := "user://signal_runway_endless_v05.json"
const LEGACY_PATH := "user://signal_runway_endless.json"
var best := {"score": 0, "distance": 0.0, "nodes": 0, "seed": 0}
var status := "missing"
var expected_rules_revision := 0
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
	if expected_rules_revision > 0 and (data.get("schema") != 2 or data.get("rules_revision") != expected_rules_revision):
		status = "invalid"
		return
	if (data.get("schema") != 1 and data.get("schema") != 2) or not data.get("best") is Dictionary:
		status = "invalid"
		return
	if data.schema == 2 and ((data.get("rules_revision") != 5 and data.get("rules_revision") != 6 and data.get("rules_revision") != 7 and data.get("rules_revision") != 8) or (data.get("generator_revision") != 2 and data.get("generator_revision") != 3 and data.get("generator_revision") != 4 and data.get("generator_revision") != 5 and data.get("generator_revision") != 6) or not data.get("profile_fingerprint") is String or data.profile_fingerprint.length() != 12):
		status = "invalid"
		return
	if data.schema==2 and ((data.rules_revision==8 and data.generator_revision!=6) or (data.generator_revision==6 and data.rules_revision!=8)):
		status="invalid"
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
func consider(file_path: String, score: int, distance: float, nodes: int, seed_value: int, metadata: Dictionary = {}) -> bool:
	if score <= int(best.score):
		return false
	best = {"score": score, "distance": distance, "nodes": nodes, "seed": seed_value}
	var temporary := file_path + ".tmp"
	var backup := file_path + ".bak"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		status = "save_failed"
		return true
	var data := {"schema":1,"generator_revision":1,"best":best}
	if not metadata.is_empty():
		data.schema = 2
		data.merge(metadata,true)
	file.store_string(JSON.stringify(data))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		status = "save_failed"
		return true
	var had_old := FileAccess.file_exists(file_path)
	if had_old and FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
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
