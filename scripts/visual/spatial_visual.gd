extends Node2D
## Read-only geometry decoration. Identity transform, live chunks only.
class SurfaceDetails extends Node2D:
	var painter: Callable
	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)

var _flow: Node
var _course: Node
var _chunks: Array[Dictionary] = []
var _connections: Array[Dictionary] = []
var _details: Node2D
var _clock := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = -1
	_details = SurfaceDetails.new()
	_details.name = "SurfaceDetails"
	_details.z_index = 2
	_details.painter = _paint_surfaces
	add_child(_details)
	if is_instance_valid(_flow):
		bind_flow(_flow,_course)

func bind_flow(flow: Node, course: Node) -> void:
	_disconnect()
	_flow = flow
	_course = course
	_clock = 0.0
	_chunks.clear()
	if not is_node_ready():
		return
	for pair in [[course,"chunks_changed",_refresh],[flow,"world_shifted",_shifted]]:
		if pair[0].has_signal(pair[1]):
			pair[0].connect(pair[1],pair[2])
			_connections.append({"source":pair[0],"signal":pair[1],"callback":pair[2]})
	_refresh()

func _refresh() -> void:
	_chunks.clear()
	if is_instance_valid(_course):
		for chunk in _course.chunks:
			if chunk.get("geometry",{}).has("ground_segments"):
				_chunks.append({"id":chunk.id,"origin":chunk.origin,"length":chunk.length,"geometry":chunk.geometry})
	queue_redraw()
	if is_instance_valid(_details):
		_details.queue_redraw()

func _shifted(_distance: float) -> void:
	_refresh()

func _process(delta: float) -> void:
	if not is_instance_valid(_flow):
		return
	var phase: String = str(_flow.phase)
	visible = _flow.is_endless() and phase in ["running","paused","recovering"]
	if visible and not get_tree().paused and phase != "paused":
		_clock += delta
	queue_redraw()
	_details.queue_redraw()

func _view() -> Rect2:
	var inverse := get_global_transform_with_canvas().affine_inverse()
	var a: Vector2 = inverse*Vector2.ZERO
	var b: Vector2 = inverse*get_viewport_rect().size
	return Rect2(a,b-a).grow(96)

static func ground_y(d: Dictionary,x: float) -> float:
	for segment in d.get("ground_segments",[]):
		var a: Vector2 = segment.from
		var b: Vector2 = segment.to
		if x>=a.x and x<=b.x:
			return lerpf(a.y,b.y,(x-a.x)/(b.x-a.x))
	return NAN

func _draw() -> void:
	var view: Rect2 = _view()
	for chunk in _chunks:
		var origin: float = chunk.origin
		if origin>view.end.x or origin+chunk.length<view.position.x:
			continue
		var d: Dictionary = chunk.geometry
		for rect in d.get("platforms",[]):
			var start: float = rect.position.x+8
			var end: float = rect.end.x-8
			var y: float = rect.end.y+4
			# Each short truss stays under its own real platform, never across a gap.
			var depth: float = 20 if str(d.spatial_id)=="bridge" else 16
			var bottom: float = y+depth
			draw_colored_polygon(PackedVector2Array([Vector2(origin+start,y),Vector2(origin+end,y),Vector2(origin+end-8,bottom),Vector2(origin+start+8,bottom)]),Color(.11,.18,.22,.58))
			for x in range(int(start)+4,int(end)-28,48):
				draw_polyline(PackedVector2Array([Vector2(origin+x,y+3),Vector2(origin+x+20,bottom-3),Vector2(origin+x+40,y+3)]),Color(.22,.35,.39,.42),1.5,true)
			# Dim posts behind the player end at existing main ground. No posts over void.
			for x in [start+24,end-24]:
				var floor_y: float = ground_y(d,x)
				if is_finite(floor_y) and floor_y>bottom+14:
					draw_rect(Rect2(origin+x-3,bottom,6,floor_y-bottom-4),Color(.12,.21,.25,.48))
					draw_line(Vector2(origin+x+3,bottom),Vector2(origin+x+3,floor_y-4),Color(.25,.38,.41,.24),1)

func _paint_surfaces(canvas: Node2D) -> void:
	var view: Rect2 = _view()
	for chunk in _chunks:
		var origin: float = chunk.origin
		if origin>view.end.x or origin+chunk.length<view.position.x:
			continue
		var d: Dictionary = chunk.geometry
		for segment in d.ground_segments:
			var a: Vector2 = segment.from
			var b: Vector2 = segment.to
			if is_equal_approx(a.y,b.y):
				continue
			# Side-panel bands are wholly inside the actual polygon, below its white top.
			var offset:=Vector2(origin,0)
			canvas.draw_colored_polygon(PackedVector2Array([a+offset+Vector2(0,9),b+offset+Vector2(0,9),b+offset+Vector2(0,29),a+offset+Vector2(0,29)]),Color(.11,.19,.24,.60))
			var first: int = int(ceil((origin+a.x+12)/72.0))
			var last: int = int(floor((origin+b.x-26)/72.0))
			for index in range(first,last+1):
				var x: float = index*72.0-origin
				var y: float = lerpf(a.y,b.y,(x-a.x)/(b.x-a.x))
				canvas.draw_line(Vector2(origin+x,y+37),Vector2(origin+x+16,y+49),Color(.27,.37,.42,.60),1.5,true)
				canvas.draw_circle(Vector2(origin+x,y+18),1.4,Color(.45,.55,.57,.50))

func presentation_state() -> Dictionary:
	return {"animation_time":_clock,"visible":visible,"chunks":_chunks.size(),"ids":_chunks.map(func(row):return row.id),"origins":_chunks.map(func(row):return row.origin),"zones":_chunks.map(func(row):return row.geometry.zone),"structures":_chunks.map(func(row):return row.geometry.spatial_id)}

func _disconnect() -> void:
	for connection in _connections:
		if is_instance_valid(connection.source) and connection.source.is_connected(connection.signal,connection.callback):
			connection.source.disconnect(connection.signal,connection.callback)
	_connections.clear()

func _exit_tree() -> void:
	_disconnect()
