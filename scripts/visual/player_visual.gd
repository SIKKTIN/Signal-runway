extends Node2D
## Drop this node under the public player node. It reads facing and subscribes to
## state_changed/action_triggered, but never changes velocity or collision.

const VISUAL_PATH := "res://assets/visual/"
const AUDIO_PATH := "res://assets/audio/"

var _sprite: Sprite2D
var _players: Dictionary = {}
var _sounds: Dictionary = {}
var _state := "idle"
var _run_clock := 0.0
var _effect_clock := 0.0
var _effect_kind := ""
var _source: Node


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_sprite)
	for state in ["idle", "run_0", "run_1", "rise", "fall", "wall_slide", "jump", "wall_jump", "land", "dead", "finish"]:
		_players[state] = load(VISUAL_PATH + "player_%s_0.png" % state)
	for action in ["jump", "wall_jump", "land", "death", "finish"]:
		var player := AudioStreamPlayer.new()
		player.name = "Sfx_" + action
		player.stream = load(AUDIO_PATH + "sfx_%s.wav" % action)
		player.volume_db = 0.0 if action == "land" else -3.0
		if AudioServer.get_bus_index("SFX") >= 0:
			player.bus = "SFX"
		add_child(player)
		_sounds[action] = player
	bind_source(get_parent())
	set_state("idle")


func bind_source(source: Node) -> void:
	_source = source
	if source == null:
		return
	if source.has_signal("state_changed") and not source.state_changed.is_connected(set_state):
		source.state_changed.connect(set_state)
	if source.has_signal("action_triggered") and not source.action_triggered.is_connected(trigger_action):
		source.action_triggered.connect(trigger_action)
	for property in source.get_property_list():
		if property.name == "fallback_visual_enabled":
			source.set("fallback_visual_enabled", false)
			break


func _exit_tree() -> void:
	for sound in _sounds.values():
		if is_instance_valid(sound):
			sound.stop()
			sound.stream = null
	_sounds.clear()


func _process(delta: float) -> void:
	if is_instance_valid(_source):
		var source_facing = _source.get("facing")
		if source_facing is float or source_facing is int:
			_sprite.flip_h = source_facing < 0
	if _state == "run":
		_run_clock += delta
		_sprite.texture = _players["run_0"] if int(_run_clock * 10.0) % 2 == 0 else _players["run_1"]
	if _effect_clock > 0.0:
		_effect_clock = maxf(0.0, _effect_clock - delta)
		queue_redraw()


func set_state(state: String) -> void:
	_state = state
	if state == "run":
		_run_clock = 0.0
		_sprite.texture = _players["run_0"]
	elif _players.has(state):
		_sprite.texture = _players[state]
	else:
		_sprite.texture = _players["idle"]
	if state == "dead":
		_sprite.modulate = Color(1.0, 0.86, 0.84)
	else:
		_sprite.modulate = Color.WHITE


func trigger_action(action: String) -> void:
	if _sounds.has(action):
		_sounds[action].stop()
		_sounds[action].play()
	_effect_kind = action
	_effect_clock = 0.17 if action != "finish" else 0.35
	if action == "jump" or action == "wall_jump":
		_sprite.scale = Vector2(0.88, 1.12)
	elif action == "land":
		_sprite.scale = Vector2(1.12, 0.88)
	else:
		_sprite.scale = Vector2.ONE
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", Vector2.ONE, 0.13)
	queue_redraw()


func play_finish() -> void:
	set_state("finish")
	trigger_action("finish")


func _draw() -> void:
	if _effect_clock <= 0.0:
		return
	var progress := _effect_clock / (0.35 if _effect_kind == "finish" else 0.17)
	var alpha := 0.35 * progress
	if _effect_kind == "jump" or _effect_kind == "wall_jump":
		draw_arc(Vector2(0, 14), 11.0 + (1.0 - progress) * 4.0, 0.2, PI - 0.2, 15, Color(0.65, 0.98, 0.93, alpha), 1.5)
	elif _effect_kind == "land":
		draw_line(Vector2(-15, 15), Vector2(15, 15), Color(0.9, 0.94, 0.93, alpha), 2.0)
	elif _effect_kind == "death":
		draw_arc(Vector2.ZERO, 12.0 + (1.0 - progress) * 10.0, 0.0, TAU, 24, Color(1.0, 0.41, 0.36, alpha), 2.0)
	elif _effect_kind == "finish":
		draw_arc(Vector2.ZERO, 16.0 + (1.0 - progress) * 14.0, 0.0, TAU, 24, Color(1.0, 0.82, 0.4, alpha), 2.0)
