extends SceneTree
const Profile=preload("res://scripts/level/generation_profile.gd")
const Generator=preload("res://scripts/level/endless_generator.gd")
const Legacy=preload("res://reports/v0.4.1/legacy_generator.gd")
const Editor=preload("res://scripts/tools/generation_editor.gd")
const Course=preload("res://scripts/level/endless_course.gd")
var checks: Array[Dictionary]=[]
func _initialize() -> void:
	call_deferred("run")
func check(name_value: String,value: bool) -> void:
	checks.append({"name":name_value,"passed":value})
func run() -> void:
	check("新默认v3合法",Profile.validate(Profile.defaults()).is_empty())
	check("旧配置v2合法且保留版本",Profile.validate(Profile.legacy_defaults()).is_empty() and Profile.normalized(Profile.legacy_defaults()).generator_revision==2)
	var old_ok:=true
	var constraints_ok:=true
	var hashes_ok:=true
	var variants: Dictionary={}
	var vertical_count:=0
	var fallback_count:=0
	for seed_value in 100:
		var old:=Legacy.new()
		old.reset(seed_value)
		var adapted:=Generator.new()
		adapted.reset(seed_value,Profile.legacy_defaults())
		var a:=Generator.new()
		a.reset(seed_value,Profile.defaults())
		var b:=Generator.new()
		b.reset(seed_value,Profile.defaults())
		var sequence: Array[Dictionary]=[]
		for i in 200:
			old_ok=old_ok and old.next().template_id==adapted.next().template_id
			var row:=a.next()
			hashes_ok=hashes_ok and var_to_bytes(row.geometry)==var_to_bytes(b.next().geometry)
			sequence.append(row)
			var vertical: bool=row.geometry.get("vertical",false)
			vertical_count+=int(vertical)
			fallback_count+=int(row.reason.begins_with("安全兜底"))
			if vertical:
				var id: String=row.template_id
				if not variants.has(id):
					variants[id]={}
				variants[id][JSON.stringify(row.geometry.parameters)]=true
			if i>=9:
				var count_vertical:=0
				for j in range(i-9,i+1):
					count_vertical+=int(sequence[j].geometry.get("vertical",false))
				constraints_ok=constraints_ok and count_vertical>=3
			if i>=3:
				constraints_ok=constraints_ok and (vertical or sequence[i-1].geometry.get("vertical",false) or sequence[i-2].geometry.get("vertical",false))
		constraints_ok=constraints_ok and Editor.sequence_errors(sequence,Profile.defaults()).is_empty()
	check("100种子200段旧默认序列精确兼容",old_ok)
	check("100种子200段空间与奖励约束",constraints_ok)
	check("同种子最终几何逐字节一致",hashes_ok)
	check("六结构各至少三参数变体",variants.size()==6 and variants.values().all(func(v):return v.size()>=3))
	var custom:=Profile.defaults()
	for id in custom.templates:
		if id not in Profile.LOCKED:
			custom.templates[id].enabled=false
	var constrained:=Generator.new()
	constrained.reset(77,custom)
	var custom_rows: Array[Dictionary]=[]
	for _i in 200:
		custom_rows.append(constrained.next())
	check("极端开关仍有有限安全兜底",Editor.sequence_errors(custom_rows,custom).is_empty())
	var bad_ok:=true
	for key in ["height_min","height_max","gap_min","gap_max"]:
		for bad in [null,"64",false,999,47,INF]:
			var settings:=Profile.defaults()
			settings[key]=bad
			bad_ok=bad_ok and not Profile.validate(settings).is_empty()
	check("坏几何类型与范围拒绝",bad_ok)
	var course:=Course.new()
	course.prototype=false
	course.run_seed=404
	course.generation_profile=Profile.defaults()
	root.add_child(course)
	while course.chunks.size()<20:
		course._append_chunk(course.generator.next())
	var preview:=Generator.new()
	preview.reset(404,Profile.defaults())
	var same:=true
	for chunk in course.chunks:
		same=same and var_to_bytes(chunk.geometry)==var_to_bytes(preview.next().geometry)
	check("Course20段碰撞源与预览几何一致",same)
	course.update_stream(20000,20000)
	check("地形回收清理holder索引",course._holders.size()==course.chunks.size() and course.chunks.size()<=7)
	root.remove_child(course)
	course.queue_free()
	await process_frame
	var failed:=checks.filter(func(c):return not c.passed).size()
	var file:=FileAccess.open("res://reports/v0.5/generation-results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failed==0,"checks":checks,"vertical_count":vertical_count,"fallback_count":fallback_count,"variants":variants,"method":"100种子各200段；v2按历史固定选择器逐项比对，几何/生命周期为结构检查，动作另见324路线报告"},"\t"))
	file.close()
	print(JSON.stringify({"checks":checks.size(),"failed":failed,"vertical_count":vertical_count,"fallback_count":fallback_count}))
	quit(0 if failed==0 else 1)
