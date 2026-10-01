extends RefCounted
## Real collision and preview share these bounded, local-coordinate surfaces.
const Vertical = preload("res://scripts/level/vertical_library.gd")
const NAMES := {"slope":"坡地连跳","terrace":"高台跨越","bridge":"断桥接续","basin":"下沉回升"}
static func surface(d: Dictionary,a: Vector2,b: Vector2) -> void:
	if b.x<=a.x:
		return
	d.ground_segments.append({"from":a,"to":b})
	d.routes.append({"from":a,"to":b,"kind":"primary"})
	if is_equal_approx(a.y,b.y):
		d.floors.append(Rect2(a.x,a.y,b.x-a.x,640-a.y))
	else:
		d.polygons.append(PackedVector2Array([a,b,Vector2(b.x,640),Vector2(a.x,640)]))
static func window(d: Dictionary,a: Vector2,b: Vector2,width: float,kind: String) -> void:
	if (b.y>a.y and b.x<=a.x+48) or (is_equal_approx(b.y,a.y) and b.x<=a.x):
		return
	d.jump_windows.append({"takeoff":Rect2(a.x-104,a.y-8,80,16),"landing":Rect2(b.x+12,b.y-6,maxf(width-24,24),12),"from":a,"to":b,"kind":kind})
static func platform(d: Dictionary,rect: Rect2,kind: String = "upper") -> void:
	d.platforms.append(rect)
	d.routes.append({"from":rect.position,"to":Vector2(rect.end.x,rect.position.y),"kind":kind})
static func empty(id: String,entry: float,exit: float,h: float,gap: float) -> Dictionary:
	var d := Vertical.build("safe_a")
	d.floors=[]
	d.walls=[]
	d.platforms=[]
	d.gaps=[]
	d.spikes=[]
	d.relays=[]
	d.routes=[]
	d.polygons=[]
	d.ground_segments=[]
	d.jump_windows=[]
	d.vertical=true
	d.spatial_id=id
	d.structure=NAMES.get(id,id)
	d.parameters={"height":h,"spacing":gap,"entry_y":entry,"exit_y":exit}
	d.connection={"entry_y":entry,"exit_y":exit,"upper_entry_y":-1.0,"upper_exit_y":-1.0,"upper_from":false,"upper_to":false,"chain_id":""}
	d.zone="下沉区" if id=="basin" else ("高架区" if id in ["terrace","bridge"] else "坡地区")
	d.validation="有界空间候选；实际动作验收见版本报告，预览非实时模拟"
	return d
static func build(id: String,entry: float,exit: float,h: float,gap: float,variant: int = 0) -> Dictionary:
	var d := empty(id,entry,exit,h,gap)
	d.variant=variant
	match id:
		"slope":
			var middle:=clampf((entry+exit)/2+(-32 if variant%2==0 else 32),384,544)
			var points:=[Vector2(0,entry),Vector2(192,entry),Vector2(576,middle),Vector2(768,middle),Vector2(1088,exit),Vector2(1280,exit)]
			for i in points.size()-1:
				surface(d,points[i],points[i+1])
			# Optional low perches add jumps while the sloped primary route stays open.
			platform(d,Rect2(384,middle-32,192,20))
			platform(d,Rect2(688,middle-64,192,20))
			window(d,Vector2(304,middle),Vector2(384,middle-32),192,"upper")
			window(d,Vector2(576,middle-32),Vector2(688,middle-64),192,"upper")
		"terrace":
			var crest:=minf(entry,exit)-h
			surface(d,Vector2(0,entry),Vector2(288,entry))
			surface(d,Vector2(288,crest),Vector2(576,crest))
			surface(d,Vector2(576,crest),Vector2(1088,exit))
			surface(d,Vector2(1088,exit),Vector2(1280,exit))
			window(d,Vector2(288,entry),Vector2(288,crest),288,"primary")
		"bridge":
			# First perch's rise is limited; end height changes only after the bridge.
			var y:=entry-h
			surface(d,Vector2(0,entry),Vector2(352,entry))
			platform(d,Rect2(352+gap,y,256,24),"primary")
			platform(d,Rect2(704+gap/2,y,256,24),"primary")
			surface(d,Vector2(1008,entry),Vector2(1088,entry))
			surface(d,Vector2(1088,entry),Vector2(1280,exit))
			d.gaps=[Rect2(352,entry,656,92)]
			window(d,Vector2(352,entry),Vector2(352+gap,y),256,"primary")
			window(d,Vector2(608+gap,y),Vector2(704+gap/2,y),256,"primary")
			window(d,Vector2(960+gap/2,y),Vector2(1008,entry),80,"primary")
		"basin":
			var lower:=minf(544,maxf(entry,exit)+h)
			var points:=[Vector2(0,entry),Vector2(160,entry),Vector2(576,lower),Vector2(704,lower),Vector2(1120,exit),Vector2(1280,exit)]
			for i in points.size()-1:
				surface(d,points[i],points[i+1])
			platform(d,Rect2(448,lower-48,256,20))
			window(d,Vector2(352,lower-32),Vector2(448,lower-48),256,"upper")
	return d
static func reward_segment(original: Dictionary,entry: float) -> Dictionary:
	var d:=empty("slope",entry,entry,original.parameters.height,original.parameters.spacing)
	d.structure=original.structure
	d.zone="高架区" if original.has("challenge") else "恢复区"
	d.platforms=original.platforms.duplicate()
	for i in d.platforms.size():
		d.platforms[i].position.y+=entry-448
		var r: Rect2=d.platforms[i]
		d.routes.append({"from":r.position,"to":Vector2(r.end.x,r.position.y),"kind":"upper"})
	for relay in original.relays:
		var node: Dictionary=relay.duplicate(true)
		node.position.y+=entry-448
		d.relays.append(node)
	if original.has("challenge"):
		d.challenge=original.challenge.duplicate(true)
		d.challenge.entry.size.y+=entry-448
		d.challenge.lower.position.y+=entry-448
	if original.has("station"):
		d.station=original.station.duplicate(true)
		d.station.heal.y+=entry-448
		d.station.score.y+=entry-448
	surface(d,Vector2(0,entry),Vector2(1280,entry))
	var previous:=Vector2(288,entry)
	for r in d.platforms:
		window(d,previous,r.position,r.size.x,"upper")
		previous=Vector2(r.end.x,r.position.y)
	return d
static func extend_upper(d: Dictionary,y: float,from_previous: bool,to_next: bool,chain: String) -> void:
	d.connection.upper_from=from_previous
	d.connection.upper_to=to_next
	d.connection.upper_entry_y=y if from_previous else -1.0
	d.connection.upper_exit_y=y if to_next else -1.0
	d.connection.chain_id=chain
	if from_previous:
		# Real one-way surfaces meet exactly at the streaming seam.
		platform(d,Rect2(0,y,256,20))
		platform(d,Rect2(320,y-32,256,20))
		platform(d,Rect2(640,y,320,20))
		window(d,Vector2(256,y),Vector2(320,y-32),256,"upper")
		window(d,Vector2(576,y-32),Vector2(640,y),320,"upper")
	if to_next:
		platform(d,Rect2(960,y,320,20))
	else:
		d.routes.append({"from":Vector2(960,y),"to":Vector2(1184,d.connection.exit_y),"kind":"merge"})
	d.zone="高架区"
static func ground_y(d: Dictionary,x: float) -> float:
	for segment in d.get("ground_segments",[]):
		var a: Vector2=segment.from
		var b: Vector2=segment.to
		if x>=a.x and x<=b.x:
			return lerpf(a.y,b.y,(x-a.x)/(b.x-a.x))
	return NAN
static func errors(d: Dictionary) -> Array[String]:
	var issues: Array[String]=[]
	for segment in d.get("ground_segments",[]):
		var a: Vector2=segment.from
		var b: Vector2=segment.to
		if b.x<=a.x or absf((b.y-a.y)/(b.x-a.x))>0.35 or minf(a.y,b.y)<320 or maxf(a.y,b.y)>544:
			issues.append("坡面/高度包络超限")
	if d.spatial_id!="bridge":
		for i in range(1,d.ground_segments.size()):
			var a: Vector2=d.ground_segments[i-1].to
			var b: Vector2=d.ground_segments[i].from
			if a.x!=b.x or absf(a.y-b.y)>64:
				issues.append("主路内部连接不连续或阶差超限")
	for r in d.platforms:
		if r.size.x<160 or r.position.y<192 or r.position.y>544:
			issues.append("落脚平台包络超限")
	if not is_equal_approx(ground_y(d,0),d.connection.entry_y) or not is_equal_approx(ground_y(d,1280),d.connection.exit_y):
		issues.append("主路入口/出口不匹配")
	return issues
