extends CharacterBody2D
## Swarmer drone. Fast, low HP, rams player for contact damage.

@export var move_speed: float = 220.0
@export var max_health: int = 20
@export var contact_damage: int = 15
@export var detection_range: float = 400.0

var health: int = 20
var state: String = "SPAWN"
var spawn_timer: float = 0.5
var ram_cooldown: float = 0.0
var death_timer: float = 0.2
var patrol_target: Vector2 = Vector2.ZERO
var patrol_wait: float = 0.0

const RAM_COOLDOWN_TIME: float = 0.8
const SECTOR_BOUNDS: Rect2 = Rect2(0, 0, 1280, 720)


func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	modulate.a = 0.0
	patrol_target = _random_point()


func _physics_process(delta: float) -> void:
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
		rotation = lerp_angle(rotation, velocity.angle(), 6.0 * delta)


func take_damage(amount: int) -> void:
	if state == "DEAD":
		return
	health -= amount
	modulate = Color(3.0, 3.0, 3.0, 1.0)
	get_tree().create_timer(0.1).timeout.connect(func(): modulate = Color(1, 1, 1, 1))
	if health <= 0:
		state = "DEAD"
		death_timer = 0.2


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
		patrol_wait = randf_range(0.5, 1.5)
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
	# Drone attack IS the chase — ram on contact via hitbox
	state = "ATTACK"
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
	velocity = (ship.global_position - global_position).normalized() * move_speed


func _state_dead(delta: float) -> void:
	velocity = Vector2.ZERO
	death_timer -= delta
	modulate = Color(3.0, 3.0, 3.0, maxf(0.0, death_timer / 0.2))
	if death_timer <= 0.0:
		queue_free()


func _get_player_ship() -> CharacterBody2D:
	var ships := get_tree().get_nodes_in_group("player_ship")
	if ships.is_empty():
		return null
	return ships[0] as CharacterBody2D


func _random_point() -> Vector2:
	return Vector2(randf_range(60, 1220), randf_range(60, 660))
