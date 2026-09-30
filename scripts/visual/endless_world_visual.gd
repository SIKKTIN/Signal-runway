extends Node2D
## Read-only active-snapshot manager. No terrain RNG or gameplay state writes.
var _flow: Node
var _course: Node
var _modules: Dictionary = {}
var _connections: Array[Dictionary] = []
var _animation_time := 0.0
var _paused := false
var _resolved := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if is_instance_valid(_flow):
		bind_flow(_flow, _course)

func bind_flow(flow: Node, course: Node) -> void:
	_disconnect_sources()
	for module in _modules.values():
		remove_child(module)
		module.queue_free()
	_modules.clear()
	_flow = flow
	_course = course
	_animation_time = 0
	if not is_node_ready():
		return
	_connect_source(course, "chunks_changed", _sync_snapshot)
	_connect_source(flow, "world_shifted", _on_world_shifted)
	_sync_phase()
	_sync_snapshot()

func _connect_source(source: Node, signal_name: String, callback: Callable) -> void:
	if source.has_signal(signal_name):
		source.connect(signal_name, callback)
		_connections.append({"source": source, "signal": signal_name, "callback": callback})

func _sync_snapshot() -> void:
	if not is_instance_valid(_course):
		return
	var active := {}
	for chunk in _course.get("chunks"):
		var id := str(chunk.id)
		active[id] = true
		if not _modules.has(id):
			var module := load("res://scripts/visual/endless_module_visual.gd").new() as Node2D
			add_child(module)
			_modules[id] = module
		_modules[id].configure(chunk, float(_course.get("total_offset")))
		_modules[id].set_clock(_animation_time)
	for id in _modules.keys():
		if not active.has(id):
			remove_child(_modules[id])
			_modules[id].queue_free()
			_modules.erase(id)

func _on_world_shifted(_distance: float) -> void:
	_sync_snapshot()

func _sync_phase() -> void:
	if is_instance_valid(_flow):
		var phase := str(_flow.get("phase"))
		_paused = phase == "paused" or get_tree().paused
		_resolved = phase in ["menu", "failed", "finished"]
		visible = phase != "menu"

func _process(delta: float) -> void:
	_sync_phase()
	if not _paused and not _resolved:
		_animation_time += delta
	for module in _modules.values():
		module.set_clock(_animation_time)

func presentation_state() -> Dictionary:
	var modules := {}
	for id in _modules:
		modules[id] = _modules[id].presentation_state()
	return {"animation_time": _animation_time, "paused": _paused, "resolved": _resolved,
		"modules": modules, "module_count": _modules.size()}

func _disconnect_sources() -> void:
	for connection in _connections:
		var source: Object = connection.source
		if is_instance_valid(source) and source.is_connected(connection.signal, connection.callback):
			source.disconnect(connection.signal, connection.callback)
	_connections.clear()

func _exit_tree() -> void:
	_disconnect_sources()
