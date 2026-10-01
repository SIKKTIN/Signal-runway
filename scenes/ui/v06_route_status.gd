extends Control
## Read-only event/snapshot display. Root rebuilds this instance per run.
@export var enable_event_audio := true
var _flow: Node
var _font: Font
var _sound: AudioStreamPlayer
var _snapshot := {"active":"","progress":0,"total":3}
var _connections: Array[Dictionary] = []
var _seen: Array[String] = []
var _clock := 0.0
var _remaining := 0.0
var _message := ""
var _kind := ""
var _color := Color("ffd166")
var _sound_triggers := 0
var _event_count := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","Noto Sans CJK SC"])
	_font = font
	_sound = AudioStreamPlayer.new()
	_sound.name = "RouteEventCue"
	_sound.volume_db = -6
	if AudioServer.get_bus_index("SFX") >= 0:
		_sound.bus = "SFX"
	add_child(_sound)
	if is_instance_valid(_flow):
		bind_flow(_flow)

func bind_flow(flow: Node) -> void:
	_disconnect()
	_flow = flow
	_seen.clear()
	_clock = 0
	_remaining = 0
	_sound_triggers = 0
	_event_count = 0
	if not is_node_ready():
		return
	_sound.stop()
	_snapshot = flow.routes.snapshot().duplicate(true)
	for pair in [["route_event",_on_event],["route_state_changed",_on_state]]:
		flow.connect(pair[0],pair[1])
		_connections.append({"source":flow,"signal":pair[0],"callback":pair[1]})
	_sync_visibility()

func _on_state(state: Dictionary) -> void:
	_snapshot = state.duplicate(true)
	queue_redraw()

func _on_event(kind: String, data: Dictionary) -> void:
	if not is_instance_valid(_flow) or _flow.phase not in ["running","paused","recovering"]:
		return
	var key: String = str(data.get("id",""))+":"+kind+":"+str(data.get("progress",""))+":"+str(data.get("kind",""))
	if key in _seen:
		return
	_seen.append(key)
	if _seen.size()>32:
		_seen.pop_front()
	_event_count += 1
	_kind = kind
	_color = Color("ffd166")
	match kind:
		"started":
			_message = "按 1 → 2 → 3 接入"
		"progress":
			_message = "3/3 · 前往出口" if int(data.get("progress",0))==3 else "下一节点 %d" % (int(data.get("progress",0))+1)
		"completed":
			_message = "连段完成 +%d" % int(data.get("bonus",0))
		"interrupted":
			_message = "连段中断 · 节点分保留"
			_color = Color("9bb5ba")
		"station":
			var amount: int = int(data.get("amount",0))
			if str(data.get("kind",""))=="heal":
				_message = "生命已满 · 本站已选择" if amount==0 else "恢复站 · 生命 +%d" % amount
				_color = Color("45dccb")
			else:
				_message = "恢复站 · 积分 +%d" % amount
		_:
			return
	_remaining = 1.2 if kind in ["completed","interrupted","station"] else .6
	if enable_event_audio and (kind=="completed" or (kind=="station" and int(data.get("amount",0))>0)):
		var name: String = "recover" if kind=="station" and str(data.get("kind",""))=="heal" else "complete"
		var path: String = "res://assets/audio/v06/"+name+".wav"
		if ResourceLoader.exists(path):
			_sound.stream = load(path)
			_sound.play()
			_sound.stream_paused = get_tree().paused
			_sound_triggers += 1
	_sync_visibility()
	queue_redraw()

func _sync_visibility() -> void:
	var live: bool = is_instance_valid(_flow) and _flow.is_endless() and _flow.phase in ["running","paused","recovering"]
	visible = live and (not str(_snapshot.get("active","")).is_empty() or _remaining>0)
	if not live and is_instance_valid(_sound):
		_sound.stop()
		_remaining = 0

func _process(delta: float) -> void:
	_sync_visibility()
	_sound.stream_paused = get_tree().paused
	if not visible or get_tree().paused:
		return
	_clock += delta
	_remaining = maxf(0,_remaining-delta)
	queue_redraw()

func _draw() -> void:
	if _font==null:
		return
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(.055,.095,.14,.96)
	panel.border_color = _color
	panel.set_border_width_all(1)
	panel.border_width_left = 3
	panel.set_corner_radius_all(5)
	draw_style_box(panel,Rect2(Vector2.ZERO,size))
	var active: bool = not str(_snapshot.get("active","")).is_empty()
	var progress: int = int(_snapshot.get("progress",0))
	var title: String = "连段 %d/3" % progress if active else ("恢复站" if _kind=="station" else "高路连段")
	draw_string(_font,Vector2(12,24),title,HORIZONTAL_ALIGNMENT_LEFT,-1,17,_color)
	if active:
		for i in 3:
			var at := Vector2(158+i*33,17)
			draw_circle(at,12,Color("304854") if i>=progress else Color("ffd166"))
			draw_string(_font,at+Vector2(-4,5),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("18212b") if i<progress else Color("9bb5ba"))
	var text: String = _message if _remaining>0 else ("3/3 · 前往出口" if progress==3 else "下一节点 %d" % (progress+1))
	draw_string(_font,Vector2(12,48),text,HORIZONTAL_ALIGNMENT_LEFT,-1,13,_color)

func presentation_state() -> Dictionary:
	return {"animation_time":_clock,"remaining":_remaining,"message":_message,"snapshot":_snapshot.duplicate(true),"visible":visible,"kind":_kind,"event_count":_event_count,"sound_triggers":_sound_triggers,"seen_count":_seen.size(),"audio_playing":_sound.playing if is_instance_valid(_sound) else false}

func _disconnect() -> void:
	for connection in _connections:
		if is_instance_valid(connection.source) and connection.source.is_connected(connection.signal,connection.callback):
			connection.source.disconnect(connection.signal,connection.callback)
	_connections.clear()

func _exit_tree() -> void:
	_disconnect()
	if is_instance_valid(_sound):
		_sound.stop()
		_sound.stream = null
