extends RefCounted
const Profile=preload("res://scripts/level/generation_profile.gd")
const Spatial=preload("res://scripts/level/spatial_library.gd")
var base: RefCounted
var profile: Dictionary
var rng:=RandomNumberGenerator.new()
var ground:=448.0
var remaining:=0
var upper_y:=400.0
var chain:=""
func reset(seed_value: int,settings: Dictionary) -> void:
	profile=settings.duplicate(true)
	base=load("res://scripts/level/rhythm_generator.gd").new()
	var old:=Profile.v06_defaults()
	for key in old:
		if key!="generator_revision":
			old[key]=profile[key]
	base.reset(seed_value,old)
	rng.seed=absi((str(seed_value)+":spatial5").hash())
	ground=448
	remaining=0
	chain=""
func next() -> Dictionary:
	var row: Dictionary=base.next()
	var original: Dictionary=row.geometry
	var entry:=ground
	var next_height:=clampf(entry+rng.randi_range(-1,1)*profile.elevation_step,448-profile.elevation_range,448+profile.elevation_range)
	var h:=rng.randi_range(profile.height_min/16,profile.height_max/16)*16
	var gap:=rng.randi_range(profile.gap_min/16,profile.gap_max/16)*16
	var d: Dictionary
	var candidates: Array[String]=[]
	var id:="slope"
	if row.index<2:
		next_height=448
		d=Spatial.empty("slope",448,448,32,80)
		Spatial.surface(d,Vector2.ZERO+Vector2(0,448),Vector2(1280,448))
		d.structure="开局安全连接"
	elif original.has("challenge") or original.has("station"):
		next_height=entry
		d=Spatial.reward_segment(original,entry)
		if original.has("challenge"):
			remaining=mini(int(profile.upper_span)-1,maxi(0,int(row.next_station)-int(row.index)-2))
			upper_y=entry-float(original.parameters.height)
			chain=str(row.index)
			if remaining>0:
				Spatial.extend_upper(d,upper_y,false,true,chain)
		else:
			remaining=0
	elif remaining>0:
		next_height=entry
		d=Spatial.empty("slope",entry,entry,32,80)
		Spatial.surface(d,Vector2(0,entry),Vector2(1280,entry))
		# Corridor has its own upper chain; don't overlap optional slope perches.
		d.platforms.clear()
		d.routes=d.routes.filter(func(r):return r.kind=="primary")
		d.jump_windows.clear()
		remaining-=1
		Spatial.extend_upper(d,upper_y,true,remaining>0,chain)
		d.structure="高路延续" if remaining>0 else "高路汇回"
	else:
		var total:=0.0
		for shape in Spatial.NAMES:
			if profile.spatial_weights[shape]>0 and (row.segment_role=="挑战" or shape in ["slope","basin"]):
				candidates.append(shape)
				total+=float(profile.spatial_weights[shape])*(1+row.stage if shape in ["terrace","bridge"] else 1)
		var choice:=rng.randf()*total
		for shape in candidates:
			choice-=float(profile.spatial_weights[shape])*(1+row.stage if shape in ["terrace","bridge"] else 1)
			id=shape
			if choice<=0:
				break
		# A terrace's first rise remains <=64 even with a rising outgoing seam.
		if id=="terrace":
			next_height=maxf(entry,next_height)
		if id=="bridge":
			next_height=clampf(next_height,entry-64,entry+64)
		d=Spatial.build(id,entry,next_height,h,gap,int(row.index))
		if row.category=="relay":
			d.relays=[{"local_id":"low","position":Vector2(1120,Spatial.ground_y(d,1120)-38)}]
	var problems:=Spatial.errors(d)
	if not problems.is_empty():
		next_height=entry
		d=Spatial.build("slope",entry,entry,32,80,int(row.index))
		remaining=0
		row.reason="安全兜底："+"；".join(problems)
		if row.category=="relay":
			d.relays=[{"local_id":"low","position":Vector2(1120,Spatial.ground_y(d,1120)-38)}]
	d.category=row.category
	d.difficulty=row.difficulty
	d.segment_role=row.segment_role
	d.phase=row.stage
	row.spatial_candidates=candidates
	row.reason+=" · 空间："+d.structure+" · 入口%.0f/出口%.0f"%[entry,next_height]
	row.geometry=d
	ground=next_height
	return row
