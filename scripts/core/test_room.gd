extends Node2D

const PlayerScene = preload("res://scenes/player/player.tscn")
var player: CharacterBody2D
var death_count := 0
var platforms: Array[Rect2] = [Rect2(0, 448, 520, 92), Rect2(580, 448, 380, 92), Rect2(200, 368, 96, 16), Rect2(736, 304, 32, 144)]
var recovery := 0.0
var camera: Camera2D

func _ready() -> void:
	preload("res://scripts/core/input_bindings.gd").configure()
	for rect in platforms:
		var body := StaticBody2D.new()
		body.position = rect.position + rect.size / 2
		body.collision_layer = 1
		body.collision_mask = 2
		var collider := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		collider.shape = shape
		body.add_child(collider)
		add_child(body)
	player = PlayerScene.instantiate()
	player.name = "Player"
	add_child(player)
	player.reset_at(Vector2(80, 430))
	player.died.connect(_on_death)
	var hazard := Area2D.new()
	hazard.name = "Hazard"
	hazard.position = Vector2(432, 432)
	hazard.collision_layer = 4
	hazard.collision_mask = 2
	var hitbox := CollisionShape2D.new()
	var spike_shape := RectangleShape2D.new()
	spike_shape.size = Vector2(24, 24)
	hitbox.shape = spike_shape
	hazard.add_child(hitbox)
	hazard.body_entered.connect(func(body: Node2D):
		if body == player:
			player.die("spike"))
	add_child(hazard)
	camera = Camera2D.new()
	camera.position = Vector2(480, 270)
	add_child(camera)

func _physics_process(delta: float) -> void:
	if player.dead:
		recovery -= delta
		if recovery <= 0.0:
			player.reset_at(Vector2(80, 430))
	elif player.global_position.y > 650:
		player.die("fall")
	if Input.is_action_just_pressed("restart"):
		player.reset_at(Vector2(80, 430))
		death_count = 0

func _on_death(_reason: String, _position: Vector2) -> void:
	death_count += 1
	recovery = 0.25

func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color("18212b"))
	for x in range(0, 961, 32):
		draw_line(Vector2(x, 0), Vector2(x, 540), Color("21303a"))
	for y in range(0, 541, 32):
		draw_line(Vector2(0, y), Vector2(960, y), Color("21303a"))
	for rect in platforms:
		draw_rect(rect, Color("334554"))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4)), Color("e6efed"))
	draw_colored_polygon(PackedVector2Array([Vector2(416, 448), Vector2(432, 416), Vector2(448, 448)]), Color("ff685c"))
	draw_string(ThemeDB.fallback_font, Vector2(28, 48), "MOVEMENT LAB / v0.1", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("e6efed"))
	draw_string(ThemeDB.fallback_font, Vector2(28, 82), "A/D + SPACE   |   R: RESET   |   F2: LAB", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("45dccb"))
