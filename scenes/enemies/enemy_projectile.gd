extends Area2D
## Enemy projectile. Hits player only (layer 3, mask 1).

@export var speed: float = 400.0
@export var damage: int = 8
@export var lifetime: float = 2.5

var direction: Vector2 = Vector2.RIGHT
var time_alive: float = 0.0


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	time_alive += delta
	if time_alive >= lifetime:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
