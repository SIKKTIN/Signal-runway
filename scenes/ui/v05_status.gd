extends Control
## Read-only UI. The owner passes real life/speed/invulnerability state.
@export var enable_hurt_audio := false
const BASE_DISPLAY_SPEED := 280.0
const MAX_DISPLAY_SPEED := 380.0
var _health := 3
var _target_speed := 280.0
var _actual_speed := 280.0
var _invulnerable := false
var _hurt_count := 0
var _initialized := false
var _clock := 0.0
var _hurt_remaining := 0.0
var _hurt_pulses := 0
var _feedback_active := true
var _font: Font
var _sound: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(380,60)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "Arial"])
	_font = font
	_sound = AudioStreamPlayer.new()
	_sound.name = "OptionalHurtCue"
	_sound.volume_db = -6
	if AudioServer.get_bus_index("SFX") >= 0:
		_sound.bus = "SFX"
	if ResourceLoader.exists("res://assets/audio/v05/hurt_tick.wav"):
		_sound.stream = load("res://assets/audio/v05/hurt_tick.wav")
	add_child(_sound)
	queue_redraw()

func update_state(health: int, target_speed: float, actual_speed: float, invulnerable: bool, hurt_count: int = 0) -> void:
	# Healing to full life is not a new run. RunFlow rebuilds this UI on restart.
	var new_round := _initialized and hurt_count < _hurt_count
	if new_round:
		_hurt_remaining = 0
		_clock = 0
		_hurt_pulses = 0
		if is_instance_valid(_sound):
			_sound.stop()
	elif _initialized and _feedback_active and (health < _health or hurt_count > _hurt_count) and health > 0:
		_hurt_remaining = 0.65
		_hurt_pulses += 1
		if enable_hurt_audio and is_instance_valid(_sound) and _sound.stream != null:
			_sound.play()
			_sound.stream_paused = get_tree().paused
	_health = clampi(health,0,3)
	_target_speed = maxf(0,target_speed)
	_actual_speed = absf(actual_speed)
	_invulnerable = invulnerable
	_hurt_count = maxi(0,hurt_count)
	_initialized = true
	if _health == 0:
		_hurt_remaining = 0
		if is_instance_valid(_sound):
			_sound.stop()
	queue_redraw()

func set_feedback_active(active: bool) -> void:
	_feedback_active = active
	if not active:
		_hurt_remaining = 0
		if is_instance_valid(_sound):
			_sound.stop()
	queue_redraw()

func _process(delta: float) -> void:
	if is_instance_valid(_sound):
		_sound.stream_paused = get_tree().paused
		if not is_visible_in_tree():
			_sound.stop()
	if get_tree().paused or not is_visible_in_tree() or _health == 0 or not _feedback_active:
		return
	_clock += delta
	_hurt_remaining = maxf(0,_hurt_remaining - delta)
	queue_redraw()

func _status_text() -> String:
	if _health == 0:
		return "生命耗尽"
	if _hurt_remaining > 0:
		return "受伤降速 · 无敌中" if _invulnerable else "受伤降速"
	if _invulnerable:
		return "无敌中 · 崩塌仍危险"
	if _target_speed >= MAX_DISPLAY_SPEED - 0.1:
		return "最高目标跑速 · 伤 %d 次" % _hurt_count
	if _target_speed > BASE_DISPLAY_SPEED + 0.1:
		return "无伤加速 · 伤 %d 次" % _hurt_count
	return "继续前进 · 伤 %d 次" % _hurt_count

func _draw() -> void:
	if _font == null:
		return
	var outline := Color("ffd166") if _invulnerable else Color("405a65")
	if _hurt_remaining > 0 or _health <= 1:
		outline = Color("ff685c")
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.055,0.095,0.14,0.96)
	panel.border_color = outline
	panel.set_border_width_all(1)
	panel.border_width_left = 3
	panel.set_corner_radius_all(5)
	draw_style_box(panel,Rect2(Vector2.ZERO,size))
	draw_string(_font,Vector2(12,23),"生命",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("a8bbc4"))
	for index in 3:
		var at := Vector2(52+index*25,9)
		var points := PackedVector2Array([Vector2(1,7),Vector2(5,2),Vector2(10,2),Vector2(12,5),Vector2(14,2),Vector2(19,2),Vector2(23,7),Vector2(22,12),Vector2(12,22),Vector2(2,12)])
		for i in points.size():
			points[i] += at
		var living := index < _health
		var tint := Color("ff685c") if _health == 1 else Color("45dccb")
		if living:
			draw_colored_polygon(points,tint)
		else:
			points.append(points[0])
			draw_polyline(points,Color("607987"),1.2,true)
	draw_string(_font,Vector2(132,24),"%d/3" % _health,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("e6efed"))
	draw_string(_font,Vector2(175,25),"跑速 %.0f" % _actual_speed,HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("e6efed"))
	draw_string(_font,Vector2(295,24),"目标%.0f" % _target_speed,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("a8bbc4"))
	var status_color := Color("ffb1a8") if _hurt_remaining > 0 else (Color("ffd166") if _invulnerable else Color("9bb5ba"))
	draw_string(_font,Vector2(12,48),_status_text(),HORIZONTAL_ALIGNMENT_LEFT,-1,13,status_color)
	var progress := clampf((_target_speed-BASE_DISPLAY_SPEED)/(MAX_DISPLAY_SPEED-BASE_DISPLAY_SPEED),0,1)
	draw_rect(Rect2(250,43,110,4),Color("304854"))
	draw_rect(Rect2(250,43,110*progress,4),Color("45dccb"))
	if _hurt_remaining > 0:
		var strength := 0.08+0.06*sin(_clock*8)
		draw_rect(Rect2(3,1,size.x-4,size.y-2),Color(1.0,0.41,0.36,strength))

func presentation_state() -> Dictionary:
	return {"health":_health,"target_speed":_target_speed,"actual_speed":_actual_speed,
		"invulnerable":_invulnerable,"hurt_count":_hurt_count,"animation_time":_clock,
		"hurt_remaining":_hurt_remaining,"hurt_pulses":_hurt_pulses,"status":_status_text(),
		"audio_enabled":enable_hurt_audio,"feedback_active":_feedback_active}

func _exit_tree() -> void:
	if is_instance_valid(_sound):
		_sound.stop()
		_sound.stream = null
