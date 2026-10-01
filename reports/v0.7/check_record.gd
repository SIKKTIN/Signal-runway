extends SceneTree
const Record=preload("res://scripts/level/endless_record.gd")
const Profile=preload("res://scripts/level/generation_profile.gd")
var checks: Array[Dictionary]=[]
func check(name_value: String,value: bool) -> void:
	checks.append({"name":name_value,"passed":value})
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var file_path:="user://v07_record_%d.json"%OS.get_process_id()
	var old_hash:=FileAccess.get_sha256(Record.V05_PATH) if FileAccess.file_exists(Record.V05_PATH) else "missing"
	var r:=Record.new()
	r.expected_rules_revision=7
	check("独立v06文件名",Record.DEFAULT_PATH!=Record.V05_PATH)
	var metadata:={"rules_revision":7,"generator_revision":4,"profile_fingerprint":Profile.fingerprint(Profile.defaults()),"score_breakdown":{"distance":100,"nodes":100,"combo":200,"station":200}}
	check("原子保存完整新规则",r.consider(file_path,600,1000,1,404,metadata) and r.status=="saved")
	var loaded:=Record.new()
	loaded.expected_rules_revision=7
	loaded.load_from(file_path)
	check("JSON重新加载v06",loaded.status=="loaded" and loaded.best.score==600)
	check("低分不覆盖",not loaded.consider(file_path,500,2000,2,77,metadata) and loaded.best.score==600)
	metadata.rules_revision=5
	r.consider(file_path,700,1000,1,404,metadata)
	loaded.load_from(file_path)
	check("v05规则拒绝混入v06",loaded.status=="invalid")
	var f:=FileAccess.open(file_path,FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	loaded.load_from(file_path)
	check("坏档可见",loaded.status=="invalid" and loaded.best.score==0)
	metadata.rules_revision=7
	r.consider("user://no_such_directory_%d/record.json"%OS.get_process_id(),800,1000,1,404,metadata)
	check("写失败保留内存成绩",r.status=="save_failed" and r.best.score==800)
	check("旧v05成绩逐字节保留",old_hash==(FileAccess.get_sha256(Record.V05_PATH) if FileAccess.file_exists(Record.V05_PATH) else "missing"))
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(file_path+suffix):
			DirAccess.remove_absolute(file_path+suffix)
	var failed:=checks.filter(func(c):return not c.passed)
	f=FileAccess.open("res://reports/v0.7/record-results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"passed":failed.is_empty(),"checks":checks,"method":"isolated record files; read/write failures and rule mismatch fixtures"},"\t"))
	f.close()
	print(JSON.stringify({"checks":checks.size(),"failed":failed}))
	quit(0 if failed.is_empty() else 1)
