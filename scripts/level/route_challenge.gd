extends RefCounted
## Per-run, bounded identities. All positions passed here are global world coordinates.
var active := ""
var progress := 0
var closed: Dictionary = {}
var stations: Dictionary = {}
var completed := 0
var interrupted := 0
var heal_choices := 0
var score_choices := 0
var combo_score := 0
var station_score := 0
var last_event := ""
var events: Array[Dictionary] = []
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _chunk: Dictionary = {}
func reset() -> void:
	active=""
	progress=0
	closed.clear()
	stations.clear()
	completed=0
	interrupted=0
	heal_choices=0
	score_choices=0
	combo_score=0
	station_score=0
	last_event=""
	events.clear()
func interrupt(reason: String) -> void:
	if active.is_empty():
		return
	closed[active]=true
	interrupted+=1
	push_event("interrupted",{"id":active,"reason":reason})
	active=""
	progress=0
func push_event(kind: String, data: Dictionary = {}) -> void:
	last_event=kind
	events.append({"kind":kind,"data":data})
func begin_step(from: Vector2,to: Vector2,chunks: Array, offset: float, damaged: bool) -> void:
	_from=from
	_to=to
	var live := {}
	for chunk in chunks:
		live[chunk.id]=true
	for id in closed.keys():
		if not live.has(id):
			closed.erase(id)
	for id in stations.keys():
		if not live.has(id):
			stations.erase(id)
	if not active.is_empty() and not live.has(active):
		interrupt("retired")
	for chunk in chunks:
		if closed.has(chunk.id) or not chunk.get("geometry",{}).has("challenge"):
			continue
		var c: Dictionary=chunk.geometry.challenge
		var rect: Rect2=c.entry
		rect.position.x+=chunk.origin+offset
		if segment_entry(from,to,rect)>=0 and active.is_empty():
			if damaged:
				closed[chunk.id]=true
				continue
			active=chunk.id
			_chunk={"id":chunk.id,"origin":chunk.origin+offset,"challenge":c,"relays":chunk.geometry.relays}
			progress=0
			push_event("started",{"id":active})
func node(relay_id: String) -> void:
	if active.is_empty() or not relay_id.begins_with(active+":"):
		return
	var local_id:=relay_id.trim_prefix(active+":")
	var order: Array=_chunk.challenge.order
	if progress<order.size() and local_id==order[progress]:
		progress+=1
		push_event("progress",{"id":active,"progress":progress,"total":order.size()})
	elif local_id in order:
		interrupt("order")
func end_step(chunks: Array,offset: float,health: int) -> Array[Dictionary]:
	var choices: Array[Dictionary]=[]
	if not active.is_empty():
		var c: Dictionary=_chunk.challenge
		var local_to:=_to-Vector2(_chunk.origin,0)
		if local_to.x>=c.exit_x:
			if progress==c.order.size():
				completed+=1
				combo_score+=int(c.bonus)
				closed[active]=true
				push_event("completed",{"id":active,"bonus":c.bonus})
				active=""
				progress=0
			else:
				interrupt("missed")
		elif segment_entry(_from-Vector2(_chunk.origin,0),local_to,c.lower)>=0:
			interrupt("lower")
		elif progress<c.order.size():
			for reward in _chunk.relays:
				if reward.local_id==c.order[progress] and local_to.x>reward.position.x+26:
					interrupt("missed")
					break
	for chunk in chunks:
		if stations.has(chunk.id) or not chunk.geometry.has("station"):
			continue
		var station: Dictionary=chunk.geometry.station
		var picked:=""
		var first:=2.0
		for kind in ["heal","score"]:
			var point: Vector2=station[kind]+Vector2(chunk.origin+offset,0)
			var t:=segment_entry(_from,_to,Rect2(point-Vector2(26,20),Vector2(52,40)))
			if t>=0 and t<first:
				first=t
				picked=kind
		if picked.is_empty():
			continue
		stations[chunk.id]=picked
		if picked=="heal":
			heal_choices+=1
		else:
			score_choices+=1
			station_score+=int(station.bonus)
		var action:={"id":chunk.id,"kind":picked,"amount":1 if picked=="heal" and health<3 else (int(station.bonus) if picked=="score" else 0)}
		choices.append(action)
		push_event("station",action)
	return choices
static func segment_entry(a: Vector2,b: Vector2,rect: Rect2) -> float:
	var enter:=0.0
	var leave:=1.0
	var move:=b-a
	for axis in 2:
		if absf(move[axis])<0.00001:
			if a[axis]<rect.position[axis] or a[axis]>rect.end[axis]:
				return -1
		else:
			var t0: float=(rect.position[axis]-a[axis])/move[axis]
			var t1: float=(rect.end[axis]-a[axis])/move[axis]
			enter=maxf(enter,minf(t0,t1))
			leave=minf(leave,maxf(t0,t1))
			if enter>leave:
				return -1
	return enter
func snapshot() -> Dictionary:
	return {"active":active,"progress":progress,"total":3,"completed":completed,"interrupted":interrupted,"combo_score":combo_score,"station_score":station_score,"heal_choices":heal_choices,"score_choices":score_choices,"last_event":last_event,"identities":closed.size()+stations.size()}
