extends RefCounted
const Library = preload("res://scripts/level/endless_library.gd")
const DEFAULT_PATH := "res://resources/generation/endless_default.json"
const LOCKED := ["safe_a", "safe_b", "relay_a"]
static func defaults() -> Dictionary:
	var entries := {}
	for id in Library.ids():
		entries[id] = {"enabled": true, "weight": 1.0}
	return {"schema": 1, "generator_revision": 2, "stage_distance": 8400.0, "relay_min": 5, "relay_max": 6, "templates": entries}
static func validate(value: Variant) -> Array[String]:
	var errors: Array[String] = []
	if not value is Dictionary:
		return ["配置必须是对象"]
	var expected: Array = defaults().keys()
	for key in value:
		if key not in expected:
			errors.append("未知字段：" + str(key))
	for key in expected:
		if not value.has(key):
			errors.append("缺少字段：" + key)
	if not errors.is_empty():
		return errors
	if value.schema != 1 or value.generator_revision != 2:
		errors.append("不支持的配置/生成规则版本")
	for key in ["stage_distance", "relay_min", "relay_max"]:
		var v: Variant = value[key]
		if not (v is int or v is float) or not is_finite(float(v)):
			errors.append(key + "必须是有限数值")
	if not errors.is_empty():
		return errors
	if value.stage_distance < 4200 or value.stage_distance > 16800:
		errors.append("阶段距离范围4200至16800")
	if value.relay_min < 4 or value.relay_max > 8 or value.relay_min > value.relay_max or floor(value.relay_min) != value.relay_min or floor(value.relay_max) != value.relay_max:
		errors.append("中继间隔必须为4至8的整数，最小不大于最大")
	if not value.templates is Dictionary:
		errors.append("templates必须是对象")
		return errors
	for id in value.templates:
		if id not in Library.ids():
			errors.append("未知片段：" + str(id))
	for id in Library.ids():
		var entry: Variant = value.templates.get(id)
		if not entry is Dictionary or entry.size() != 2 or not entry.get("enabled") is bool:
			errors.append(id + "需要enabled布尔和weight")
			continue
		var weight: Variant = entry.get("weight")
		if not (weight is int or weight is float) or not is_finite(float(weight)):
			errors.append(id + "权重必须是有限数值")
			continue
		if weight < 0 or weight > 10 or (entry.enabled and weight <= 0):
			errors.append(id + "启用时权重须大于0，上限10")
		if id in LOCKED and (not entry.enabled or weight < 1):
			errors.append(id + "为安全/奖励保障，必须启用且权重至少1")
	return errors
static func normalized(value: Dictionary) -> Dictionary:
	var result := defaults()
	result.stage_distance = float(value.stage_distance)
	result.relay_min = int(value.relay_min)
	result.relay_max = int(value.relay_max)
	for id in Library.ids():
		result.templates[id] = {"enabled": bool(value.templates[id].enabled), "weight": float(value.templates[id].weight)}
	return result
static func fingerprint(value: Dictionary) -> String:
	return JSON.stringify(normalized(value), "", true).sha256_text().substr(0, 12)
static func load_profile(file_path: String = DEFAULT_PATH) -> Dictionary:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {"profile": defaults(), "fallback": true, "errors": ["配置缺失或无法读取，已回退内置默认"]}
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	var errors: Array[String] = []
	if error == OK:
		errors = validate(parser.data)
	else:
		errors.append("JSON损坏")
	return {"profile": normalized(parser.data) if errors.is_empty() else defaults(), "fallback": not errors.is_empty(), "errors": errors}
static func save_profile(value: Dictionary, file_path: String) -> Dictionary:
	var errors := validate(value)
	if not errors.is_empty():
		return {"ok": false, "message": "；".join(errors)}
	var file := FileAccess.open(file_path + ".tmp", FileAccess.WRITE)
	if file == null:
		return {"ok": false, "message": "无法写入：" + file_path}
	file.store_string(JSON.stringify(normalized(value), "\t", true))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return {"ok": false, "message": "写入失败，原配置保留"}
	var had_old := FileAccess.file_exists(file_path)
	if had_old:
		if FileAccess.file_exists(file_path + ".bak"):
			DirAccess.remove_absolute(file_path + ".bak")
		if DirAccess.rename_absolute(file_path, file_path + ".bak") != OK:
			return {"ok": false, "message": "备份失败，原配置保留"}
	if DirAccess.rename_absolute(file_path + ".tmp", file_path) != OK:
		if had_old:
			DirAccess.rename_absolute(file_path + ".bak", file_path)
		return {"ok": false, "message": "替换失败，原配置已恢复"}
	return {"ok": true, "message": "已保存；旧配置备份为.bak" if had_old else "已保存"}
