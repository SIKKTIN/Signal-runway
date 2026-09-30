extends Node

signal threat_updated(front_x: float, gap_px: float, warning_level: String, grace_remaining: float)

var front_x := -500.0
var gap_px := 1268.0
var warning_level := "grace"
var grace_remaining := 2.0
var speed := 270.0


func sample(x: float, gap: float, grade: String, grace: float = 0.0) -> void:
	front_x = x
	gap_px = gap
	warning_level = grade
	grace_remaining = grace
	threat_updated.emit(front_x, gap_px, warning_level, grace_remaining)
