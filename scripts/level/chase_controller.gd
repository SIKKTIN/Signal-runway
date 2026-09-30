extends Node

signal threat_updated(front_x: float, gap_px: float, warning_level: String, grace_remaining: float)

@export var initial_gap := 640.0
@export var start_delay := 2.0
@export var speed := 270.0
var front_x := 0.0
var gap_px := 0.0
var grace_remaining := 0.0
var warning_level := "stopped"
var enabled := false
var started := false
var _previous_player_left := 0.0

func reset(spawn_x: float) -> void:
	front_x = spawn_x - maxf(initial_gap, 20.0)
	_previous_player_left = spawn_x - 10.0
	gap_px = _previous_player_left - front_x
	grace_remaining = maxf(start_delay, 0.0)
	enabled = false
	started = false
	warning_level = "grace"
	_publish()

func set_enabled(value: bool) -> void:
	enabled = value
	if value:
		started = true
		_update_warning()
	else:
		warning_level = "stopped"
	_publish()

func advance(active_delta: float, player_left_x: float) -> bool:
	var delta := maxf(active_delta, 0.0)
	if enabled:
		var used := minf(grace_remaining, delta)
		grace_remaining -= used
		delta -= used
		front_x += maxf(speed, 1.0) * delta
	gap_px = player_left_x - front_x
	_previous_player_left = player_left_x
	if enabled:
		_update_warning()
	_publish()
	# A filled half-plane catches interval crossings even when neither old nor
	# new positions overlaps a thin Area2D. The boundary never skips a body.
	return enabled and gap_px <= 0.0

func _update_warning() -> void:
	if grace_remaining > 0.0:
		warning_level = "grace"
		return
	var seconds := gap_px / maxf(speed, 1.0)
	if warning_level == "urgent" and seconds <= 2.25:
		return
	if seconds <= 2.0:
		warning_level = "urgent"
	elif seconds <= 4.0 or (warning_level == "near" and seconds <= 4.25):
		warning_level = "near"
	else:
		warning_level = "safe"

func _publish() -> void:
	threat_updated.emit(front_x, gap_px, warning_level, grace_remaining)
