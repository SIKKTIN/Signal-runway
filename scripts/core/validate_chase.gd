extends SceneTree

var checks: Array[Dictionary] = []
func check(label: String, passed: bool, detail: Variant = "") -> void:
	checks.append({"check": label, "passed": passed, "detail": detail})
	print(label, ": ", passed, " ", detail)

func _initialize() -> void:
	var chase := preload("res://scripts/level/chase_controller.gd").new()
	# Preserve the first prototype fixture while the route uses the selected 270.
	chase.speed = 260.0
	root.add_child(chase)
	chase.reset(80.0)
	chase.advance(30.0, 70.0)
	check("waiting_does_not_advance", chase.front_x == -560.0 and chase.grace_remaining == 2.0)
	chase.set_enabled(true)
	chase.advance(1.0, 350.0)
	check("grace_holds_front", chase.front_x == -560.0 and chase.grace_remaining == 1.0)
	chase.advance(1.5, 770.0)
	check("grace_uses_remaining_delta", is_equal_approx(chase.front_x, -430.0), chase.front_x)
	var before: float = chase.front_x
	chase.advance(0.0, 770.0)
	check("zero_active_time_freezes", chase.front_x == before)
	var gap: float = chase.gap_px
	chase.advance(1.0, 1050.0)
	check("fast_forward_gains_gap", chase.gap_px > gap, chase.gap_px - gap)
	gap = chase.gap_px
	chase.advance(0.0, 850.0)
	check("retreat_loses_gap", chase.gap_px == gap - 200.0)
	check("large_delta_crossing_caught", chase.advance(10.0, 850.0))
	chase.reset(80.0)
	chase.set_enabled(true)
	check("retreat_into_half_plane_caught", chase.advance(0.01, -600.0))
	var stable := true
	for _i in 20:
		chase.reset(80.0)
		stable = stable and not chase.enabled and not chase.started and chase.front_x == -560.0 and chase.warning_level == "grace" and chase.grace_remaining == 2.0
		chase.set_enabled(true)
		chase.advance(6.0, 70.0)
	check("20_full_resets", stable)
	chase.reset(80.0)
	chase.set_enabled(true)
	check("standing_eventually_caught", chase.advance(5.0, 70.0))
	chase.reset(80.0)
	chase.start_delay = 0.0
	chase.reset(80.0)
	chase.set_enabled(true)
	chase.advance(0.0, chase.front_x + 1.9 * chase.speed)
	chase.advance(0.0, chase.front_x + 2.1 * chase.speed)
	check("warning_hysteresis", chase.warning_level == "urgent")
	chase.advance(0.0, chase.front_x + 2.3 * chase.speed)
	check("warning_recovers", chase.warning_level == "near")
	var passed := checks.all(func(c): return c.passed)
	DirAccess.make_dir_recursive_absolute("res://reports/v0.2")
	var file := FileAccess.open("res://reports/v0.2/prototype-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"suite": "v0.2-chase-rules", "godot": Engine.get_version_info().string, "checks": checks, "passed": passed}, "\t"))
	file.close()
	chase.free()
	quit(0 if passed else 1)
