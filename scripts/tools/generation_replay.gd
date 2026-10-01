extends RefCounted
const Profile=preload("res://scripts/level/generation_profile.gd")
const DEFAULT_PATH="user://map_editor_failure_v08.json"
const V07_PATH="user://map_editor_failure_v07.json"
static func make(seed_value: int,profile: Dictionary,global_x: float,reason: String,dash_state: Dictionary={}) -> Dictionary:
	var value:={"schema":1,"seed":seed_value,"profile":profile.duplicate(true),"fingerprint":Profile.fingerprint(profile),"failed_x":maxf(96,global_x),"reason":reason,"created_at":Time.get_datetime_string_from_system(true)}
	if not dash_state.is_empty() and profile.generator_revision==6:
		value.schema=2
		value.dash={"charges":int(dash_state.get("charges",1)),"progress":int(dash_state.get("progress",0))}
	return value
static func validate(value: Variant) -> Array[String]:
	if not value is Dictionary or (value.get("schema")!=1 and value.get("schema")!=2) or value.size()!=(8 if value.get("schema")==2 else 7) or not value.get("reason") is String or not value.get("created_at") is String:
		return ["失败种子文件格式无效"]
	if value.schema==2:
		if not value.get("dash") is Dictionary or value.dash.size()!=2:
			return ["失败资源快照格式无效"]
		for spec in [["charges",0,2],["progress",0,1]]:
			var v: Variant=value.dash.get(spec[0])
			if not (v is int or v is float) or not is_finite(float(v)) or floor(float(v))!=v or v<spec[1] or v>spec[2]:
				return ["失败资源快照超范围"]
		if value.dash.charges==2 and value.dash.progress!=0:
			return ["满储备不能携带隐藏充能进度"]
	var seed: Variant=value.get("seed")
	var x: Variant=value.get("failed_x")
	if not (seed is int or seed is float) or not is_finite(float(seed)) or seed<0 or seed>2147483647 or floor(float(seed))!=seed or not (x is int or x is float) or not is_finite(float(x)) or x<96 or x>1.0e9:
		return ["种子或失败位置超范围"]
	var errors:=Profile.validate(value.get("profile"))
	if errors.is_empty() and value.schema==2 and value.profile.generator_revision!=6:
		errors.append("资源快照仅用于生成6")
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
