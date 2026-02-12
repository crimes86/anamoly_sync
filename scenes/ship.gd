extends CharacterBody2D
## Player ship with movement, shooting, warp-out, and edge-jump.

signal health_changed(current: int, max_hp: int)
signal warp_charge_changed(progress: float)
signal warp_completed()
signal ship_destroyed()
signal edge_jump_started(direction: String)
signal edge_jump_progress_changed(progress: float)
signal edge_jump_completed(direction: String)
signal edge_jump_cancelled()

@export var move_speed: float = 300.0
@export var max_health: int = 100
@export var fire_rate: float = 0.2  # seconds between shots
@export var warp_charge_time: float = 8.0  # seconds to warp out

var health: int = 100
var is_warping: bool = false
var warp_progress: float = 0.0
var fire_cooldown: float = 0.0

# Combat state — shooting pauses sync
var combat_timer: float = 0.0
const COMBAT_COOLDOWN: float = 1.5  # seconds after last shot before sync resumes

# Edge jump state
var is_edge_jumping: bool = false
var edge_jump_direction: String = ""
var edge_jump_progress: float = 0.0
const EDGE_JUMP_TIME: float = 3.0  # seconds to channel edge transition
const SECTOR_BOUNDS: Rect2 = Rect2(0, 0, 1280, 720)
const EDGE_THRESHOLD: float = 20.0  # pixels from edge to trigger

# Orbital mechanics — set by anomaly each frame
var orbital_force: Vector2 = Vector2.ZERO
var is_in_orbit: bool = false

# Touch input
var touch_move_vector: Vector2 = Vector2.ZERO

@onready var projectile_scene: PackedScene = preload("res://scenes/projectile.tscn")


func _ready() -> void:
	_apply_upgrades()
	health = int(max_health * GameState.spawn_health_percent)
	health = maxi(health, 1)
	GameState.spawn_health_percent = 1.0  # Reset after use


func _apply_upgrades() -> void:
	var upgrades: Dictionary = GameState.ship_upgrades
	if upgrades.has("max_health"):
		max_health += int(upgrades["max_health"])
	if upgrades.has("warp_charge_time"):
		warp_charge_time = maxf(2.0, warp_charge_time + upgrades["warp_charge_time"])


var is_in_combat: bool:
	get:
		return combat_timer > 0.0


func _physics_process(delta: float) -> void:
	if combat_timer > 0.0:
		combat_timer -= delta
	_handle_movement(delta)
	_handle_shooting(delta)
	_handle_warp(delta)
	_check_edge_jump(delta)


func _handle_movement(delta: float) -> void:
	var input_vec := Vector2.ZERO

	# Keyboard input
	input_vec.x = Input.get_axis("move_left", "move_right")
	input_vec.y = Input.get_axis("move_up", "move_down")

	# Touch input override
	if touch_move_vector.length() > 0.1:
		input_vec = touch_move_vector

	var player_velocity: Vector2 = input_vec.normalized() * move_speed

	if is_in_orbit:
		# In orbit: orbital force guides, player input can steer/escape
		velocity = orbital_force + player_velocity * 0.85
	else:
		velocity = player_velocity

	move_and_slide()

	# Reset orbital force — anomaly must re-apply each frame
	orbital_force = Vector2.ZERO
	is_in_orbit = false

	# Clamp to sector bounds
	global_position.x = clampf(global_position.x, SECTOR_BOUNDS.position.x, SECTOR_BOUNDS.end.x)
	global_position.y = clampf(global_position.y, SECTOR_BOUNDS.position.y, SECTOR_BOUNDS.end.y)

	# Rotate ship to face movement direction — smooth interpolation prevents jitter in orbit
	if velocity.length() > 30.0:
		var target_angle: float = velocity.angle()
		rotation = lerp_angle(rotation, target_angle, 8.0 * delta)


func _check_edge_jump(delta: float) -> void:
	if is_warping:
		return

	# Detect which edge the ship is touching
	var direction := _get_edge_direction()

	if direction != "":
		# Check if there's a connected sector in that direction
		var neighbor := GameState.get_neighbor_in_direction(GameState.current_sector_id, direction)
		if neighbor == "" or not GameState.can_jump():
			# No connection or can't jump — cancel any channel
			if is_edge_jumping:
				_cancel_edge_jump()
			return

		# Start or continue edge jump channel
		if not is_edge_jumping:
			is_edge_jumping = true
			edge_jump_direction = direction
			edge_jump_progress = 0.0
			edge_jump_started.emit(direction)
		elif direction != edge_jump_direction:
			# Switched edges — restart
			edge_jump_direction = direction
			edge_jump_progress = 0.0

		edge_jump_progress += delta / EDGE_JUMP_TIME
		edge_jump_progress_changed.emit(edge_jump_progress)

		if edge_jump_progress >= 1.0:
			edge_jump_completed.emit(edge_jump_direction)
	else:
		# Not at edge — cancel channel
		if is_edge_jumping:
			_cancel_edge_jump()


func _get_edge_direction() -> String:
	if global_position.x <= SECTOR_BOUNDS.position.x + EDGE_THRESHOLD:
		return "west"
	elif global_position.x >= SECTOR_BOUNDS.end.x - EDGE_THRESHOLD:
		return "east"
	elif global_position.y <= SECTOR_BOUNDS.position.y + EDGE_THRESHOLD:
		return "north"
	elif global_position.y >= SECTOR_BOUNDS.end.y - EDGE_THRESHOLD:
		return "south"
	return ""


func _cancel_edge_jump() -> void:
	is_edge_jumping = false
	edge_jump_direction = ""
	edge_jump_progress = 0.0
	edge_jump_cancelled.emit()
	edge_jump_progress_changed.emit(0.0)


func _handle_shooting(delta: float) -> void:
	fire_cooldown -= delta
	if fire_cooldown > 0.0:
		return

	if Input.is_action_pressed("shoot"):
		_fire_projectile()
		fire_cooldown = fire_rate
		combat_timer = COMBAT_COOLDOWN


func _fire_projectile() -> void:
	if projectile_scene == null:
		return
	var aim_dir: Vector2 = Vector2.RIGHT.rotated(rotation)
	# Auto-aim: target nearest enemy if any are alive
	var target := _get_nearest_enemy()
	if target:
		aim_dir = (target.global_position - global_position).normalized()
	var projectile := projectile_scene.instantiate()
	projectile.global_position = global_position
	projectile.rotation = aim_dir.angle()
	projectile.direction = aim_dir
	get_tree().current_scene.add_child(projectile)


func _get_nearest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		if enemy.get("state") == "DEAD":
			continue
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy
	return nearest


func _handle_warp(delta: float) -> void:
	if Input.is_action_pressed("warp_out"):
		# Cancel edge jump if warping
		if is_edge_jumping:
			_cancel_edge_jump()
		if not is_warping:
			is_warping = true
			warp_progress = 0.0
		warp_progress += delta / warp_charge_time
		warp_charge_changed.emit(warp_progress)
		if warp_progress >= 1.0:
			warp_completed.emit()
	elif is_warping:
		# Released warp key — cancel
		is_warping = false
		warp_progress = 0.0
		warp_charge_changed.emit(0.0)


func take_damage(amount: int) -> void:
	health -= amount
	health = maxi(health, 0)
	health_changed.emit(health, max_health)

	# Damage interrupts warp
	if is_warping:
		warp_progress = maxf(0.0, warp_progress - 0.25)
		warp_charge_changed.emit(warp_progress)

	# Damage interrupts edge jump
	if is_edge_jumping:
		edge_jump_progress = maxf(0.0, edge_jump_progress - 0.3)
		edge_jump_progress_changed.emit(edge_jump_progress)
		if edge_jump_progress <= 0.0:
			_cancel_edge_jump()

	if health <= 0:
		ship_destroyed.emit()


func apply_orbital_force(force: Vector2) -> void:
	orbital_force = force
	is_in_orbit = true


func set_touch_input(direction: Vector2) -> void:
	touch_move_vector = direction
