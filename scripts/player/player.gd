extends CharacterBody2D

signal state_changed(state: String)
signal action_triggered(action: String)
signal died(reason: String, position: Vector2)
signal damage_taken(reason: String, remaining_health: int)
signal dash_state_changed(snapshot: Dictionary)

@export var move_speed := 280.0
@export var ground_acceleration := 1800.0
@export var ground_deceleration := 2100.0
@export var air_acceleration := 1400.0
@export var gravity := 1500.0
@export var fall_gravity := 2100.0
@export var jump_speed := 536.65
@export var jump_cut := 0.42
@export var coyote_window := 0.10
@export var buffer_window := 0.12
@export var wall_slide_speed := 90.0
@export var wall_jump_speed := Vector2(220.0, -550.0)

var state := "idle"
var facing := 1.0
var control_enabled := true
var auto_run := false
var dead := false
var fallback_visual_enabled := true
var _coyote := 0.0
var _buffer := 0.0
var _wall_lock := 0.0
var _spent_wall_side := 0.0
var _previous_floor := false
var health_enabled := false
var health := 3
var invulnerable_remaining := 0.0
var hurt_count := 0
var _hurt_frame := -1
var dash_enabled := false
var dash_charges := 1
var dash_progress := 0
var dash_remaining := 0.0
var dash_active := false
var dash_duration := 0.20
var dash_speed := 800.0
var dash_used := 0
var dash_refilled := 0
var _dash_nodes: Dictionary = {}

func dash_snapshot() -> Dictionary:
	return {"enabled":dash_enabled,"charges":dash_charges,"progress":dash_progress,"active":dash_active,"remaining":dash_remaining,"used":dash_used,"refilled":dash_refilled}

func _dash_changed(reason: String) -> void:
	var snapshot:=dash_snapshot()
	snapshot.reason=reason
	dash_state_changed.emit(snapshot)

func try_dash() -> bool:
	if not dash_enabled or dead or not control_enabled or get_tree().paused or dash_active:
		return false
	if dash_charges<=0:
		_dash_changed("empty")
		return false
	dash_charges-=1
	dash_remaining=dash_duration
	dash_active=true
	dash_used+=1
	action_triggered.emit("dash")
	_dash_changed("started")
	return true

func cancel_dash(reason: String) -> void:
	if not dash_active:
		return
	dash_active=false
	dash_remaining=0
	velocity.x=minf(velocity.x,move_speed)
	_dash_changed(reason)

func charge_dash(node_id: String) -> bool:
	if not dash_enabled or dead or not control_enabled or get_tree().paused or _dash_nodes.has(node_id):
		return false
	_dash_nodes[node_id]=true
	if dash_charges<2:
		dash_progress+=1
		if dash_progress==2:
			dash_progress=0
			dash_charges+=1
			dash_refilled+=1
			_dash_changed("refilled")
		else:
			_dash_changed("charging")
	else:
		dash_progress=0
	return true

func prune_dash_nodes(live_chunks: Dictionary) -> void:
	for id in _dash_nodes.keys():
		if not live_chunks.has(str(id).get_slice(":",0)+":"+str(id).get_slice(":",1)):
			_dash_nodes.erase(id)

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 4.0
	add_to_group("player")
	if not has_node("CollisionShape2D"):
		var collider := CollisionShape2D.new()
		collider.name = "CollisionShape2D"
		var shape := RectangleShape2D.new()
		shape.size = Vector2(20, 30)
		collider.shape = shape
		add_child(collider)

func _physics_process(delta: float) -> void:
	if dead:
		return
	invulnerable_remaining = maxf(0.0, invulnerable_remaining - delta)
	modulate.a = 0.45 if invulnerable_remaining > 0 and int(invulnerable_remaining * 12) % 2 == 0 else 1.0
	var grounded := is_on_floor()
	var direction := (1.0 if auto_run else Input.get_axis("move_left", "move_right")) if control_enabled else 0.0
	_coyote = coyote_window if grounded else maxf(0.0, _coyote - delta)
	_buffer = maxf(0.0, _buffer - delta)
	_wall_lock = maxf(0.0, _wall_lock - delta)
	if grounded:
		_spent_wall_side = 0.0
	if control_enabled and Input.is_action_just_pressed("jump"):
		_buffer = buffer_window
	if control_enabled and dash_enabled and Input.is_action_just_pressed("dash"):
		try_dash()
	if not grounded:
		velocity.y += (gravity if velocity.y < 0 else fall_gravity) * delta
		velocity.y = minf(velocity.y, 900.0)
	if _wall_lock <= 0.0:
		var acceleration := ground_acceleration if grounded else air_acceleration
		if grounded and is_zero_approx(direction):
			acceleration = ground_deceleration
		velocity.x = move_toward(velocity.x, direction * move_speed, acceleration * delta)
	if not is_zero_approx(direction):
		facing = direction
	var wall_side := signf(get_wall_normal().x) if is_on_wall() else 0.0
	var pressing_wall := not grounded and wall_side != 0.0 and direction == -wall_side
	if pressing_wall and _spent_wall_side != 0.0 and wall_side != _spent_wall_side:
		_spent_wall_side = 0.0
	if pressing_wall and velocity.y > wall_slide_speed:
		velocity.y = wall_slide_speed
	if _buffer > 0.0 and control_enabled:
		if _coyote > 0.0:
			velocity.y = -jump_speed
			_coyote = 0.0
			_buffer = 0.0
			_previous_floor = false
			action_triggered.emit("jump")
		elif pressing_wall and wall_side != _spent_wall_side:
			velocity = Vector2(wall_side * wall_jump_speed.x, wall_jump_speed.y)
			_spent_wall_side = wall_side
			_wall_lock = 0.08
			_buffer = 0.0
			action_triggered.emit("wall_jump")
	if control_enabled and Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut
	if dash_active:
		velocity.x=move_speed+(dash_speed-move_speed)*minf(1.0,dash_remaining/delta)
		dash_remaining=maxf(0,dash_remaining-delta)
	move_and_slide()
	if dash_active and dash_remaining<=0.00001:
		cancel_dash("finished")
	var landed := is_on_floor()
	if landed and not _previous_floor and velocity.y >= 0.0:
		action_triggered.emit("land")
	_previous_floor = landed
	var next_state := "idle"
	if not landed:
		next_state = "wall_slide" if pressing_wall and velocity.y >= 0.0 else ("rise" if velocity.y < 0.0 else "fall")
	elif absf(velocity.x) > 8.0:
		next_state = "run"
	_set_state(next_state)
	queue_redraw()

func _set_state(next_state: String) -> void:
	if next_state != state:
		state = next_state
		state_changed.emit(state)

func die(reason: String) -> void:
	if health_enabled and reason in ["spike", "fall"]:
		take_damage(reason)
		return
	if dead:
		return
	dead = true
	cancel_dash("death")
	control_enabled = false
	velocity = Vector2.ZERO
	_set_state("dead")
	action_triggered.emit("death")
	died.emit(reason, global_position)
	queue_redraw()

func take_damage(reason: String) -> bool:
	if not health_enabled:
		die(reason)
		return true
	if dead or get_tree().paused or invulnerable_remaining > 0 or _hurt_frame == Engine.get_physics_frames():
		return false
	_hurt_frame = Engine.get_physics_frames()
	cancel_dash("hurt")
	health = maxi(0, health - 1)
	hurt_count += 1
	invulnerable_remaining = 1.2
	move_speed = 280.0
	velocity.x = minf(velocity.x, 280.0)
	damage_taken.emit(reason, health)
	action_triggered.emit("hurt")
	if health == 0:
		die("health")
	return true

func recover_at(point: Vector2) -> void:
	cancel_dash("recovery")
	global_position = point
	velocity = Vector2(280, 0)
	control_enabled = true
	_buffer = 0
	_coyote = 0
	_wall_lock = 0
	_spent_wall_side = 0
	_previous_floor = false
	set_physics_process(true)

func reset_at(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	dead = false
	control_enabled = true
	_coyote = 0.0
	_buffer = 0.0
	_wall_lock = 0.0
	_spent_wall_side = 0.0
	_previous_floor = false
	health = 3
	hurt_count = 0
	_hurt_frame = -1
	invulnerable_remaining = 0
	dash_active=false
	dash_remaining=0
	dash_charges=1
	dash_progress=0
	dash_used=0
	dash_refilled=0
	_dash_nodes.clear()
	modulate.a = 1
	_set_state("idle")
	queue_redraw()

func set_control_enabled(enabled: bool) -> void:
	control_enabled = enabled
	if not enabled:
		cancel_dash("control_disabled")
		velocity.x = 0.0
		_buffer = 0.0
		if not dead:
			_set_state("idle")

func _draw() -> void:
	if fallback_visual_enabled:
		draw_rect(Rect2(-12, -16, 24, 32), Color("45dccb") if not dead else Color("ff685c"))
		draw_rect(Rect2(Vector2(3 if facing > 0 else -8, -9), Vector2(5, 4)), Color("18212b"))
