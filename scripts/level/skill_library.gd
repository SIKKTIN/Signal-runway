extends RefCounted
const Spatial=preload("res://scripts/level/spatial_library.gd")
const NAMES={"shortcut":"冲刺捷径","relay":"空中接力","rescue":"紧急脱险"}
static func build(kind: String,entry: float=448,h: float=48,bonus: int=200) -> Dictionary:
	var d:=Spatial.empty("slope",entry,entry,h,80)
	d.category="relay"
	d.difficulty=1
	d.structure=NAMES[kind]
	d.segment_role="分路"
	if kind=="rescue":
		d.spatial_id="bridge"
		Spatial.surface(d,Vector2(0,entry),Vector2(480,entry))
		Spatial.surface(d,Vector2(608,entry),Vector2(1280,entry))
		d.gaps=[Rect2(480,entry,128,640-entry)]
		Spatial.window(d,Vector2(480,entry),Vector2(608,entry),672,"primary")
		d.relays=[{"local_id":"supply_1","position":Vector2(240,entry-34)},{"local_id":"supply_2","position":Vector2(400,entry-34)},{"local_id":"rescue","position":Vector2(832,entry-34)}]
		d.skill={"kind":kind,"required":0,"entry_x":240.0,"reward_nodes":3,"stable":true,"dash_windows":[{"takeoff_x":476.0,"dash_x":528.0,"from":Vector2(480,entry),"to":Vector2(608,entry),"kind":"rescue"}]}
		return d
	Spatial.surface(d,Vector2(0,entry),Vector2(1280,entry))
	var p: Array[Rect2]
	if kind=="relay":
		p.assign([Rect2(224,entry-h,160,20),Rect2(672,entry-h-32,160,20),Rect2(1120,entry-h-64,160,20)])
	else:
		p.assign([Rect2(320,entry-h,160,20),Rect2(768,entry-h-32,192,20),Rect2(1024,entry-h,256,20)])
	# Leave enough runway to land on the first 160-unit perch at all three speeds.
	var previous:=Vector2(p[0].position.x-80,entry)
	var dash_windows: Array[Dictionary]=[]
	for i in p.size():
		var rect:=p[i]
		Spatial.platform(d,rect)
		Spatial.window(d,previous,rect.position,rect.size.x,"skill" if i>0 and rect.position.x-previous.x>200 else "upper")
		if i>0 and rect.position.x-previous.x>200:
			dash_windows.append({"takeoff_x":previous.x-4,"dash_x":previous.x+70,"from":previous,"to":rect.position,"kind":"skill"})
		var node_x:=rect.end.x-48 if kind=="shortcut" and i==2 else rect.get_center().x
		d.relays.append({"local_id":"challenge_%d"%(i+1),"position":Vector2(node_x,rect.position.y-34)})
		previous=Vector2(rect.end.x,rect.position.y)
	d.relays.append({"local_id":"low","position":Vector2(1080,entry-34)})
	d.challenge={"entry":Rect2(p[0].position.x-112,0,96,p[0].position.y-10),"lower":Rect2(p[0].position.x+30,entry-38,1280-p[0].position.x-30,110),"exit_x":1270.0,"order":["challenge_1","challenge_2","challenge_3"],"bonus":bonus}
	d.skill={"kind":kind,"required":1,"dash_cost":2 if kind=="relay" else 1,"expected_refill":1,"entry_x":float(p[0].position.x-128),"reward_nodes":3,"stable":true,"dash_windows":dash_windows}
	d.zone="高架区"
	return d
static func prototype_row(kind: String,index: int) -> Dictionary:
	var d: Dictionary
	if index==1:
		d=build(kind)
	else:
		d=Spatial.empty("slope",448,448,32,80)
		Spatial.surface(d,Vector2(0,448),Vector2(1280,448))
		d.structure="原型起跑区" if index==0 else "原型完成区"
		d.category="safe"
		d.difficulty=0
	return {"index":index,"length":1280,"template_id":"safe_a","stage":0,"geometry":d,"segment_role":"分路" if index==1 else "缓和"}
