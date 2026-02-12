extends CharacterBody2D
## Heavy tank. Slow, tanky, burst-fires 3-shot spreads, contact damage.

@export var move_speed: float = 80.0
@export var max_health: int = 80
@export var contact_damage: int = 25
@export var detection_range: float = 500.0
@export var fire_rate: float = 2.0
@export var projectile_damage: int = 15
@export var projectile_speed: float = 300.0

var health: int = 80
var state: String = "SPAWN"
var spawn_timer: float = 0.5
var death_timer: float = 0.3
var fire_cooldown: float = 0.0
var ram_cooldown: float = 0.0
var patrol_target: Vector2 = Vector2.ZERO
var patrol_wait: float = 0.0

const RAM_COOLDOWN_TIME: float = 1.0
const SECTOR_BOUNDS: Rect2 = Rect2(0, 0, 1280, 720)
const SPREAD_ANGLE: float = 0.26  # ~15 degrees
var projectile_scene: PackedScene = preload("res://scenes/enemies/enemy_projectile.tscn")


func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	modulate.a = 0.0
	patrol_target = _random_point()


func _physics_process(delta: float) -> void:
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	ram_cooldown = maxf(0.0, ram_cooldown - delta)
	match state:
		"SPAWN":
			_state_spawn(delta)
		"PATROL":
			_state_patrol(delta)
		"CHASE":
			_state_chase(delta)
		"ATTACK":
			_state_attack(delta)
		"DEAD":
			_state_dead(delta)
	if state != "DEAD" and state != "SPAWN":
		move_and_slide()
		global_position.x = clampf(global_position.x, SECTOR_BOUNDS.position.x, SECTOR_BOUNDS.end.x)
		global_position.y = clampf(global_position.y, SECTOR_BOUNDS.position.y, SECTOR_BOUNDS.end.y)
	if velocity.length() > 10.0:
		rotation = lerp_angle(rotation, velocity.angle(), 4.0 * delta)


func take_damage(amount: int) -> void:
	if state == "DEAD":
		return
	health -= amount
	modulate = Color(3.0, 3.0, 3.0, 1.0)
	get_tree().create_timer(0.1).timeout.connect(func(): modulate = Color(1, 1, 1, 1))
	if health <= 0:
		state = "DEAD"
		death_timer = 0.3


func _on_hitbox_body_entered(body: Node2D) -> void:
	if state == "DEAD" or state == "SPAWN":
		return
	if ram_cooldown > 0.0:
		return
	if body.has_method("take_damage"):
		body.take_damage(contact_damage)
		ram_cooldown = RAM_COOLDOWN_TIME


func _state_spawn(delta: float) -> void:
	spawn_timer -= delta
	modulate.a = lerpf(0.0, 1.0, 1.0 - (spawn_timer / 0.5))
	if spawn_timer <= 0.0:
		modulate.a = 1.0
		state = "PATROL"


func _state_patrol(delta: float) -> void:
	var ship := _get_player_ship()
	if ship and global_position.distance_to(ship.global_position) <= detection_range:
		state = "CHASE"
		return
	if patrol_wait > 0.0:
		patrol_wait -= delta
		velocity = Vector2.ZERO
		return
	var dir: Vector2 = (patrol_target - global_position)
	if dir.length() < 20.0:
		patrol_target = _random_point()
		patrol_wait = randf_range(1.0, 2.0)
		velocity = Vector2.ZERO
		return
	velocity = dir.normalized() * move_speed * 0.6


func _state_chase(delta: float) -> void:
	var ship := _get_player_ship()
	if ship == null:
		state = "PATROL"
		return
	var dist: float = global_position.distance_to(ship.global_position)
	if dist > detection_range * 1.3:
		state = "PATROL"
		return
	if dist <= 200.0:
		state = "ATTACK"
		return
	velocity = (ship.global_position - global_position).normalized() * move_speed


func _state_attack(delta: float) -> void:
	var ship := _get_player_ship()
	if ship == null:
		state = "PATROL"
		return
	var dist: float = global_position.distance_to(ship.global_position)
	if dist > detection_range * 1.3:
		state = "PATROL"
		return
	# Keep advancing slowly
	velocity = (ship.global_position - global_position).normalized() * move_speed
	# Burst fire
	if fire_cooldown <= 0.0:
		_burst_fire(ship.global_position)
		fire_cooldown = fire_rate


func _state_dead(delta: float) -> void:
	velocity = Vector2.ZERO
	death_timer -= delta
	modulate = Color(3.0, 3.0, 3.0, maxf(0.0, death_timer / 0.3))
	if death_timer <= 0.0:
		queue_free()


func _burst_fire(target_pos: Vector2) -> void:
	var base_dir: Vector2 = (target_pos - global_position).normalized()
	var base_angle: float = base_dir.angle()
	for offset in [-SPREAD_ANGLE, 0.0, SPREAD_ANGLE]:
		var proj := projectile_scene.instantiate()
		proj.global_position = global_position
		proj.direction = Vector2.RIGHT.rotated(base_angle + offset)
		proj.rotation = base_angle + offset
		proj.damage = projectile_damage
		proj.speed = projectile_speed
		get_tree().current_scene.add_child(proj)


func _get_player_ship() -> CharacterBody2D:
	var ships := get_tree().get_nodes_in_group("player_ship")
	if ships.is_empty():
		return null
	return ships[0] as CharacterBody2D


func _random_point() -> Vector2:
	return Vector2(randf_range(60, 1220), randf_range(60, 660))
