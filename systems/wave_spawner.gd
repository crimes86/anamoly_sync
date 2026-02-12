extends Node
## Spawns enemy waves based on sector signal strength and time elapsed.
## Instantiated by sector.gd at runtime — not an autoload.

signal wave_spawned(wave_number: int, enemy_count: int)

var signal_strength: float = 0.5
var sector_id: String = ""

var wave_timer: float = 5.0  # First wave delay
var waves_completed: int = 0
var active_enemies: Array[Node] = []
var sync_complete: bool = false

const BASE_WAVE_INTERVAL: float = 12.0
const MAX_WAVE_INTERVAL: float = 20.0
const MIN_WAVE_INTERVAL: float = 6.0
const ESCALATION_RATE: float = 0.92
const FIRST_WAVE_DELAY: float = 5.0
const SPAWN_MARGIN: float = 40.0
const MIN_PLAYER_DISTANCE: float = 250.0
const MAX_ACTIVE_ENEMIES: int = 15

var drone_scene: PackedScene = preload("res://scenes/enemies/enemy_drone.tscn")
var gunner_scene: PackedScene = preload("res://scenes/enemies/enemy_gunner.tscn")
var sentinel_scene: PackedScene = preload("res://scenes/enemies/enemy_sentinel.tscn")


func _physics_process(delta: float) -> void:
	# Clean dead references
	active_enemies = active_enemies.filter(func(e): return is_instance_valid(e))

	# Stop spawning after sync is complete
	if sync_complete:
		return

	wave_timer -= delta
	if wave_timer <= 0.0:
		_spawn_wave()
		waves_completed += 1
		wave_timer = _get_wave_interval()


func _get_wave_interval() -> float:
	var interval: float = lerpf(MAX_WAVE_INTERVAL, BASE_WAVE_INTERVAL, signal_strength)
	interval *= pow(ESCALATION_RATE, waves_completed)
	return maxf(interval, MIN_WAVE_INTERVAL)


func _get_wave_size() -> int:
	var base: int = 1 + int(signal_strength * 3.0)
	var bonus: int = mini(waves_completed, 5)
	return base + bonus


func _spawn_wave() -> void:
	# Enforce cap
	active_enemies = active_enemies.filter(func(e): return is_instance_valid(e))
	var available_slots: int = MAX_ACTIVE_ENEMIES - active_enemies.size()
	if available_slots <= 0:
		return

	var wave_size: int = mini(_get_wave_size(), available_slots)
	var composition: Array[String] = _get_wave_composition(wave_size)

	for enemy_type in composition:
		var enemy: CharacterBody2D = _create_enemy(enemy_type)
		if enemy:
			enemy.global_position = _get_spawn_position()
			get_tree().current_scene.add_child(enemy)
			active_enemies.append(enemy)

	wave_spawned.emit(waves_completed + 1, composition.size())


func _get_wave_composition(wave_size: int) -> Array[String]:
	var result: Array[String] = []

	# Guaranteed sentinel at wave 4+ in high-signal sectors
	if waves_completed >= 3 and signal_strength >= 0.6:
		result.append("sentinel")
		wave_size -= 1

	for i in range(wave_size):
		result.append(_pick_enemy_type())
	return result


func _pick_enemy_type() -> String:
	var roll: float = randf()
	if signal_strength >= 0.8:
		# 40% drone, 30% gunner, 30% sentinel
		if roll < 0.4:
			return "drone"
		elif roll < 0.7:
			return "gunner"
		else:
			return "sentinel"
	elif signal_strength >= 0.6:
		# 50% drone, 30% gunner, 20% sentinel
		if roll < 0.5:
			return "drone"
		elif roll < 0.8:
			return "gunner"
		else:
			return "sentinel"
	elif signal_strength >= 0.4:
		# 70% drone, 30% gunner
		if roll < 0.7:
			return "drone"
		else:
			return "gunner"
	else:
		return "drone"


func _create_enemy(enemy_type: String) -> CharacterBody2D:
	match enemy_type:
		"drone":
			return drone_scene.instantiate()
		"gunner":
			return gunner_scene.instantiate()
		"sentinel":
			return sentinel_scene.instantiate()
	return drone_scene.instantiate()


func _get_spawn_position() -> Vector2:
	var ship := _get_player_ship()
	var player_pos: Vector2 = ship.global_position if ship else Vector2(640, 360)

	# Pick a random edge
	var edge: int = randi() % 4
	var pos: Vector2 = _edge_position(edge)

	# If too close to player, pick opposite edge
	if pos.distance_to(player_pos) < MIN_PLAYER_DISTANCE:
		pos = _edge_position((edge + 2) % 4)

	return pos


func _edge_position(edge: int) -> Vector2:
	match edge:
		0:  # Top
			return Vector2(randf_range(SPAWN_MARGIN, 1280.0 - SPAWN_MARGIN), SPAWN_MARGIN)
		1:  # Right
			return Vector2(1280.0 - SPAWN_MARGIN, randf_range(SPAWN_MARGIN, 720.0 - SPAWN_MARGIN))
		2:  # Bottom
			return Vector2(randf_range(SPAWN_MARGIN, 1280.0 - SPAWN_MARGIN), 720.0 - SPAWN_MARGIN)
		3:  # Left
			return Vector2(SPAWN_MARGIN, randf_range(SPAWN_MARGIN, 720.0 - SPAWN_MARGIN))
	return Vector2(SPAWN_MARGIN, SPAWN_MARGIN)


func get_active_enemy_count() -> int:
	active_enemies = active_enemies.filter(func(e): return is_instance_valid(e))
	return active_enemies.size()


func get_wave_number() -> int:
	return waves_completed


func _get_player_ship() -> CharacterBody2D:
	var ships := get_tree().get_nodes_in_group("player_ship")
	if ships.is_empty():
		return null
	return ships[0] as CharacterBody2D
