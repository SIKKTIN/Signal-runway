extends RefCounted
const Profile=preload("res://scripts/level/generation_profile.gd")
const DEFAULT_PATH="user://map_editor_failure_v07.json"
static func make(seed_value: int,profile: Dictionary,global_x: float,reason: String) -> Dictionary:
	return {"schema":1,"seed":seed_value,"profile":profile.duplicate(true),"fingerprint":Profile.fingerprint(profile),"failed_x":maxf(96,global_x),"reason":reason,"created_at":Time.get_datetime_string_from_system(true)}
static func validate(value: Variant) -> Array[String]:
	if not value is Dictionary or value.size()!=7 or value.get("schema")!=1 or not value.get("reason") is String or not value.get("created_at") is String:
		return ["失败种子文件格式无效"]
	var seed: Variant=value.get("seed")
	var x: Variant=value.get("failed_x")
	if not (seed is int or seed is float) or not is_finite(float(seed)) or seed<0 or seed>2147483647 or floor(float(seed))!=seed or not (x is int or x is float) or not is_finite(float(x)) or x<96 or x>1.0e9:
		return ["种子或失败位置超范围"]
	var errors:=Profile.validate(value.get("profile"))
	if errors.is_empty() and value.get("fingerprint")!=Profile.fingerprint(value.profile):
		errors.append("失败种子配置指纹不匹配")
	return errors
static func save(value: Dictionary,file_path: String = DEFAULT_PATH) -> Dictionary:
	var errors:=validate(value)
	if not errors.is_empty():
		return {"ok":false,"message":"；".join(errors)}
	var file:=FileAccess.open(file_path+".tmp",FileAccess.WRITE)
	if file==null:
		return {"ok":false,"message":"无法保存失败种子，原文件保留"}
	file.store_string(JSON.stringify(value,"\t",true))
	file.flush()
	var error:=file.get_error()
	file.close()
	if error!=OK:
		return {"ok":false,"message":"写入失败，原文件保留"}
	var had_old:=FileAccess.file_exists(file_path)
	if had_old:
		if FileAccess.file_exists(file_path+".bak"):
			DirAccess.remove_absolute(file_path+".bak")
		if DirAccess.rename_absolute(file_path,file_path+".bak")!=OK:
			return {"ok":false,"message":"备份失败，原文件保留"}
	if DirAccess.rename_absolute(file_path+".tmp",file_path)!=OK:
		if had_old:
			DirAccess.rename_absolute(file_path+".bak",file_path)
		return {"ok":false,"message":"替换失败，原文件已恢复"}
	return {"ok":true,"message":"失败种子已保存（含冻结配置与失败位置）"}
static func load_from(file_path: String = DEFAULT_PATH) -> Dictionary:
	var file:=FileAccess.open(file_path,FileAccess.READ)
	if file==null:
		return {"ok":false,"message":"尚无可加载的失败种子"}
	var parser:=JSON.new()
	var result:=parser.parse(file.get_as_text())
	file.close()
	var errors: Array[String]=["失败种子JSON损坏"] if result!=OK else validate(parser.data)
	return {"ok":errors.is_empty(),"value":parser.data if errors.is_empty() else {},"message":"已加载失败种子；连接前起跑是定位复盘，非逐帧录像" if errors.is_empty() else "；".join(errors)}
