extends RefCounted
## Verification only. Sends jump actions through the real auto-run controller.
var held := 0
var wall_jumps := 0
var take_relays := true
func step(app: Node) -> void:
	var p: CharacterBody2D = app.player
	if held > 0:
		held -= 1
		if held == 0:
			Input.action_release("jump")
	if p.is_on_wall() and not p.is_on_floor() and p._spent_wall_side != signf(p.get_wall_normal().x):
		if Input.is_action_pressed("jump"):
			Input.action_release("jump")
			held = 0
		else:
			Input.action_press("jump")
			held = 25
			wall_jumps += 1
	elif p.is_on_floor() and not Input.is_action_pressed("jump"):
		var jump := false
		if take_relays:
			for chunk in app.course.chunks:
				if chunk.category == "relay":
					var x: float = p.position.x - chunk.origin
					if chunk.template_id == "relay_b":
						jump = jump or (x >= 185 and x < 240 and p.position.y > 410) or (x >= 320 and x < 360 and p.position.y < 410)
					else:
						jump = jump or (x >= 274 and x < 320 and p.position.y > 410) or (x >= 453 and x < 500 and p.position.y < 410)
		if p.position.y > 410:
			for gap in app.course.gaps:
				jump = jump or (p.position.x >= gap.position.x - 44 and p.position.x < gap.position.x)
			for spike in app.course.spikes:
				jump = jump or (p.position.x >= spike.position.x - 54 and p.position.x < spike.end.x)
			for wall in app.course.walls:
				jump = jump or (wall.end.y >= 430 and p.position.x >= wall.position.x - 56 and p.position.x < wall.position.x)
		if jump:
			Input.action_press("jump")
			held = 25
