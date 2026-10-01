extends Node2D
## Identity world transform. Read-only route metadata, no collision or RNG writes.
const GOLD := Color("ffd166")
const HEAL := Color("45dccb")
const MUTED := Color("78939e")
var _flow: Node
var _course: Node
var _font: Font
var _clock := 0.0
var _features: Array[Dictionary] = []
var _connections: Array[Dictionary] = []
var _phase := "menu"
var _skill_offer: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 1
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","Noto Sans CJK SC"])
	_font = font
	if is_instance_valid(_flow):
		bind_flow(_flow,_course)

func bind_flow(flow: Node, course: Node) -> void:
	_disconnect()
	_flow = flow
	_course = course
	_clock = 0
	_features.clear()
	_skill_offer.clear()
	if not is_node_ready():
		return
	for pair in [[course,"chunks_changed",_refresh],[flow,"world_shifted",_shifted]]:
		if pair[0].has_signal(pair[1]):
			pair[0].connect(pair[1],pair[2])
			_connections.append({"source":pair[0],"signal":pair[1],"callback":pair[2]})
	if flow.has_signal("skill_state_changed"):
		flow.connect("skill_state_changed",_on_skill)
		_connections.append({"source":flow,"signal":"skill_state_changed","callback":_on_skill})
	_refresh()

func _refresh() -> void:
	_features.clear()
	if not is_instance_valid(_course):
		return
	for chunk in _course.chunks:
		var d: Dictionary = chunk.get("geometry",{})
		if d.has("challenge") or d.has("station") or d.has("ground_segments"):
			_features.append({"id":chunk.id,"origin":chunk.origin,"geometry":d})
	queue_redraw()

func _shifted(_distance: float) -> void:
	_refresh()

func _process(delta: float) -> void:
	if not is_instance_valid(_flow):
		return
	_phase = str(_flow.phase)
	if _flow.has_method("current_skill_offer"):
		_skill_offer = _flow.current_skill_offer()
	visible = _phase in ["running","paused","recovering"] and _flow.is_endless()
	if visible and not get_tree().paused:
		_clock += delta
	queue_redraw()

func _on_skill(snapshot: Dictionary) -> void:
	_skill_offer = snapshot.duplicate(true)
	queue_redraw()

func _text(at: Vector2, label: String, color: Color, font_size: int = 14) -> void:
	draw_string(_font,at,label,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _hex(at: Vector2, index: int, activated: bool, next: bool, closed: bool) -> void:
	var polygon := PackedVector2Array()
	for point in 6:
		polygon.append(at+Vector2(cos(float(point)*TAU/6),sin(float(point)*TAU/6))*22)
	draw_colored_polygon(polygon,Color("13232d"))
	polygon.append(polygon[0])
	var tint: Color = GOLD if not closed or activated else MUTED
	draw_polyline(polygon,tint,2,true)
	if next and not closed:
		draw_arc(at,25,_clock*.8,_clock*.8+1.4,16,Color(1,.82,.4,.5),1.5,true)
	_text(at+Vector2(-6,7),str(index),tint,19)
	if activated:
		draw_polyline(PackedVector2Array([at+Vector2(9,-12),at+Vector2(12,-8),at+Vector2(18,-15)]),HEAL,2,true)

func _symbol(at: Vector2, kind: String, tint: Color, selected: bool = false, locked: bool = false) -> void:
	if kind == "heal":
		draw_circle(at,14,Color("142c32"))
		draw_arc(at,14,0,TAU,24,tint,1.5,true)
		draw_rect(Rect2(at-Vector2(3,9),Vector2(6,18)),tint)
		draw_rect(Rect2(at-Vector2(9,3),Vector2(18,6)),tint)
	else:
		var diamond := PackedVector2Array([at+Vector2(0,-14),at+Vector2(14,0),at+Vector2(0,14),at+Vector2(-14,0),at+Vector2(0,-14)])
		draw_colored_polygon(diamond,Color("252b2c"))
		draw_polyline(diamond,tint,1.5,true)
		for x in [-5,2]:
			for y in [-5,2]:
				draw_rect(Rect2(at+Vector2(x,y),Vector2(3,3)),tint)
	if selected:
		draw_polyline(PackedVector2Array([at+Vector2(10,-12),at+Vector2(14,-8),at+Vector2(20,-15)]),HEAL,2,true)
	elif locked:
		draw_rect(Rect2(at+Vector2(9,-16),Vector2(10,9)),MUTED)
		draw_arc(at+Vector2(14,-16),4,PI,TAU,10,MUTED,1.5,true)

func _draw() -> void:
	if _font == null or not is_instance_valid(_flow):
		return
	var state: Dictionary = _flow.routes.snapshot()
	var activated := {}
	for relay in _course.relays:
		if relay.activated:
			activated[relay.id] = true
	var inverse := get_global_transform_with_canvas().affine_inverse()
	var left: float = (inverse*Vector2.ZERO).x-260
	var right: float = (inverse*get_viewport_rect().size).x+260
	for feature in _features:
		var x: float = feature.origin
		if x+1280 < left or x > right:
			continue
		var d: Dictionary = feature.geometry
		if d.has("ground_segments"):
			_draw_spatial_routes(d,x)
		if d.has("skill") and bool(_flow.player.get("dash_enabled")):
			_draw_skill_entry(d,x)
		if d.has("challenge"):
			var challenge: Dictionary = d.challenge
			var entry: Rect2 = challenge.entry
			var first_y: float = 360
			for relay in d.relays:
				if relay.local_id == challenge.order[0]:
					first_y = relay.position.y
			var entry_at := Vector2(x+entry.position.x,first_y-50)
			_text(entry_at-Vector2(54,0),"连段入口",GOLD,14)
			draw_polyline(PackedVector2Array([entry_at+Vector2(-8,9),entry_at+Vector2(0,1),entry_at+Vector2(8,9)]),GOLD,2,true)
			for i in challenge.order.size():
				for relay in d.relays:
					if relay.local_id == challenge.order[i]:
						_hex(relay.position+Vector2(x,0),i+1,activated.has(feature.id+":"+relay.local_id),state.active==feature.id and int(state.progress)==i,_flow.routes.closed.has(feature.id))
			var exit_y: float = 330
			if d.has("ground_segments"):
				for relay in d.relays:
					if relay.local_id==challenge.order[-1]:
						exit_y=relay.position.y-42
			_text(Vector2(x+challenge.exit_x-15,exit_y),"出口结算",GOLD,13)
			_text(Vector2(x+challenge.exit_x-15,exit_y+19),"+%d 连段" % int(challenge.bonus),GOLD,13)
		if d.has("station"):
			var station: Dictionary = d.station
			# Keep the advance sign below the threat HUD when the camera follows a valley.
			var card_y: float = (inverse*Vector2(0,240)).y
			var selected: String = str(_flow.routes.stations.get(feature.id,""))
			var full: bool = _flow.player.health >= 3
			var card := StyleBoxFlat.new()
			card.bg_color = Color(.05,.09,.13,.96)
			card.border_color = HEAL if selected.is_empty() else MUTED
			card.set_border_width_all(1)
			card.set_corner_radius_all(5)
			draw_style_box(card,Rect2(x+40,card_y,224,96))
			_text(Vector2(x+52,card_y+21),"恢复站 · 选一路" if selected.is_empty() else "恢复站 · 已选择",Color("e6efed"),16)
			for kind in ["heal","score"]:
				var locked: bool = not selected.is_empty() and selected != kind
				var tint: Color = MUTED if locked else (HEAL if kind=="heal" else GOLD)
				var line_y: float = card_y+46 if kind=="heal" else card_y+76
				var label: String = ("生命已满" if full else "补血 +1") if kind=="heal" else "积分 +%d" % int(station.bonus)
				if not selected.is_empty():
					label = "已选补血" if kind=="heal" and selected==kind else ("已选积分" if selected==kind else "本站已选择")
				_symbol(Vector2(x+69,line_y-5),kind,tint,selected==kind,locked)
				_text(Vector2(x+92,line_y),label,tint,15)
				_symbol(station[kind]+Vector2(x,0),kind,tint,selected==kind,locked)
	_draw_skill_offer()

func presentation_state() -> Dictionary:
	return {"animation_time":_clock,"features":_features.size(),"phase":_phase,"visible":visible,"feature_ids":_features.map(func(row):return row.id),"skill_offer":_skill_offer.duplicate(true),"skill_rect":Rect2(270,128,390,58) if not _skill_offer.is_empty() else Rect2(),"skill_lines":_skill_lines()}

func _skill_lines() -> Array[String]:
	if _skill_offer.is_empty():
		return []
	var kind: String = str(_skill_offer.get("kind",""))
	var title: String = str({"shortcut":"冲刺捷径","relay":"空中接力","rescue":"紧急脱险"}.get(kind,"技能路线"))
	var required: int = int(_skill_offer.get("required",0))
	var first: String = title + " · 入口需 %d 次" % required
	if bool(_skill_offer.get("active",false)):
		first = title + " · 接力中 · 路径用 %d 次" % int(_skill_offer.get("dash_cost",0))
	elif required == 0:
		first = title + (" · 正常跳跃 / 冲刺救场" if int(_skill_offer.get("charges",0))>0 else " · 正常跳跃 · 冲刺需储备")
	elif not bool(_skill_offer.get("available",false)):
		first = title + " · 冲刺不足 · 走主路"
	var second: String = "中继 %d · 最多补 %d 次（容量允许） · 主路需跳跃" % [int(_skill_offer.get("reward_nodes",0)),int(_skill_offer.get("expected_refill",0))]
	return [first,second]

func _draw_skill_offer() -> void:
	var lines: Array[String] = _skill_lines()
	if lines.is_empty():
		return
	var transform := get_global_transform_with_canvas()
	var at: Vector2 = transform.affine_inverse()*Vector2(270,128)
	var enough: bool = bool(_skill_offer.get("available",false)) or bool(_skill_offer.get("active",false))
	var tint: Color = HEAL if enough else GOLD
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(.05,.09,.13,.95)
	panel.border_color = tint
	panel.border_width_left = 2
	panel.border_width_bottom = 1
	panel.set_corner_radius_all(4)
	draw_style_box(panel,Rect2(at,Vector2(390,58)))
	_text(at+Vector2(10,21),lines[0],tint,14)
	_text(at+Vector2(10,43),lines[1],Color("9bb5ba"),12)

func _draw_skill_entry(d: Dictionary,x: float) -> void:
	var skill: Dictionary = d.skill
	var entry_y: float = float(d.connection.entry_y)
	if not d.get("platforms",[]).is_empty():
		entry_y = float(d.platforms[0].position.y)
	var at := Vector2(x+float(skill.entry_x),entry_y-24)
	# Small physical entry pointer. It does not connect platforms or promise a landing.
	var tint: Color = HEAL
	if _flow.player.dash_charges < int(skill.required):
		tint = MUTED
	draw_polyline(PackedVector2Array([at+Vector2(-9,4),at,at+Vector2(-9,-4)]),tint,1.5,true)
	draw_polyline(PackedVector2Array([at+Vector2(-18,4),at+Vector2(-9,0),at+Vector2(-18,-4)]),tint,1.5,true)

func _direction(at: Vector2,title: String,color: Color,down: bool = false) -> void:
	# Keep auxiliary route words above bottom HUD and below top/status cards.
	var transform := get_global_transform_with_canvas()
	var screen_at: Vector2 = transform*at
	screen_at.y=clampf(screen_at.y,148,426)
	if screen_at.x>660 and screen_at.y<294:
		screen_at.y=314
	at=transform.affine_inverse()*screen_at
	_text(at,title,color,13)
	var tilt: float = 4 if down else -4
	draw_polyline(PackedVector2Array([at+Vector2(0,10),at+Vector2(24,10+tilt),at+Vector2(18,5+tilt)]),color,1.5,true)

func _draw_spatial_routes(d: Dictionary,x: float) -> void:
	var connection: Dictionary = d.connection
	if connection.upper_from:
		_direction(Vector2(x+40,connection.upper_entry_y-58),"高路延续" if connection.upper_to else "高路 · 前方汇回",GOLD)
		_direction(Vector2(x+40,connection.entry_y-44),"主路",MUTED)
		if not connection.upper_to:
			for route in d.routes:
				if route.kind=="merge":
					_direction(Vector2(x+route.from.x-36,route.from.y-58),"汇回主路",MUTED,true)
	elif not d.has("challenge") and not d.has("station"):
		for route in d.routes:
			if route.kind=="upper":
				_direction(Vector2(x+route.from.x-48,route.from.y-62),"高路入口",GOLD)
				break
		if str(d.spatial_id)=="bridge":
			_direction(Vector2(x+232,connection.entry_y-62),"断桥 · 接续",MUTED)

func station_presentation(id: String) -> Dictionary:
	for feature in _features:
		if feature.id==id and feature.geometry.has("station"):
			var transform := get_global_transform_with_canvas()
			var inverse := transform.affine_inverse()
			var top_y: float = (inverse*Vector2(0,240)).y
			return {"preview_rect":Rect2(transform*Vector2(feature.origin+40,top_y),Vector2(224,96)),"selected":str(_flow.routes.stations.get(id,"")),"full":_flow.player.health>=3,"heal_canvas":transform*(feature.geometry.station.heal+Vector2(feature.origin,0)),"score_canvas":transform*(feature.geometry.station.score+Vector2(feature.origin,0))}
	return {}

func _disconnect() -> void:
	for connection in _connections:
		if is_instance_valid(connection.source) and connection.source.is_connected(connection.signal,connection.callback):
			connection.source.disconnect(connection.signal,connection.callback)
	_connections.clear()

func _exit_tree() -> void:
	_disconnect()
